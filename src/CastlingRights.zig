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

    pub fn colorMask(color: Color) u4 {
        return @as(u4, 0b0001) << (2 * @as(u2, color.int()));
    }

    pub fn sideMask(isKingSide: bool) u4 {
        return @as(u4, 0b0101) << (2 * @as(u2, isKingSide));
    }

    pub fn anyInMask(self: CastlingRights, mask_: u4) bool {
        return self.mask() & mask_ != 0;
    }

    pub fn toggleMask(self: *CastlingRights, mask_: u4) void {
        self.* = CastlingRights.fromMask(*self ^ mask_);
    }
};
