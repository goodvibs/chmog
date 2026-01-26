const std = @import("std");
const assert = @import("std").debug.assert;
const ArrayList = @import("std").ArrayList;
const Move = @import("./mod.zig").Move;
const MoveFlag = @import("./mod.zig").MoveFlag;
const Bitboard = @import("./mod.zig").Bitboard;
const Board = @import("./mod.zig").Board;
const Rank = @import("./mod.zig").Rank;
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
const slidingQueenAttacks = @import("./mod.zig").attacks.slidingQueenAttacks;
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
            .currentContext = PositionContext.new(),
            .previousContexts = try ArrayList(PositionContext).initCapacity(allocator, previousContextsCapacity),
            .halfmove = 0,
            .gameResult = GameResult.None,
            .sideToMove = Color.White,
        };
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

    pub fn addAllMoves(self: *const Position, moves_: [*]Move) [*]Move {
        var moves = moves_;
        const currentSidePieces = self.board.colorMask(self.sideToMove);

        const knights = self.board.pieceMask(Piece.Knight) & currentSidePieces;
        const queens = self.board.pieceMask(Piece.Queen) & currentSidePieces;
        const bishops = self.board.pieceMask(Piece.Bishop) & currentSidePieces;
        const rooks = self.board.pieceMask(Piece.Rook) & currentSidePieces;
        const diagonalPieces = queens | bishops;
        const orthogonalPieces = rooks | queens;
        const kings = self.board.pieceMask(Piece.King) & currentSidePieces;

        var isInDoubleCheck = false;
        const allowedDests: Bitboard = if (self.currentContext.checkers == 0) ~@as(Bitboard, 0) else blk: {
            const numCheckers = @popCount(self.currentContext.checkers);
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
            moves = self.addPseudoLegalPawnMoves(true, allowedDests, moves);
            moves = self.addPseudoLegalMovesFromAttacks(knightAttacks, knights, allowedDests, moves);
            moves = self.addPseudoLegalMovesFromAttacks(slidingBishopAttacks, diagonalPieces, allowedDests, moves);
            moves = self.addPseudoLegalMovesFromAttacks(slidingRookAttacks, orthogonalPieces, allowedDests, moves);
            moves = self.addPseudoLegalCastlingMoves(moves);
        }

        moves = self.addPseudoLegalMovesFromAttacks(kingAttacks, kings, allowedDests, moves);

        return moves;
    }

    pub fn addPseudoLegalMovesFromAttacks(
        self: *const Position,
        pieceAttacks: anytype,
        from: Bitboard,
        allowedDests: Bitboard,
        moves_: [*]Move,
    ) [*]Move {
        var moves = moves_;

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

            moves = splatMoves(source, attacks & attacksFilter, moves);
        }
        return moves;
    }

    fn addPseudoLegalPawnMoves(self: *const Position, comptime includeEnPassant: bool, allowedDests: Bitboard, moves_: [*]Move) [*]Move {
        var moves = moves_;
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

        moves = splatPawnMoves(false, down, singlePushes, moves);
        moves = splatPawnMoves(false, down * 2, doublePushes, moves);

        moves = splatPawnMoves(true, downRight, capturesLeft & promotionRankMask, moves);
        moves = splatPawnMoves(true, downLeft, capturesRight & promotionRankMask, moves);
        moves = splatPawnMoves(true, down, singlePushes & promotionRankMask, moves);

        moves = splatPawnMoves(false, downRight, capturesLeft & ~promotionRankMask, moves);
        moves = splatPawnMoves(false, downLeft, capturesRight & ~promotionRankMask, moves);

        if (includeEnPassant) {
            if (self.currentContext.doublePawnPushFile) |file| {
                const captureRank = enPassantCaptureRank(self.sideToMove);
                const captureMask = captureRank.mask() & file.mask();
                const captureSquare = Square.fromMask(captureMask) catch unreachable;
                var sourcesMask = pawnsAttacks(captureMask, self.sideToMove.other()) & self.board.colorMask(self.sideToMove);
                for (0..2) |_| {
                    if (sourcesMask != 0) {
                        const sourceMask = lsbMask(sourcesMask);
                        const sourceSquare = Square.fromMask(sourceMask) catch unreachable;
                        sourcesMask ^= sourceMask;
                        moves[0] = Move.newNonPromotion(sourceSquare, captureSquare, MoveFlag.EnPassant);
                        moves += 1;
                    }
                }
            }
        }

        return moves;
    }

    fn addPseudoLegalCastlingMoves(self: *const Position, moves_: [*]Move) [*]Move {
        var moves = moves_;

        const castlingRights = self.currentContext.castlingRights;

        if (castlingRights.kingsideForColor(self.sideToMove) and !self.kingsideCastlingImpeded()) {
            moves[0] = Move.kingsideCastling(self.sideToMove);
            moves += 1;
        }

        if (castlingRights.queensideForColor(self.sideToMove) and !self.queensideCastlingImpeded()) {
            moves[0] = Move.queensideCastling(self.sideToMove);
            moves += 1;
        }

        return moves;
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

    fn kingsideCastlingImpeded(self: *const Position) bool {
        return self.board.occupiedMask() & kingsideCastlingGapMask(self.sideToMove) != 0;
    }

    fn queensideCastlingImpeded(self: *const Position) bool {
        return self.board.occupiedMask() & queensideCastlingGapMask(self.sideToMove) != 0;
    }

    fn kingsideCastlingInCheck(self: *const Position) bool {
        return self.board.isMaskAttacked(kingsideCastlingCheckMask(self.sideToMove), self.sideToMove.other());
    }

    fn queensideCastlingInCheck(self: *const Position) bool {
        return self.board.isMaskAttacked(queensideCastlingCheckMask(self.sideToMove), self.sideToMove.other());
    }
};

