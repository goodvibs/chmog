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
        return mask_ & (@as(u4, 1) << (2 * @as(u2, color.int()))) != 0;
    }

    pub fn queensideForColor(self: CastlingRights, color: Color) bool {
        const mask_ = self.mask();
        return mask_ & (@as(u4, 2) << (2 * @as(u2, color.int()))) != 0;
    }
};

const testing = @import("std").testing;

test "castlingRights none and all" {
    const none = CastlingRights.none();
    try testing.expect(!none.whiteKingside);
    try testing.expect(!none.whiteQueenside);
    try testing.expect(!none.blackKingside);
    try testing.expect(!none.blackQueenside);
    try testing.expectEqual(@as(u4, 0), none.mask());

    const all = CastlingRights.all();
    try testing.expect(all.whiteKingside);
    try testing.expect(all.whiteQueenside);
    try testing.expect(all.blackKingside);
    try testing.expect(all.blackQueenside);
    try testing.expectEqual(@as(u4, 0b1111), all.mask());
}

test "castlingRights mask and fromMask" {
    for (0..16) |i| {
        const mask_: u4 = @intCast(i);
        const rights = CastlingRights.fromMask(mask_);
        try testing.expectEqual(mask_, rights.mask());
    }
}

test "castlingRights kingsideForColor" {
    const all = CastlingRights.all();
    try testing.expect(all.kingsideForColor(Color.White));
    try testing.expect(all.kingsideForColor(Color.Black));

    const none = CastlingRights.none();
    try testing.expect(!none.kingsideForColor(Color.White));
    try testing.expect(!none.kingsideForColor(Color.Black));

    // White kingside only (bit 0)
    const whiteKingsideOnly = CastlingRights{
        .whiteKingside = true,
        .whiteQueenside = false,
        .blackKingside = false,
        .blackQueenside = false,
    };
    try testing.expect(whiteKingsideOnly.kingsideForColor(Color.White));
    try testing.expect(!whiteKingsideOnly.kingsideForColor(Color.Black));
    try testing.expect(!whiteKingsideOnly.queensideForColor(Color.White));
    try testing.expect(!whiteKingsideOnly.queensideForColor(Color.Black));

    // Black kingside only (bit 2)
    const blackKingsideOnly = CastlingRights{
        .whiteKingside = false,
        .whiteQueenside = false,
        .blackKingside = true,
        .blackQueenside = false,
    };
    try testing.expect(!blackKingsideOnly.kingsideForColor(Color.White));
    try testing.expect(blackKingsideOnly.kingsideForColor(Color.Black));
    try testing.expect(!blackKingsideOnly.queensideForColor(Color.White));
    try testing.expect(!blackKingsideOnly.queensideForColor(Color.Black));
}

test "castlingRights queensideForColor" {
    const all = CastlingRights.all();
    try testing.expect(all.queensideForColor(Color.White));
    try testing.expect(all.queensideForColor(Color.Black));

    const none = CastlingRights.none();
    try testing.expect(!none.queensideForColor(Color.White));
    try testing.expect(!none.queensideForColor(Color.Black));

    // White queenside only (bit 1)
    const whiteQueensideOnly = CastlingRights{
        .whiteKingside = false,
        .whiteQueenside = true,
        .blackKingside = false,
        .blackQueenside = false,
    };
    try testing.expect(!whiteQueensideOnly.kingsideForColor(Color.White));
    try testing.expect(!whiteQueensideOnly.kingsideForColor(Color.Black));
    try testing.expect(whiteQueensideOnly.queensideForColor(Color.White));
    try testing.expect(!whiteQueensideOnly.queensideForColor(Color.Black));

    // Black queenside only (bit 3)
    const blackQueensideOnly = CastlingRights{
        .whiteKingside = false,
        .whiteQueenside = false,
        .blackKingside = false,
        .blackQueenside = true,
    };
    try testing.expect(!blackQueensideOnly.kingsideForColor(Color.White));
    try testing.expect(!blackQueensideOnly.kingsideForColor(Color.Black));
    try testing.expect(!blackQueensideOnly.queensideForColor(Color.White));
    try testing.expect(blackQueensideOnly.queensideForColor(Color.Black));
}
