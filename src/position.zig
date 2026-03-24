//! Game position with move history and context stack for make/unmake.

const std = @import("std");
const assert = @import("std").debug.assert;
const ArrayList = @import("std").ArrayList;
const Allocator = @import("std").mem.Allocator;
const Move = @import("./root.zig").Move;
const MoveFlag = @import("./root.zig").MoveFlag;
const Bitboard = @import("./root.zig").Bitboard;
const CastlingRights = @import("./root.zig").CastlingRights;
const Board = @import("./root.zig").Board;
const Flank = @import("./root.zig").Flank;
const Rank = @import("./root.zig").Rank;
const File = @import("./root.zig").File;
const Piece = @import("./root.zig").Piece;
const PromotionPiece = @import("./root.zig").PromotionPiece;
const Square = @import("./root.zig").Square;
const Color = @import("./root.zig").Color;
const GameResult = @import("./root.zig").GameResult;
const PositionContext = @import("./root.zig").PositionContext;
const iterSetBits = @import("./root.zig").utils.iterSetBits;
const lsbMask = @import("./root.zig").utils.lsbMask;
const pawnsAttacks = @import("./root.zig").attacks.pawnsAttacks;
const pawnsAttacksLeft = @import("./root.zig").attacks.pawnsAttacksLeft;
const pawnsAttacksRight = @import("./root.zig").attacks.pawnsAttacksRight;
const knightAttacks = @import("./root.zig").attacks.knightAttacks;
const slidingBishopAttacks = @import("./root.zig").attacks.slidingBishopAttacks;
const slidingRookAttacks = @import("./root.zig").attacks.slidingRookAttacks;
const kingAttacks = @import("./root.zig").attacks.kingAttacks;
const pawnsPushes = @import("./root.zig").attacks.pawnsPushes;
const edgeToEdge = @import("./root.zig").utils.edgeToEdge;
const between = @import("./root.zig").utils.between;

/// Returned when unmakeMove is called at the root (no move to unmake).
pub const PositionError = error{
    CannotUnmakeAtRoot,
};

