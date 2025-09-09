const Color = @import("./mod.zig").Color;

pub const CastlingRights = packed struct {
    whiteKingside: bool,
    whiteQueenside: bool,
    blackKingside: bool,
    blackQueenside: bool,

    pub fn none() CastlingRights {
        return CastlingRights{
            .whiteKingside = false,
            .whiteQueenside = false,
            .blackKingside = false,
            .blackQueenside = false,
        };
    }

    pub fn all() CastlingRights {
        return CastlingRights{
            .whiteKingside = true,
            .whiteQueenside = true,
            .blackKingside = true,
            .blackQueenside = true,
        };
    }

    pub fn mask(self: CastlingRights) u4 {
        return @bitCast(self);
    }

    pub fn fromMask(mask_: u4) CastlingRights {
        return @bitCast(mask_);
    }

    pub fn kingsideForColor(self: CastlingRights, color: Color) bool {
        const mask_ = self.mask();
        return mask_ & (@as(u4, 1) << (1 + 2 * @as(u2, color.int())));
    }

    pub fn queensideForColor(self: CastlingRights, color: Color) bool {
        const mask_ = self.mask();
        return mask_ & (@as(u4, 1) << (0 + 2 * @as(u2, color.int())));
    }
};
