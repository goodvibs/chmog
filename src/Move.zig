const std = @import("std");
const Color = @import("./mod.zig").Color;
const Square = @import("./mod.zig").Square;
const PromotionPiece = @import("./mod.zig").PromotionPiece;
const MoveFlag = @import("./mod.zig").MoveFlag;

const KINGSIDE_CASTLING_BY_COLOR = [2]Move{
    Move.newNonPromotion(Square.E1, Square.G1, MoveFlag.Castling),
    Move.newNonPromotion(Square.E8, Square.G8, MoveFlag.Castling),
};

const QUEENSIDE_CASTLING_BY_COLOR = [2]Move{
    Move.newNonPromotion(Square.E1, Square.C1, MoveFlag.Castling),
    Move.newNonPromotion(Square.E8, Square.C8, MoveFlag.Castling),
};

pub const Move = packed struct {
    from: Square,
    to: Square,
    promotion: PromotionPiece,
    flag: MoveFlag,

    pub const DEFAULT_PROMOTION = PromotionPiece.Knight;

    pub fn newNonPromotion(from: Square, to: Square, flag: MoveFlag) Move {
        return Move{
            .from = from,
            .to = to,
            .promotion = DEFAULT_PROMOTION,
            .flag = flag,
        };
    }

    pub fn newPromotion(from: Square, to: Square, promotion: PromotionPiece) Move {
        return Move{
            .from = from,
            .to = to,
            .promotion = promotion,
            .flag = MoveFlag.Promotion,
        };
    }

    pub fn kingsideCastling(color: Color) Move {
        return KINGSIDE_CASTLING_BY_COLOR[@as(usize, color.int())];
    }

    pub fn queensideCastling(color: Color) Move {
        return QUEENSIDE_CASTLING_BY_COLOR[@as(usize, color.int())];
    }

    pub fn uci(self: Move, buffer: []u8) ![]const u8 {
        if (buffer.len < 5) return error.BufferTooSmall;

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
    const whiteKingside = Move.kingsideCastling(Color.White);
    try testing.expectEqual(Square.E1, whiteKingside.from);
    try testing.expectEqual(Square.G1, whiteKingside.to);
    try testing.expectEqual(MoveFlag.Castling, whiteKingside.flag);

    const blackQueenside = Move.queensideCastling(Color.Black);
    try testing.expectEqual(Square.E8, blackQueenside.from);
    try testing.expectEqual(Square.C8, blackQueenside.to);
    try testing.expectEqual(MoveFlag.Castling, blackQueenside.flag);
}

test "move uci" {
    var buffer: [10]u8 = undefined;

    const normalMove = Move.newNonPromotion(Square.E2, Square.E4, MoveFlag.Normal);
    const uci = try normalMove.uci(&buffer);
    try testing.expectEqualSlices(u8, "e2e4", uci);

    const promotionMove = Move.newPromotion(Square.E7, Square.E8, PromotionPiece.Queen);
    const uciPromo = try promotionMove.uci(&buffer);
    try testing.expectEqualSlices(u8, "e7e8q", uciPromo);

    const castlingMove = Move.kingsideCastling(Color.White);
    const uciCastle = try castlingMove.uci(&buffer);
    try testing.expectEqualSlices(u8, "e1g1", uciCastle);
}

test "move uci buffer too small" {
    var buffer: [3]u8 = undefined;
    const move = Move.newNonPromotion(Square.E2, Square.E4, MoveFlag.Normal);
    try testing.expectError(error.BufferTooSmall, move.uci(&buffer));
}