/// Chess position: board state, move history stack, halfmove clock, side to move.
pub const Position = struct {
    board: Board,
    contexts: ArrayList(PositionContext),
    halfmove: u10,
    gameResult: GameResult,
    sideToMove: Color,

    fn depth(self: *const Position) usize {
        return self.contexts.items.len - 1;
    }

    /// Returns a copy of the context for the current position. Pointers are
    /// not long lived; they are invalidated when elements are added.
    pub fn currentContext(self: *const Position) *const PositionContext {
        return &self.contexts.items[self.depth()];
    }

    pub fn currentContextMut(self: *const Position) *PositionContext {
        return &self.contexts.items[self.depth()];
    }

    /// Creates the standard starting position. contextsCapacity: hint for move history.
    pub fn initial(allocator: std.mem.Allocator, contextsCapacity: usize) Allocator.Error!Position {
        var contexts = try ArrayList(PositionContext).initCapacity(allocator, contextsCapacity);
        try contexts.append(allocator, PositionContext{
            .checkers = 0,
            .pinners = 0,
            .checkBlockers = 0,
            .hash = 0,
            .castlingRights = CastlingRights.ALL,
            .movedPiece = Piece.Null,
            .capturedPiece = Piece.Null,
            .doublePawnPushFile = null,
            .halfmoveClock = 0,
            .repetition = 0,
        });
        var pos = Position{
            .board = Board.initial(),
            .contexts = contexts,
            .halfmove = 0,
            .gameResult = GameResult.None,
            .sideToMove = Color.White,
        };
        pos.updateCheckInfo();

        pos.validate();

        return pos;
    }

    /// Asserts current context invariants.
    pub fn validateCurrentContext(self: *const Position) void {
        self.currentContext().validate();

        const opponentPieces = self.board.colorMask(self.sideToMove.other());

        assert(opponentPieces & self.currentContext().checkers == self.currentContext().checkers);
        assert(self.board.occupiedMask() & self.currentContext().pinners == self.currentContext().pinners);
        // assert(self.currentContext().hash == self.computeHash());
        if (self.currentContext().castlingRights.whiteKingside) {
            assert(self.board.pieceAtSquare(Square.H1) == Piece.Rook);
            assert(self.board.pieceAtSquare(Square.E1) == Piece.King);
        }
        if (self.currentContext().castlingRights.whiteQueenside) {
            assert(self.board.pieceAtSquare(Square.A1) == Piece.Rook);
            assert(self.board.pieceAtSquare(Square.E1) == Piece.King);
        }
        if (self.currentContext().castlingRights.blackKingside) {
            assert(self.board.pieceAtSquare(Square.H8) == Piece.Rook);
            assert(self.board.pieceAtSquare(Square.E8) == Piece.King);
        }
        if (self.currentContext().castlingRights.blackQueenside) {
            assert(self.board.pieceAtSquare(Square.A8) == Piece.Rook);
            assert(self.board.pieceAtSquare(Square.E8) == Piece.King);
        }
        assert(self.currentContext().halfmoveClock <= self.halfmove);
        assert(@abs(self.currentContext().repetition) <= self.halfmove);
    }

    /// Returns true if halfmove count is consistent with side to move.
    pub fn doHalfmoveAndSideToMoveAgree(self: *const Position) bool {
        const isEven = self.halfmove % 2 == 0;
        const isWhite = self.sideToMove == Color.White;
        return isEven == isWhite;
    }

    /// Returns true if halfmove clock does not exceed halfmoves played.
    pub fn isHalfmoveClockPlausible(self: *const Position) bool {
        return self.currentContext().halfmoveClock <= self.halfmove;
    }

    /// Returns true if the side not to move is not in check (legal position).
    pub fn isNotInIllegalCheck(self: *const Position) bool {
        return !self.board.isColorInCheck(self.sideToMove.other());
    }

    /// Asserts board and context invariants.
    pub fn validate(self: *const Position) void {
        self.board.validate();
        self.currentContext().validate();
        self.validateCurrentContext();
        for (self.contexts.items) |context| {
            context.validate();
        }
        assert(self.doHalfmoveAndSideToMoveAgree());
        assert(self.isHalfmoveClockPlausible());
        assert(self.isNotInIllegalCheck());
    }

    /// Applies the move and advances the position. Allocator used for context stack.
    pub fn makeMove(self: *Position, allocator: std.mem.Allocator, move: Move) Allocator.Error!void {
        self.validate();

        try self.contexts.append(allocator, self.contexts.items[self.depth()]);

        self.currentContextMut().halfmoveClock += 1;
        self.currentContextMut().doublePawnPushFile = null;

        switch (move.flag) {
            .Castling => {
                assert(self.board.mask(Piece.King, self.sideToMove) == move.from.mask());

                self.board.makeOrUnmakeCastlingMove(move, self.sideToMove);

                self.currentContextMut().movedPiece = Piece.King;
                self.currentContextMut().capturedPiece = Piece.Null;
                self.currentContextMut().halfmoveClock = 0;
                self.currentContextMut().castlingRights.clearMask(CastlingRights.colorMask(self.sideToMove));
            },
            .EnPassant => {
                self.board.makeOrUnmakeEnPassantMove(move, self.sideToMove);

                self.currentContextMut().movedPiece = Piece.Pawn;
                self.currentContextMut().capturedPiece = Piece.Pawn;
                self.currentContextMut().halfmoveClock = 0;
            },
            else => {
                self.currentContextMut().movedPiece = switch (move.flag) {
                    .Promotion => Piece.Pawn,
                    .Normal => self.board.pieceAtSquare(move.from),
                    else => unreachable,
                };

                self.currentContextMut().capturedPiece = self.board.pieceAtSquare(move.to);

                self.board.makeOrUnmakeNormalOrPromotionMove(
                    move,
                    self.sideToMove,
                    self.currentContext().movedPiece,
                    self.currentContext().capturedPiece,
                );

                if (self.currentContext().capturedPiece != Piece.Null) {
                    self.currentContextMut().halfmoveClock = 0;

                    if (self.currentContext().capturedPiece == Piece.Rook) {
                        self.currentContextMut().castlingRights.clearForRook(move.to);
                    }
                }

                switch (self.currentContext().movedPiece) {
                    .Pawn => {
                        self.currentContextMut().halfmoveClock = 0;
                        // Two steps along one file in rank-major square index (double push).
                        const double_pawn_push_index_delta: u6 = 16;
                        const from_i = move.from.int();
                        const to_i = move.to.int();
                        if (@max(from_i, to_i) - @min(from_i, to_i) == double_pawn_push_index_delta) {
                            self.currentContextMut().doublePawnPushFile = move.from.file();
                        }
                    },
                    .King => {
                        self.currentContextMut().castlingRights.clearMask(CastlingRights.colorMask(self.sideToMove));
                    },
                    .Rook => {
                        self.currentContextMut().castlingRights.clearForRook(move.from);
                    },
                    else => {},
                }
            },
        }

        self.sideToMove = self.sideToMove.other();
        self.halfmove += 1;

        self.updateCheckInfo();

        self.validate();
    }

    pub fn updateCheckInfo(self: *Position) void {
        self.currentContextMut().checkers = 0;
        self.currentContextMut().pinners = 0;
        self.currentContextMut().checkBlockers = 0;

        self.validate();

        const kingSquare = Square.fromMask(self.board.mask(Piece.King, self.sideToMove)) catch unreachable;

        const diagonalSliders = self.board.pieceMask(Piece.Bishop) | self.board.pieceMask(Piece.Queen);
        const orthogonalSliders = self.board.pieceMask(Piece.Rook) | self.board.pieceMask(Piece.Queen);

        const currentSideKingDiagonals = kingSquare.diagonalsMask();
        const currentSideKingOrthogonals = kingSquare.orthogonalsMask();

        const opponentPieces = self.board.colorMask(self.sideToMove.other());

        const knightCheckers = knightAttacks(kingSquare) & self.board.pieceMask(Piece.Knight) & opponentPieces;
        const pawnCheckers = pawnsAttacks(kingSquare.mask(), self.sideToMove) & self.board.pieceMask(Piece.Pawn) & opponentPieces;
        self.currentContextMut().checkers |= knightCheckers | pawnCheckers;

        const slidingThreats = ((diagonalSliders & currentSideKingDiagonals) | (orthogonalSliders & currentSideKingOrthogonals)) & opponentPieces;
        var slidingThreatMasksIter = iterSetBits(slidingThreats);

        while (slidingThreatMasksIter.next()) |attackingSliderMask| {
            const attackingSliderSquare = Square.fromMask(attackingSliderMask) catch unreachable;
            const betweenMask = between(kingSquare, attackingSliderSquare);
            assert(betweenMask & (kingSquare.mask() | attackingSliderMask) == 0);
            const occupiedBetween = betweenMask & self.board.occupiedMask();
            const numBlockers = @popCount(occupiedBetween);
            switch (numBlockers) {
                0 => self.currentContextMut().checkers |= attackingSliderMask,
                1 => {
                    self.currentContextMut().pinners |= attackingSliderMask;
                    self.currentContextMut().checkBlockers |= occupiedBetween;
                },
                else => {},
            }
        }
        assert(@popCount(self.currentContext().checkers) <= 2);
    }

    /// Reverts the move. Returns PositionError.CannotUnmakeAtRoot if at root.
    pub fn unmakeMove(self: *Position, move: Move) PositionError!void {
        self.validate();

        if (self.depth() == 0) return PositionError.CannotUnmakeAtRoot;

        self.sideToMove = self.sideToMove.other();
        self.halfmove -= 1;

        switch (move.flag) {
            .Castling => {
                self.board.makeOrUnmakeCastlingMove(move, self.sideToMove);
            },
            .EnPassant => {
                self.board.makeOrUnmakeEnPassantMove(move, self.sideToMove);
            },
            else => {
                self.board.makeOrUnmakeNormalOrPromotionMove(
                    move,
                    self.sideToMove,
                    self.currentContext().movedPiece,
                    self.currentContext().capturedPiece,
                );
            },
        }

        _ = self.contexts.pop();

        self.validate();
    }

    /// Perft (perft function): counts leaf nodes at given depth.
    /// Depth 0 returns 1. Depth 1 returns number of legal moves.
    pub fn perft(self: *Position, allocator: std.mem.Allocator, targetDepth: u8) !u64 {
        if (targetDepth == 0) return 1;

        var moves: [256]Move = undefined;
        const endPtr = self.genLegalMoves(&moves);
        const numMoves = endPtr - moves[0..].ptr;

        var nodes: u64 = 0;
        var i: usize = 0;
        while (i < numMoves) : (i += 1) {
            try self.makeMove(allocator, moves[i]);
            nodes += try self.perft(allocator, targetDepth - 1);
            self.unmakeMove(moves[i]) catch unreachable;
        }
        return nodes;
    }

    /// Drops pseudo-legal moves that are illegal (swap-remove in place).
    /// Only runs full legality for moves that need it:
    /// from a pinned square, king moves (including castling), or en passant.
    fn compactLegalInPlace(self: *const Position, moves: [*]Move, nextMovesPtr: [*]Move) [*]Move {
        const kingSquare = Square.fromMask(self.board.mask(Piece.King, self.sideToMove)) catch unreachable;

        var lastMovePtr = nextMovesPtr - 1;
        var movesPtr = lastMovePtr;

        while (@intFromPtr(movesPtr) >= @intFromPtr(moves)) : (movesPtr -= 1) {
            const move = movesPtr[0];

            const legal = if (!doesMoveNeedLegalityCheck(
                move,
                self.currentContext().checkBlockers,
                kingSquare,
            )) true else self.isPseudoLegalMoveLegal(move);

            if (!legal) {
                movesPtr[0] = lastMovePtr[0];
                lastMovePtr -= 1;
            }
        }
        return lastMovePtr + 1;
    }

    /// Fills the moves buffer with legal moves and returns a pointer past the last move.
    pub fn genLegalMoves(self: *const Position, moves: [*]Move) [*]Move {
        var nextMovesPtr = moves;
        const enemyKingMask = self.board.mask(Piece.King, self.sideToMove.other());
        const currentSidePieces = self.board.colorMask(self.sideToMove);

        const knights = self.board.pieceMask(Piece.Knight) & currentSidePieces;
        const queens = self.board.pieceMask(Piece.Queen) & currentSidePieces;
        const bishops = self.board.pieceMask(Piece.Bishop) & currentSidePieces;
        const rooks = self.board.pieceMask(Piece.Rook) & currentSidePieces;
        const diagonalPieces = queens | bishops;
        const orthogonalPieces = rooks | queens;
        const kings = self.board.pieceMask(Piece.King) & currentSidePieces;

        var isInDoubleCheck = false;
        const numCheckers = @popCount(self.currentContext().checkers);
        assert(numCheckers <= 2);

        const allowedDests: Bitboard = if (self.currentContext().checkers == 0) ~@as(Bitboard, 0) else blk: {
            if (numCheckers == 1) {
                const king = Square.fromMask(self.board.mask(Piece.King, self.sideToMove)) catch unreachable;
                const checker = Square.fromMask(self.currentContext().checkers) catch unreachable;
                const blockOrCheckMask = between(checker, king);

                assert(blockOrCheckMask & king.mask() == 0);

                break :blk blockOrCheckMask | checker.mask();
            } else {
                isInDoubleCheck = true;
                break :blk 0;
            }
        };
        if (!isInDoubleCheck) {
            nextMovesPtr = self.genPseudoLegalPawnMoves(allowedDests, enemyKingMask, nextMovesPtr);
            nextMovesPtr = self.genPseudoLegalMovesFromAttacks(knightAttacks, knights, allowedDests, enemyKingMask, nextMovesPtr);
            nextMovesPtr = self.genPseudoLegalMovesFromAttacks(slidingBishopAttacks, diagonalPieces, allowedDests, enemyKingMask, nextMovesPtr);
            nextMovesPtr = self.genPseudoLegalMovesFromAttacks(slidingRookAttacks, orthogonalPieces, allowedDests, enemyKingMask, nextMovesPtr);

            if (self.currentContext().checkers == 0) {
                nextMovesPtr = self.genPseudoLegalCastlingMoves(nextMovesPtr);
            }
        }

        nextMovesPtr = self.genPseudoLegalMovesFromAttacks(kingAttacks, kings, ~@as(Bitboard, 0), enemyKingMask, nextMovesPtr);

        if (nextMovesPtr == moves) return moves;

        return self.compactLegalInPlace(moves, nextMovesPtr);
    }

    pub fn isPseudoLegalMoveLegal(self: *const Position, move: Move) bool {
        if (move.flag == MoveFlag.EnPassant) return self.isPseudoLegalEnPassantLegal(move);
        if (move.flag == MoveFlag.Castling) return self.isPseudoLegalCastlingLegal(move);
        if (self.board.pieceMask(Piece.King) & move.from.mask() != 0) return self.isPseudoLegalKingMoveLegal(move);

        // Check if piece is pinned
        return (self.currentContext().checkBlockers & move.from.mask() == 0 or
            edgeToEdge(move.from, move.to) & self.board.mask(Piece.King, self.sideToMove) != 0);
    }

    pub fn isPseudoLegalEnPassantLegal(self: *const Position, move: Move) bool {
        assert(move.flag == MoveFlag.EnPassant);

        const enPassantCaptureSquare = Square.fromRankAndFile(self.sideToMove.enPassantCaptureRank(), move.to.file());
        const occupiedMaskAfterMove = self.board.occupiedMask() ^ move.from.mask() ^ move.to.mask() ^ enPassantCaptureSquare.mask();
        const opponentPieces = self.board.colorMask(self.sideToMove.other());
        const queens = self.board.pieceMask(Piece.Queen);
        const opponentDiagonalAttackers = (self.board.pieceMask(Piece.Bishop) | queens) & opponentPieces;
        const opponentOrthogonalAttackers = (self.board.pieceMask(Piece.Rook) | queens) & opponentPieces;
        const currentSideKing = Square.fromMask(self.board.mask(Piece.King, self.sideToMove)) catch unreachable;

        return slidingBishopAttacks(currentSideKing, occupiedMaskAfterMove) & opponentDiagonalAttackers == 0 and
            slidingRookAttacks(currentSideKing, occupiedMaskAfterMove) & opponentOrthogonalAttackers == 0;
    }

    pub fn isPseudoLegalCastlingLegal(self: *const Position, move: Move) bool {
        assert(move.flag == MoveFlag.Castling);
        return !self.castlingInCheck(move.castlingFlank() catch unreachable);
    }

    pub fn isPseudoLegalKingMoveLegal(self: *const Position, move: Move) bool {
        assert(move.from.mask() == self.board.mask(Piece.King, self.sideToMove));

        return self.isKingMoveSafe(move.from, move.to);
    }

    pub fn genPseudoLegalMovesFromAttacks(
        self: *const Position,
        pieceAttacks: anytype,
        from: Bitboard,
        allowedDests: Bitboard,
        enemyKingMask: Bitboard,
        moves: [*]Move,
    ) [*]Move {
        var nextMovesPtr = moves;

        const occupiedMask = self.board.occupiedMask();
        const attacksFilter = allowedDests & ~self.board.colorMask(self.sideToMove) & ~enemyKingMask;

        var sourceMasksIter = iterSetBits(from);
        while (sourceMasksIter.next()) |sourceMask| {
            const source = Square.fromMask(sourceMask) catch unreachable;

            const attacks: Bitboard = blk: {
                const T = @TypeOf(pieceAttacks);
                if (T == fn (Square) Bitboard) break :blk pieceAttacks(source);
                if (T == fn (Square, Bitboard) Bitboard) break :blk pieceAttacks(source, occupiedMask);

                @compileError("pieceAttacks must be fn(Square) Bitboard or fn(Square, Bitboard) Bitboard");
            };

            nextMovesPtr = splatMoves(source, attacks & attacksFilter, nextMovesPtr);
        }
        return nextMovesPtr;
    }

    fn genPseudoLegalPawnMoves(self: *const Position, allowedDests: Bitboard, enemyKingMask: Bitboard, moves: [*]Move) [*]Move {
        var nextMovesPtr = moves;
        const occupied = self.board.occupiedMask();
        const enemies = self.board.colorMask(self.sideToMove.other()) & ~enemyKingMask;
        const pawns = self.board.mask(Piece.Pawn, self.sideToMove);
        const promotionRankMask = Rank.Eight.fromPerspective(self.sideToMove).mask();
        const doublePawnPushMask = Rank.Three.fromPerspective(self.sideToMove).mask();

        const down: i7 = switch (self.sideToMove) {
            .White => Square.DELTA_DOWN,
            .Black => Square.DELTA_UP,
        };
        const downRight: i7 = switch (self.sideToMove) {
            .White => Square.DELTA_DOWN + Square.DELTA_RIGHT,
            .Black => Square.DELTA_UP + Square.DELTA_LEFT,
        };
        const downLeft: i7 = switch (self.sideToMove) {
            .White => Square.DELTA_DOWN + Square.DELTA_LEFT,
            .Black => Square.DELTA_UP + Square.DELTA_RIGHT,
        };

        var singlePushes = pawnsPushes(pawns, self.sideToMove) & ~occupied;
        const doublePushes = pawnsPushes(singlePushes & doublePawnPushMask, self.sideToMove) & ~occupied & allowedDests;
        singlePushes &= allowedDests;

        const capturesLeft = pawnsAttacksLeft(pawns, self.sideToMove) & enemies & allowedDests;
        const capturesRight = pawnsAttacksRight(pawns, self.sideToMove) & enemies & allowedDests;

        nextMovesPtr = splatPawnMoves(false, down, singlePushes & ~promotionRankMask, nextMovesPtr);
        nextMovesPtr = splatPawnMoves(false, down * 2, doublePushes, nextMovesPtr);

        nextMovesPtr = splatPawnMoves(true, downRight, capturesLeft & promotionRankMask, nextMovesPtr);
        nextMovesPtr = splatPawnMoves(true, downLeft, capturesRight & promotionRankMask, nextMovesPtr);
        nextMovesPtr = splatPawnMoves(true, down, singlePushes & promotionRankMask, nextMovesPtr);

        nextMovesPtr = splatPawnMoves(false, downRight, capturesLeft & ~promotionRankMask, nextMovesPtr);
        nextMovesPtr = splatPawnMoves(false, downLeft, capturesRight & ~promotionRankMask, nextMovesPtr);

        if (self.currentContext().doublePawnPushFile) |file| {
            const captureRank = self.sideToMove.enPassantDestRank();
            const captureMask = captureRank.mask() & file.mask();
            const captureSquare = Square.fromMask(captureMask) catch unreachable;
            // One bit in captureMask = hypothetical opponent pawn on the EP target; pawnsAttacks(..., .other())
            // is the reverse map (same idea as Stockfish attacks_bb<PAWN>(ep, Them)).
            const sourcesMask = self.board.mask(Piece.Pawn, self.sideToMove) & pawnsAttacks(captureMask, self.sideToMove.other());
            var epSources = sourcesMask;
            while (epSources != 0) {
                const sourceMask = lsbMask(epSources);
                const sourceSquare = Square.fromMask(sourceMask) catch unreachable;
                epSources ^= sourceMask;
                nextMovesPtr[0] = Move.newNonPromotion(sourceSquare, captureSquare, MoveFlag.EnPassant) catch unreachable;
                nextMovesPtr += 1;
            }
        }

        return nextMovesPtr;
    }

    fn genPseudoLegalCastlingMoves(self: *const Position, moves: [*]Move) [*]Move {
        var nextMovesPtr = moves;
        const castlingRights = self.currentContext().castlingRights;

        inline for ([_]Flank{ .Kingside, .Queenside }) |flank| {
            if (castlingRights.query(flank, self.sideToMove) and !self.castlingImpeded(flank)) {
                nextMovesPtr[0] = Move.castling(flank, self.sideToMove);
                nextMovesPtr += 1;
            }
        }

        return nextMovesPtr;
    }

    fn isKingMoveSafe(self: *const Position, source: Square, dest: Square) bool {
        const attackers = self.board.colorMask(self.sideToMove.other()) & ~dest.mask();

        if (pawnsAttacks(dest.mask(), self.sideToMove) & self.board.pieceMask(Piece.Pawn) & attackers != 0 or
            knightAttacks(dest) & self.board.pieceMask(Piece.Knight) & attackers != 0 or
            kingAttacks(dest) & self.board.pieceMask(Piece.King) & attackers != 0)
        {
            return false;
        } else {
            const queens = self.board.pieceMask(Piece.Queen);
            const relevantDiagonalAttackers = (self.board.pieceMask(Piece.Bishop) | queens) & attackers & dest.diagonalsMask();
            const relevantOrthogonalAttackers = (self.board.pieceMask(Piece.Rook) | queens) & attackers & dest.orthogonalsMask();
            const relevantSlidingAttackers = relevantDiagonalAttackers | relevantOrthogonalAttackers;

            const occupied = self.board.occupiedMask() ^ (dest.mask() | source.mask());

            var attackerSourceMasksIter = iterSetBits(relevantSlidingAttackers);
            while (attackerSourceMasksIter.next()) |attackerSourceMask| {
                const attackerSource = Square.fromMask(attackerSourceMask) catch unreachable;
                const blockers = between(dest, attackerSource) & occupied;
                if (blockers == 0) {
                    return false;
                }
            }

            return true;
        }
    }

    fn castlingImpeded(self: *const Position, flank: Flank) bool {
        return self.board.occupiedMask() & flank.castlingGapMask(self.sideToMove) != 0;
    }

    fn castlingInCheck(self: *const Position, flank: Flank) bool {
        return self.board.isMaskAttacked(flank.castlingCheckMask(self.sideToMove), self.sideToMove.other());
    }
};

