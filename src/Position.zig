//! Game position with move history and context stack for make/unmake.

const std = @import("std");
const assert = @import("std").debug.assert;
const ArrayList = @import("std").ArrayList;
const Move = @import("./mod.zig").Move;
const MoveFlag = @import("./mod.zig").MoveFlag;
const Bitboard = @import("./mod.zig").Bitboard;
const CastlingRights = @import("./mod.zig").CastlingRights;
const Board = @import("./mod.zig").Board;
const Flank = @import("./mod.zig").Flank;
const Rank = @import("./mod.zig").Rank;
const File = @import("./mod.zig").File;
const Piece = @import("./mod.zig").Piece;
const PromotionPiece = @import("./mod.zig").PromotionPiece;
const Square = @import("./mod.zig").Square;
const Color = @import("./mod.zig").Color;
const GameResult = @import("./mod.zig").GameResult;
const PositionContext = @import("./mod.zig").PositionContext;
const iterSetBits = @import("./mod.zig").utils.iterSetBits;
const lsbMask = @import("./mod.zig").utils.lsbMask;
const pawnsAttacks = @import("./mod.zig").attacks.pawnsAttacks;
const pawnsAttacksLeft = @import("./mod.zig").attacks.pawnsAttacksLeft;
const pawnsAttacksRight = @import("./mod.zig").attacks.pawnsAttacksRight;
const knightAttacks = @import("./mod.zig").attacks.knightAttacks;
const slidingBishopAttacks = @import("./mod.zig").attacks.slidingBishopAttacks;
const slidingRookAttacks = @import("./mod.zig").attacks.slidingRookAttacks;
const kingAttacks = @import("./mod.zig").attacks.kingAttacks;
const pawnsPushes = @import("./mod.zig").attacks.pawnsPushes;
const edgeToEdge = @import("./mod.zig").utils.edgeToEdge;
const between = @import("./mod.zig").utils.between;

/// Returned when unmakeMove is called at the root (no move to unmake).
pub const PositionError = error{
    CannotUnmakeAtRoot,
};

