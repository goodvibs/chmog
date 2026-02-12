const std = @import("std");
const assert = @import("std").debug.assert;
const ArrayList = @import("std").ArrayList;
const Move = @import("./mod.zig").Move;
const MoveFlag = @import("./mod.zig").MoveFlag;
const Bitboard = @import("./mod.zig").Bitboard;
const CastlingRights = @import("./mod.zig").CastlingRights;
const Board = @import("./mod.zig").Board;
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

pub const MAX_MOVES: usize = 256;

pub const Position = struct {
    board: Board,
    currentContext: PositionContext,
    previousContexts: ArrayList(PositionContext),
    halfmove: u10,
    gameResult: GameResult,
    sideToMove: Color,

    pub fn initial(allocator: std.mem.Allocator, previousContextsCapacity: usize) !Position {
        return Position{
            .board = Board.initial(),
            .currentContext = PositionContext{
                .checkers = 0,
                .pinners = 0,
                .checkBlockers = [2]Bitboard{ 0, 0 },
                .hash = 0,
                .castlingRights = CastlingRights.all(),
                .movedPiece = Piece.Null,
                .capturedPiece = Piece.Null,
                .doublePawnPushFile = null,
                .halfmoveClock = 0,
                .repetition = 0,
            },
            .previousContexts = try ArrayList(PositionContext).initCapacity(allocator, previousContextsCapacity),
            .halfmove = 0,
            .gameResult = GameResult.None,
            .sideToMove = Color.White,
        };
    }

    pub fn validateCurrentContext(self: *const Position) void {
        self.currentContext.validate();

        const opponentPieces = self.board.colorMask(self.sideToMove.other());

        assert(opponentPieces & self.currentContext.checkers == self.currentContext.checkers);
        assert(self.board.occupiedMask() & self.currentContext.pinners == self.currentContext.pinners);
        // assert(self.currentContext.hash == self.computeHash();
        if (self.currentContext.castlingRights.whiteKingside) {
            assert(self.board.pieceAtSquare(Square.H1) == Piece.Rook);
            assert(self.board.pieceAtSquare(Square.E1) == Piece.King);
        }
        if (self.currentContext.castlingRights.whiteQueenside) {
            assert(self.board.pieceAtSquare(Square.A1) == Piece.Rook);
            assert(self.board.pieceAtSquare(Square.E1) == Piece.King);
        }
        if (self.currentContext.castlingRights.blackKingside) {
            assert(self.board.pieceAtSquare(Square.H8) == Piece.Rook);
            assert(self.board.pieceAtSquare(Square.E8) == Piece.King);
        }
        if (self.currentContext.castlingRights.blackQueenside) {
            assert(self.board.pieceAtSquare(Square.A8) == Piece.Rook);
            assert(self.board.pieceAtSquare(Square.E8) == Piece.King);
        }
        assert(self.currentContext.halfmoveClock <= self.halfmove);
        assert(@abs(self.currentContext.repetition) <= self.halfmove);
    }

    pub fn validate(self: *const Position) void {
        self.board.validate();
        self.currentContext.validate();
        self.validateCurrentContext();
        for (self.previousContexts.items) |context| {
            context.validate();
        }
        assert(self.previousContexts.items.len >= self.halfmove);
        assert(self.doHalfmoveAndSideToMoveAgree());
    }

    pub fn doHalfmoveAndSideToMoveAgree(self: *const Position) bool {
        const isEven = self.halfmove % 2 == 0;
        const isWhite = self.sideToMove == Color.White;
        return isEven == isWhite;
    }

    pub fn isHalfmoveClockPlausible(self: *const Position) bool {
        return self.currentContext.halfmoveClock <= self.halfmove;
    }

    pub fn isInCheckmate(self: *const Position) bool {
        return !self.hasMoves();
    }

    pub fn isNotInIllegalCheck(self: *const Position) bool {
        return !self.board.isColorInCheck(self.sideToMove.other());
    }

    pub fn makeMove(self: *Position, allocator: std.mem.Allocator, move: Move) !void {
        try self.previousContexts.append(allocator, self.currentContext);

        self.currentContext.doublePawnPushFile = null;
        self.board.xorOccupiedMask(move.from.mask() | move.to.mask());
        self.board.xorColorMask(self.sideToMove, move.from.mask() | move.to.mask());
        switch (move.flag) {
            .Castling => {
                assert(self.board.mask(Piece.King, self.sideToMove) == self.from.mask());
                self.currentContext.capturedPiece = null;
                self.currentContext.halfmoveClock = 0;
                const isKingSide = isKingSideCastling(move);

                const kingMoveMask = move.from.mask() | move.to.mask();

                const colorlessRookMoveMask = if (isKingSide) File.H.mask() | File.F.mask() else File.A.mask() | File.D.mask();
                const rankMask = move.from.rank.mask();
                const rookMoveMask = colorlessRookMoveMask & rankMask;

                self.board.xorPieceMask(Piece.King, kingMoveMask);
                self.board.xorPieceMask(Piece.Rook, rookMoveMask);
                self.board.xorColorMask(self.sideToMove, rookMoveMask);
                self.board.xorOccupiedMask(rookMoveMask);
                self.currentContext.castlingRights.toggleMask(CastlingRights.colorMask(self.sideToMove));
            },
            .EnPassant => {
                self.currentContext.capturedPiece = Piece.Pawn;
                self.currentContext.halfmoveClock = 0;
                const captureSquare = Square.fromRankAndFile(enPassantCaptureRank(self.sideToMove), move.to.file());
                const captureMask = captureSquare.mask();
                self.board.xorPieceMask(Piece.Pawn, captureMask);
                self.board.xorColorMask(self.sideToMove.other(), captureMask);
                self.board.xorOccupiedMask(captureMask);
            },
            else => {
                self.currentContext.capturedPiece = self.board.pieceAtSquare(move.to);
                if (self.currentContext.capturedPiece) |capturedPiece| {
                    self.currentContext.halfmoveClock = 0;
                    self.board.xorPieceMask(capturedPiece, move.to.mask());
                    self.board.xorColorMask(self.sideToMove.other(), move.to.mask());
                    self.board.xorOccupiedMask(move.to.mask());
                    // if (move.to.mask() & self.currentContext.chec
                }
                if (move.flag == MoveFlag.Promotion) {
                    const promotion = move.promotion.piece();
                    self.board.xorPieceMask(Piece.Pawn, move.from.mask());
                    self.board.xorPieceMask(promotion, move.to.mask());
                } else {
                    const movedPiece = self.board.pieceAtSquare(move.from);
                    switch (movedPiece) {
                        .Pawn => {
                            self.currentContext.halfmoveClock = 0;
                            if (distance(move.from.int(), move.to.int() == 2)) {
                                self.currentContext.doublePawnPushFile = move.from.file();
                            }
                        },
                        .Bishop => {},
                        .Rook => {},
                        .Queen => {},
                        .King => {
                            self.currentContext.castlingRights = CastlingRights.fromMask(@as(u4, 0));
                        },
                    }
                }
            },
        }
    }

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
        const numCheckers = @popCount(self.currentContext.checkers);
        assert(numCheckers <= 2);

        const allowedDests: Bitboard = if (self.currentContext.checkers == 0) ~@as(Bitboard, 0) else blk: {
            if (numCheckers == 1) {
                const king = Square.fromMask(self.board.mask(Piece.King, self.sideToMove)) catch unreachable;
                const checker = Square.fromMask(self.currentContext.checkers) catch unreachable;
                const blockOrCheckMask = between(checker, king);

                assert(blockOrCheckMask & king.mask() == 0);
                assert(blockOrCheckMask & checker.mask() != 0);

                break :blk blockOrCheckMask;
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

            if (self.currentContext.checkers == 0) {
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

        return (self.currentContext.pinned & self.board.colorMask(self.sideToMove) & move.from.mask() == 0 or
            edgeToEdge(move.from, move.to) & self.board.mask(Piece.King, self.sideToMove) != 0);
    }

    pub fn isPseudoLegalEnPassantLegal(self: *const Position, move: Move) bool {
        assert(move.flag == MoveFlag.EnPassant);

        const enPassantCaptureSquare = Square.fromRankAndFile(enPassantCaptureRank(self.sideToMove), move.to.file());
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

        if (isKingSideCastling(move)) return !self.kingSideCastlingInCheck();
        return !self.queenSideCastlingInCheck();
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
            if (self.currentContext.doublePawnPushFile) |file| {
                const captureRank = enPassantDestRank(self.sideToMove);
                const captureMask = captureRank.mask() & file.mask();
                const captureSquare = Square.fromMask(captureMask) catch unreachable;
                var sourcesMask = pawnsAttacks(captureMask, self.sideToMove.other()) & self.board.colorMask(self.sideToMove);
                for (0..2) |_| {
                    if (sourcesMask != 0) {
                        const sourceMask = lsbMask(sourcesMask);
                        const sourceSquare = Square.fromMask(sourceMask) catch unreachable;
                        sourcesMask ^= sourceMask;
                        nextMovesPtr[0] = Move.newNonPromotion(sourceSquare, captureSquare, MoveFlag.EnPassant);
                        nextMovesPtr += 1;
                    }
                }
            }
        }

        return nextMovesPtr;
    }

    fn genPseudoLegalCastlingMoves(self: *const Position, moves: [*]Move) [*]Move {
        var nextMovesPtr = moves;

        const castlingRights = self.currentContext.castlingRights;

        if (castlingRights.query(true, self.sideToMove) and !self.kingSideCastlingImpeded()) {
            nextMovesPtr[0] = Move.kingsideCastling(self.sideToMove);
            nextMovesPtr += 1;
        }

        if (castlingRights.query(false, self.sideToMove) and !self.queenSideCastlingImpeded()) {
            nextMovesPtr[0] = Move.queensideCastling(self.sideToMove);
            nextMovesPtr += 1;
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

    fn hasMoves(_: *const Position) bool {
        return true;
    }

    fn kingSideCastlingImpeded(self: *const Position) bool {
        return self.board.occupiedMask() & kingSideCastlingGapMask(self.sideToMove) != 0;
    }

    fn queenSideCastlingImpeded(self: *const Position) bool {
        return self.board.occupiedMask() & queenSideCastlingGapMask(self.sideToMove) != 0;
    }

    fn kingSideCastlingInCheck(self: *const Position) bool {
        return self.board.isMaskAttacked(kingSideCastlingCheckMask(self.sideToMove), self.sideToMove.other());
    }

    fn queenSideCastlingInCheck(self: *const Position) bool {
        return self.board.isMaskAttacked(queenSideCastlingCheckMask(self.sideToMove), self.sideToMove.other());
    }
};

fn isKingSideCastling(move: Move) bool {
    assert(move.flag == MoveFlag.Castling);
    const result = move.to.int() > move.from.int();
    assert(result == ((move.from == Square.E1 and move.to == Square.H1) or (move.from == Square.E8 and move.to == Square.H8)));
    assert(result != ((move.from == Square.E1 and move.to == Square.A1) or (move.from == Square.E8 and move.to == Square.A8)));
    return result;
}

fn kingSideCastlingGapMask(forColor: Color) Bitboard {
    return switch (forColor) {
        .White => Square.F1.mask() | Square.G1.mask(),
        .Black => Square.F8.mask() | Square.G8.mask(),
    };
}

fn queenSideCastlingGapMask(forColor: Color) Bitboard {
    return switch (forColor) {
        .White => Square.D1.mask() | Square.C1.mask() | Square.B1.mask(),
        .Black => Square.D8.mask() | Square.C8.mask() | Square.B8.mask(),
    };
}

fn kingSideCastlingCheckMask(forColor: Color) Bitboard {
    return switch (forColor) {
        .White => Square.F1.mask() | Square.G1.mask(),
        .Black => Square.F8.mask() | Square.G8.mask(),
    };
}

fn queenSideCastlingCheckMask(forColor: Color) Bitboard {
    return switch (forColor) {
        .White => Square.D1.mask() | Square.C1.mask(),
        .Black => Square.D8.mask() | Square.C8.mask(),
    };
}

fn enPassantSourceRank(forColor: Color) Rank {
    return switch (forColor) {
        .White => Rank.Six,
        .Black => Rank.Three,
    };
}

fn enPassantDestRank(forColor: Color) Rank {
    return switch (forColor) {
        .White => Rank.Six,
        .Black => Rank.Three,
    };
}

fn enPassantCaptureRank(forColor: Color) Rank {
    return switch (forColor) {
        .White => Rank.Five,
        .Black => Rank.Four,
    };
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
            nextMovesPtr[0] = Move.newNonPromotion(from, dest, MoveFlag.Normal);
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
        nextMovesPtr[0] = Move.newNonPromotion(from, dest, MoveFlag.Normal);
        nextMovesPtr += 1;
    }
    return nextMovesPtr;
}

fn distance(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    return @max(a, b) - @min(a, b);
}