fn splatPawnMoves(comptime arePromotions: bool, fromOffset: i7, to: Bitboard, moves: [*]Move) [*]Move {
    var nextMovesPtr = moves;
    var iter = iterSetBits(to);
    while (iter.next()) |destMask| {
        const dest = Square.fromMask(destMask) catch unreachable;
        const from = dest.relative(fromOffset) orelse unreachable;
        if (arePromotions) {
            nextMovesPtr[0..4].* = generatePawnPromotions(from, dest);
            nextMovesPtr += 4;
        } else {
            nextMovesPtr[0] = Move.newNonPromotion(from, dest, MoveFlag.Normal) catch unreachable;
            nextMovesPtr += 1;
        }
    }
    return nextMovesPtr;
}

fn generatePawnPromotions(from: Square, to: Square) [4]Move {
    return [4]Move{
        Move.newPromotion(from, to, PromotionPiece.Queen),
        Move.newPromotion(from, to, PromotionPiece.Knight),
        Move.newPromotion(from, to, PromotionPiece.Rook),
        Move.newPromotion(from, to, PromotionPiece.Bishop),
    };
}

fn splatMoves(from: Square, to: Bitboard, moves: [*]Move) [*]Move {
    var nextMovesPtr = moves;
    var iter = iterSetBits(to);
    while (iter.next()) |destMask| {
        const dest = Square.fromMask(destMask) catch unreachable;
        nextMovesPtr[0] = Move.newNonPromotion(from, dest, MoveFlag.Normal) catch unreachable;
        nextMovesPtr += 1;
    }
    return nextMovesPtr;
}

fn doesMoveNeedLegalityCheck(move: Move, checkBlockers: Bitboard, kingSquare: Square) bool {
    return move.flag == MoveFlag.EnPassant or checkBlockers & move.from.mask() != 0 or move.from == kingSquare;
}
