const std = @import("std");

const Color = @import("../mod.zig").Color;
const Square = @import("../mod.zig").Square;
const PromotionPiece = @import("../mod.zig").PromotionPiece;
const MoveFlag = @import("mod.zig").MoveFlag;

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