/// Chess position: board state, move history stack, halfmove clock, side to move.
pub const Position = struct {
    board: Board,
    contexts: ArrayList(PositionContext),
    currentDepth: usize,
    halfmove: u10,
    gameResult: GameResult,
    sideToMove: Color,

    /// Returns the context for the current position (castling, en passant, checkers, etc.).
    pub fn currentContext(self: *const Position) *const PositionContext {
        return &self.contexts.items[self.currentDepth];
    }

    fn currentContextMut(self: *Position) *PositionContext {
        return &self.contexts.items[self.currentDepth];
    }

    /// Creates the standard starting position. contextsCapacity: hint for move history.
    pub fn initial(allocator: std.mem.Allocator, contextsCapacity: usize) !Position {
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
        return Position{
            .board = Board.initial(),
            .contexts = contexts,
            .currentDepth = 0,
            .halfmove = 0,
            .gameResult = GameResult.None,
            .sideToMove = Color.White,
        };
    }

    /// Asserts current context invariants. Call in debug builds.
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

    /// Asserts board and context invariants. Call in debug builds.
    pub fn validate(self: *const Position) void {
        self.board.validate();
        self.currentContext().validate();
        self.validateCurrentContext();
        for (self.contexts.items[0 .. self.currentDepth + 1]) |context| {
            context.validate();
        }
        assert(self.currentDepth == self.halfmove);
        assert(self.doHalfmoveAndSideToMoveAgree());
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

    /// Applies the move and advances the position. Allocator used for context stack.
    pub fn makeMove(self: *Position, allocator: std.mem.Allocator, move: Move) !void {
        try self.contexts.append(allocator, self.contexts.items[self.currentDepth]);
        self.currentDepth += 1;

        const context = self.currentContextMut();
        context.halfmoveClock += 1;

        context.doublePawnPushFile = null; // Only set below if double pawn push

        switch (move.flag) {
            .Castling => {
                assert(self.board.mask(Piece.King, self.sideToMove) == move.from.mask());

                context.movedPiece = Piece.King;
                context.capturedPiece = Piece.Null;
                context.halfmoveClock = 0;

                const kingMoveMask = move.from.mask() | move.to.mask();
                const rookMoveMask = castlingRookMoveMask(move.castlingFlank() catch unreachable, self.sideToMove);

                self.board.xorPieceMask(Piece.King, kingMoveMask);
                self.board.xorPieceMask(Piece.Rook, rookMoveMask);
                self.board.xorColorMask(self.sideToMove, kingMoveMask | rookMoveMask);
                self.board.xorOccupiedMask(kingMoveMask | rookMoveMask);

                context.castlingRights.clearMask(CastlingRights.colorMask(self.sideToMove));
            },
            .EnPassant => {
                context.movedPiece = Piece.Pawn;
                context.capturedPiece = Piece.Pawn;
                context.halfmoveClock = 0;

                const captureSquare = Square.fromRankAndFile(self.sideToMove.enPassantCaptureRank(), move.to.file());
                const captureMask = captureSquare.mask();

                self.board.xorPieceMask(Piece.Pawn, move.from.mask() | move.to.mask() | captureMask);
                self.board.xorColorMask(self.sideToMove, move.from.mask() | move.to.mask());
                self.board.xorColorMask(self.sideToMove.other(), captureMask);
                self.board.xorOccupiedMask(move.from.mask() | move.to.mask() | captureMask);
            },
            else => {
                context.capturedPiece = self.board.pieceAtSquare(move.to);
                const isCapture = context.capturedPiece != Piece.Null;

                // Current side must move from source to destination no matter what
                self.board.xorColorMask(self.sideToMove, move.from.mask() | move.to.mask());

                if (isCapture) {
                    context.halfmoveClock = 0;
                    // No matter what, opposite side piece at destination square is removed
                    self.board.xorPieceMask(context.capturedPiece, move.to.mask());
                    self.board.xorColorMask(self.sideToMove.other(), move.to.mask());

                    // Unoccupy source but keep destination occupied
                    self.board.xorOccupiedMask(move.from.mask());

                    if (context.capturedPiece == Piece.Rook) {
                        context.castlingRights.clearForRook(move.to);
                    }
                } else {
                    // Unoccupy source and occupy destination
                    self.board.xorOccupiedMask(move.from.mask() | move.to.mask());
                }

                var movedPiece: Piece = undefined;

                if (move.flag == MoveFlag.Promotion) {
                    movedPiece = Piece.Pawn;

                    // Reset halfmove clock for pawn move
                    context.halfmoveClock = 0;
                    // Remove pawn from source
                    self.board.xorPieceMask(Piece.Pawn, move.from.mask());
                    // Put promotion piece at destination
                    self.board.xorPieceMask(move.promotion.piece(), move.to.mask());
                } else {
                    movedPiece = self.board.pieceAtSquare(move.from);

                    // Toggle moved piece at source and destination
                    self.board.xorPieceMask(movedPiece, move.from.mask() | move.to.mask());
                }

                switch (movedPiece) {
                    .Pawn => {
                        context.halfmoveClock = 0;
                        if (distance(move.from.int(), move.to.int()) == 16) {
                            context.doublePawnPushFile = move.from.file();
                        }
                    },
                    .King => {
                        context.castlingRights.clearMask(CastlingRights.colorMask(self.sideToMove));
                    },
                    .Rook => {
                        context.castlingRights.clearForRook(move.from);
                    },
                    else => {},
                }
            },
        }

        self.sideToMove = self.sideToMove.other();
        self.halfmove += 1;

        self.updateCheckInfo();
    }

    pub fn updateCheckInfo(self: *Position) void {
        const context = self.currentContextMut();
        context.checkers = 0;
        context.pinners = 0;
        context.checkBlockers = 0;

        const kingSquare = Square.fromMask(self.board.mask(Piece.King, self.sideToMove)) catch unreachable;

        const diagonalSliders = self.board.pieceMask(Piece.Bishop) | self.board.pieceMask(Piece.Queen);
        const orthogonalSliders = self.board.pieceMask(Piece.Rook) | self.board.pieceMask(Piece.Queen);

        const currentSideKingDiagonals = kingSquare.diagonalsMask();
        const currentSideKingOrthogonals = kingSquare.orthogonalsMask();

        const slidingThreats = ((diagonalSliders & currentSideKingDiagonals) | (orthogonalSliders & currentSideKingOrthogonals)) & self.board.colorMask(self.sideToMove.other());
        var slidingThreatMasksIter = iterSetBits(slidingThreats);

        while (slidingThreatMasksIter.next()) |attackingSliderMask| {
            const attackingSliderSquare = Square.fromMask(attackingSliderMask) catch unreachable;
            const betweenMask = between(kingSquare, attackingSliderSquare);
            assert(betweenMask & (kingSquare.mask() | attackingSliderMask) == 0);
            const occupiedBetween = betweenMask & self.board.occupiedMask();
            const numBlockers = @popCount(occupiedBetween);
            switch (numBlockers) {
                0 => context.checkers |= attackingSliderMask,
                1 => {
                    context.pinners |= attackingSliderMask;
                    context.checkBlockers |= occupiedBetween;
                },
                else => {},
            }
        }
    }

    /// Reverts the move. Returns PositionError.CannotUnmakeAtRoot if at root.
    pub fn unmakeMove(self: *Position, move: Move) PositionError!void {
        if (self.currentDepth == 0) return PositionError.CannotUnmakeAtRoot;

        const movedPiece = self.contexts.items[self.currentDepth].movedPiece;
        const capturedPiece = self.contexts.items[self.currentDepth].capturedPiece;

        self.sideToMove = self.sideToMove.other();
        self.halfmove -= 1;
        self.currentDepth -= 1;

        switch (move.flag) {
            .Castling => {
                const kingMoveMask = move.from.mask() | move.to.mask();
                const rookMoveMask = castlingRookMoveMask(move.castlingFlank() catch unreachable, self.sideToMove.other());

                self.board.xorPieceMask(Piece.King, kingMoveMask);
                self.board.xorPieceMask(Piece.Rook, rookMoveMask);
                self.board.xorColorMask(self.sideToMove, kingMoveMask | rookMoveMask);
                self.board.xorOccupiedMask(kingMoveMask | rookMoveMask);
            },
            .EnPassant => {
                const captureSquare = Square.fromRankAndFile(self.sideToMove.enPassantCaptureRank(), move.to.file());
                const captureMask = captureSquare.mask();

                self.board.xorPieceMask(Piece.Pawn, move.from.mask() | move.to.mask() | captureMask);
                self.board.xorColorMask(self.sideToMove, move.from.mask() | move.to.mask());
                self.board.xorColorMask(self.sideToMove.other(), captureMask);
                self.board.xorOccupiedMask(move.from.mask() | move.to.mask() | captureMask);
            },
            else => {
                const isCapture = capturedPiece != Piece.Null;

                self.board.xorColorMask(self.sideToMove, move.from.mask() | move.to.mask());

                if (isCapture) {
                    self.board.xorPieceMask(capturedPiece, move.to.mask());
                    self.board.xorColorMask(self.sideToMove.other(), move.to.mask());
                    self.board.xorOccupiedMask(move.from.mask());
                } else {
                    self.board.xorOccupiedMask(move.from.mask() | move.to.mask());
                }

                if (move.flag == MoveFlag.Promotion) {
                    self.board.xorPieceMask(Piece.Pawn, move.from.mask());
                    self.board.xorPieceMask(move.promotion.piece(), move.to.mask());
                } else {
                    self.board.xorPieceMask(movedPiece, move.from.mask() | move.to.mask());
                }
            },
        }
    }

    /// Fills the moves buffer with legal moves and returns a pointer past the last move.
    pub fn genLegalMoves(self: *const Position, moves: [*]Move) [*]Move {
        var nextMovesPtr = moves;
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
            nextMovesPtr = self.genPseudoLegalPawnMoves(true, allowedDests, nextMovesPtr);
            nextMovesPtr = self.genPseudoLegalMovesFromAttacks(knightAttacks, knights, allowedDests, nextMovesPtr);
            nextMovesPtr = self.genPseudoLegalMovesFromAttacks(slidingBishopAttacks, diagonalPieces, allowedDests, nextMovesPtr);
            nextMovesPtr = self.genPseudoLegalMovesFromAttacks(slidingRookAttacks, orthogonalPieces, allowedDests, nextMovesPtr);

            if (self.currentContext().checkers == 0) {
                nextMovesPtr = self.genPseudoLegalCastlingMoves(nextMovesPtr);
            }
        }

        nextMovesPtr = self.genPseudoLegalMovesFromAttacks(kingAttacks, kings, ~@as(Bitboard, 0), nextMovesPtr);

        if (nextMovesPtr == moves) return moves;

        var lastMovePtr = nextMovesPtr - 1;
        var movesPtr = lastMovePtr;
        while (@intFromPtr(movesPtr) >= @intFromPtr(moves)) : (movesPtr -= 1) {
            if (!self.isPseudoLegalMoveLegal(movesPtr[0])) {
                movesPtr[0] = lastMovePtr[0];
                lastMovePtr -= 1;
            }
        }

        return lastMovePtr + 1;
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
        moves: [*]Move,
    ) [*]Move {
        var nextMovesPtr = moves;

        const occupiedMask = self.board.occupiedMask();
        const attacksFilter = allowedDests & ~self.board.colorMask(self.sideToMove);

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

    fn genPseudoLegalPawnMoves(self: *const Position, comptime includeEnPassant: bool, allowedDests: Bitboard, moves: [*]Move) [*]Move {
        var nextMovesPtr = moves;
        const occupied = self.board.occupiedMask();
        const enemies = self.board.colorMask(self.sideToMove.other());

        const pawns = self.board.mask(Piece.Pawn, self.sideToMove);
        const promotionRankMask = Rank.Eight.fromPerspective(self.sideToMove).mask();
        const doublePawnPushMask = Rank.Three.fromPerspective(self.sideToMove).mask();

        const down: i7 = switch (self.sideToMove) {
            .White => 8,
            .Black => -8,
        };
        const downRight: i7 = switch (self.sideToMove) {
            .White => 9,
            .Black => -9,
        };
        const downLeft: i7 = switch (self.sideToMove) {
            .White => 7,
            .Black => -7,
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

        if (includeEnPassant) {
            if (self.currentContext().doublePawnPushFile) |file| {
                const captureRank = self.sideToMove.enPassantDestRank();
                const captureMask = captureRank.mask() & file.mask();
                const captureSquare = Square.fromMask(captureMask) catch unreachable;
                var sourcesMask = pawnsAttacks(captureMask, self.sideToMove.other()) & self.board.colorMask(self.sideToMove);
                for (0..2) |_| {
                    if (sourcesMask != 0) {
                        const sourceMask = lsbMask(sourcesMask);
                        const sourceSquare = Square.fromMask(sourceMask) catch unreachable;
                        sourcesMask ^= sourceMask;
                        nextMovesPtr[0] = Move.newNonPromotion(sourceSquare, captureSquare, MoveFlag.EnPassant) catch unreachable;
                        nextMovesPtr += 1;
                    }
                }
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

/// Returns the bitboard of squares the rook moves through when castling on the given flank and color.
fn castlingRookMoveMask(flank: Flank, color: Color) Bitboard {
    return flank.castlingRookFilesMask() & color.backRank().mask();
}

fn splatPawnMoves(comptime arePromotions: bool, fromOffset: i7, to: Bitboard, moves: [*]Move) [*]Move {
    var nextMovesPtr = moves;
    var iter = iterSetBits(to);
    while (iter.next()) |destMask| {
        const dest = Square.fromMask(destMask) catch unreachable;
        const fromIntSigned = @as(i8, dest.int()) + fromOffset;
        assert(fromIntSigned >= 0);
        const fromIntUnsigned: u8 = @bitCast(fromIntSigned);
        assert(fromIntUnsigned <= ~@as(u6, 0));
        const from = Square.fromInt(@truncate(fromIntUnsigned));
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

/// Returns the absolute difference between two values.
fn distance(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    return @max(a, b) - @min(a, b);
}
