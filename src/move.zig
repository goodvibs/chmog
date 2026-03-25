//! Move representation: UCI format, castling, promotion.

const assert = @import("std").debug.assert;
const Color = @import("./root.zig").Color;
const Flank = @import("./root.zig").Flank;
const Square = @import("./root.zig").Square;
const PromotionPiece = @import("./root.zig").PromotionPiece;

/// Move flag indicating the type of move.
pub const MoveFlag = enum(u2) {
    Normal = 0,
    Promotion = 1,
    EnPassant = 2,
    Castling = 3,

    /// Creates from 0-3 index.
    pub fn fromInt(index: u2) MoveFlag {
        return @enumFromInt(index);
    }

    /// Returns 0-3 index.
    pub fn int(self: MoveFlag) u2 {
        return @intFromEnum(self);
    }
};

const CASTLING_BY_FLANK_AND_COLOR: [2][2]Move = [2][2]Move{
    .{
        Move.newNonPromotion(Square.E1, Square.G1, MoveFlag.Castling),
        Move.newNonPromotion(Square.E1, Square.C1, MoveFlag.Castling),
    },
    .{
        Move.newNonPromotion(Square.E8, Square.G8, MoveFlag.Castling),
        Move.newNonPromotion(Square.E8, Square.C8, MoveFlag.Castling),
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

    /// Creates a non-promotion move (normal, en passant, or castling). Asserts flag is not Promotion.
    pub fn newNonPromotion(from: Square, to: Square, flag: MoveFlag) Move {
        assert(flag != MoveFlag.Promotion);
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

    /// Returns the flank for a castling move. Asserts castling flag.
    pub fn castlingFlank(self: Move) Flank {
        assert(self.flag == MoveFlag.Castling);
        return if (self.to.int() > self.from.int()) Flank.Kingside else Flank.Queenside;
    }

    /// Writes UCI string (e.g. "e2e4") to buffer. Asserts buffer.len >= 5 (promotions may use 5 chars).
    pub fn uci(self: Move, buffer: []u8) []const u8 {
        assert(buffer.len >= 5);

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
    const move = Move.newNonPromotion(Square.E2, Square.E4, MoveFlag.Normal);
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

    const normalMove = Move.newNonPromotion(Square.E2, Square.E4, MoveFlag.Normal);
    const uci = normalMove.uci(&buffer);
    try testing.expectEqualSlices(u8, "e2e4", uci);

    const promotionMove = Move.newPromotion(Square.E7, Square.E8, PromotionPiece.Queen);
    const uciPromo = promotionMove.uci(&buffer);
    try testing.expectEqualSlices(u8, "e7e8q", uciPromo);

    const castlingMove = Move.castling(Flank.Kingside, Color.White);
    const uciCastle = castlingMove.uci(&buffer);
    try testing.expectEqualSlices(u8, "e1g1", uciCastle);
}