fn kingsideCastlingGapMask(forColor: Color) Bitboard {
    return switch (forColor) {
        .White => Square.F1.mask() | Square.G1.mask(),
        .Black => Square.F8.mask() | Square.G8.mask(),
    };
}

fn queensideCastlingGapMask(forColor: Color) Bitboard {
    return switch (forColor) {
        .White => Square.D1.mask() | Square.C1.mask() | Square.B1.mask(),
        .Black => Square.D8.mask() | Square.C8.mask() | Square.B8.mask(),
    };
}

fn kingsideCastlingCheckMask(forColor: Color) Bitboard {
    return switch (forColor) {
        .White => Square.F1.mask() | Square.G1.mask(),
        .Black => Square.F8.mask() | Square.G8.mask(),
    };
}

fn queensideCastlingCheckMask(forColor: Color) Bitboard {
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

fn enPassantCaptureRank(forColor: Color) Rank {
    return switch (forColor) {
        .White => Rank.Six,
        .Black => Rank.Three,
    };
}

fn splatPawnMoves(comptime arePromotions: bool, fromOffset: i7, to: Bitboard, moves_: [*]Move) [*]Move {
    var moves = moves_;
    var iter = iterSetBits(to);
    while (iter.next()) |destMask| {
        const dest = Square.fromMask(destMask) catch unreachable;
        const fromIntSigned = @as(i8, dest.int()) + fromOffset;
        assert(fromIntSigned >= 0);
        const fromIntUnsigned: u8 = @bitCast(fromIntSigned);
        assert(fromIntUnsigned <= ~@as(u6, 0));
        const from = Square.fromInt(@truncate(fromIntUnsigned));
        if (arePromotions) {
            moves[0..4].* = generatePawnPromotions(from, dest);
            moves += 4;
        } else {
            moves[0] = Move.newNonPromotion(from, dest, MoveFlag.Normal);
            moves += 1;
        }
    }
    return moves;
}

fn generatePawnPromotions(from: Square, to: Square) [4]Move {
    return [4]Move{
        Move.newPromotion(from, to, PromotionPiece.Queen),
        Move.newPromotion(from, to, PromotionPiece.Knight),
        Move.newPromotion(from, to, PromotionPiece.Rook),
        Move.newPromotion(from, to, PromotionPiece.Bishop),
    };
}

fn splatMoves(from: Square, to: Bitboard, moves_: [*]Move) [*]Move {
    var moves = moves_;
    var iter = iterSetBits(to);
    while (iter.next()) |destMask| {
        const dest = Square.fromMask(destMask) catch unreachable;
        moves[0] = Move.newNonPromotion(from, dest, MoveFlag.Normal);
        moves += 1;
    }
    return moves;
}
