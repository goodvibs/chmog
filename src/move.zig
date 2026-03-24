//! Move representation: UCI format, castling, promotion.

const std = @import("std");
const Color = @import("./root.zig").Color;
const Flank = @import("./root.zig").Flank;
const Square = @import("./root.zig").Square;
const PromotionPiece = @import("./root.zig").PromotionPiece;
const MoveFlag = @import("./root.zig").MoveFlag;

/// Move-related errors: ExpectedACastlingMove, ExpectedANonPromotion, BufferTooSmall.
pub const MoveError = error{
    ExpectedACastlingMove,
    ExpectedANonPromotion,
    BufferTooSmall,
};

const CASTLING_BY_FLANK_AND_COLOR: [2][2]Move = [2][2]Move{
    .{
        Move.newNonPromotion(Square.E1, Square.G1, MoveFlag.Castling) catch unreachable,
        Move.newNonPromotion(Square.E1, Square.C1, MoveFlag.Castling) catch unreachable,
    },
    .{
        Move.newNonPromotion(Square.E8, Square.G8, MoveFlag.Castling) catch unreachable,
        Move.newNonPromotion(Square.E8, Square.C8, MoveFlag.Castling) catch unreachable,
    },
};

/// Chess move: from/to squares, promotion piece, and flag (normal, en passant, castling, promotion).
pub const Move = packed struct {
    from: Square,
    to: Square,
    promotion: PromotionPiece,
    flag: MoveFlag,

    /// Default promotion piece when not a promotion move.
    pub const DEFAULT_PROMOTION = PromotionPiece.Knight;

    /// Creates a non-promotion move (normal, en passant, or castling).
    pub fn newNonPromotion(from: Square, to: Square, flag: MoveFlag) MoveError!Move {
        if (flag == MoveFlag.Promotion) {
            return MoveError.ExpectedANonPromotion;
        }

        return Move{
            .from = from,
            .to = to,
            .promotion = DEFAULT_PROMOTION,
            .flag = flag,
        };
    }

    /// Creates a pawn promotion move.
    pub fn newPromotion(from: Square, to: Square, promotion: PromotionPiece) Move {
        return Move{
            .from = from,
            .to = to,
            .promotion = promotion,
            .flag = MoveFlag.Promotion,
        };
    }

    /// Creates a castling move for the given flank and color.
    pub fn castling(flank: Flank, color: Color) Move {
        return CASTLING_BY_FLANK_AND_COLOR[@as(usize, color.int())][@as(usize, flank.int())];
    }

    /// Returns the flank for a castling move. Returns MoveError.ExpectedACastlingMove if not a castling move.
    pub fn castlingFlank(self: Move) MoveError!Flank {
        if (self.flag != MoveFlag.Castling) return MoveError.ExpectedACastlingMove;
        return if (self.to.int() > self.from.int()) Flank.Kingside else Flank.Queenside;
    }

    /// Writes UCI string (e.g. "e2e4") to buffer. Returns MoveError.BufferTooSmall if buffer.len < 5 for promotions.
    pub fn uci(self: Move, buffer: []u8) MoveError![]const u8 {
        if (buffer.len < 5) return MoveError.BufferTooSmall;

        const from = self.from.name();
        const to = self.to.name();

        buffer[0] = from[0];
        buffer[1] = from[1];
        buffer[2] = to[0];
        buffer[3] = to[1];

        if (self.flag == MoveFlag.Promotion) {
            buffer[4] = self.promotion.piece().lowercaseAscii();
            return buffer[0..5];
        } else {
            return buffer[0..4];
        }
    }
};

const testing = @import("std").testing;

test "move newNonPromotion" {
    const move = try Move.newNonPromotion(Square.E2, Square.E4, MoveFlag.Normal);
    try testing.expectEqual(Square.E2, move.from);
    try testing.expectEqual(Square.E4, move.to);
    try testing.expectEqual(MoveFlag.Normal, move.flag);
    try testing.expectEqual(PromotionPiece.Knight, move.promotion);
}

test "move newPromotion" {
    const move = Move.newPromotion(Square.E7, Square.E8, PromotionPiece.Queen);
    try testing.expectEqual(Square.E7, move.from);
    try testing.expectEqual(Square.E8, move.to);
    try testing.expectEqual(MoveFlag.Promotion, move.flag);
    try testing.expectEqual(PromotionPiece.Queen, move.promotion);
}

test "move castling" {
    const whiteKingside = Move.castling(Flank.Kingside, Color.White);
    try testing.expectEqual(Square.E1, whiteKingside.from);
    try testing.expectEqual(Square.G1, whiteKingside.to);
    try testing.expectEqual(MoveFlag.Castling, whiteKingside.flag);
    try testing.expectEqual(Flank.Kingside, whiteKingside.castlingFlank());

    const blackQueenside = Move.castling(Flank.Queenside, Color.Black);
    try testing.expectEqual(Square.E8, blackQueenside.from);
    try testing.expectEqual(Square.C8, blackQueenside.to);
    try testing.expectEqual(MoveFlag.Castling, blackQueenside.flag);
    try testing.expectEqual(Flank.Queenside, blackQueenside.castlingFlank());
}

test "move uci" {
    var buffer: [10]u8 = undefined;

    const normalMove = try Move.newNonPromotion(Square.E2, Square.E4, MoveFlag.Normal);
    const uci = try normalMove.uci(&buffer);
    try testing.expectEqualSlices(u8, "e2e4", uci);

    const promotionMove = Move.newPromotion(Square.E7, Square.E8, PromotionPiece.Queen);
    const uciPromo = try promotionMove.uci(&buffer);
    try testing.expectEqualSlices(u8, "e7e8q", uciPromo);

    const castlingMove = Move.castling(Flank.Kingside, Color.White);
    const uciCastle = try castlingMove.uci(&buffer);
    try testing.expectEqualSlices(u8, "e1g1", uciCastle);
}

test "move uci buffer too small" {
    var buffer: [3]u8 = undefined;
    const move = try Move.newNonPromotion(Square.E2, Square.E4, MoveFlag.Normal);
    try testing.expectError(MoveError.BufferTooSmall, move.uci(&buffer));
}
