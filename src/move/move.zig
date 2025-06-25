const std = @import("std");

const Square = @import("../mod.zig").Square;
const PromotionPiece = @import("../mod.zig").PromotionPiece;
const MoveFlag = @import("mod.zig").MoveFlag;

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

    pub fn uci(self: Move, buffer: []u8) ![]const u8 {
        const isPromotion = self.flag == MoveFlag.Promotion;
        const from = self.from.name();
        const to = self.to.name();
        const promotion = if (isPromotion) self.promotion.piece().lowercaseAscii() else "";
        return std.fmt.bufPrint(buffer, "{s}{s}{s}", .{ from, to, promotion });
    }
};
