//! Castling rights (KQkq) for each flank and color.

const Color = @import("./mod.zig").Color;
const Flank = @import("./mod.zig").Flank;
const Square = @import("./mod.zig").Square;

/// Castling rights per color and flank (KQkq in FEN).
pub const CastlingRights = packed struct {
    whiteKingside: bool,
    whiteQueenside: bool,
    blackKingside: bool,
    blackQueenside: bool,

    pub const ALL = CastlingRights{
        .whiteKingside = true,
        .whiteQueenside = true,
        .blackKingside = true,
        .blackQueenside = true,
    };

    pub const NONE = CastlingRights{
        .whiteKingside = false,
        .whiteQueenside = false,
        .blackKingside = false,
        .blackQueenside = false,
    };

    /// Returns the 4-bit mask representation (bits 0-3: whiteKingside, whiteQueenside, blackKingside, blackQueenside).
    pub fn mask(self: CastlingRights) u4 {
        return @bitCast(self);
    }

    /// Returns CastlingRights from a 4-bit mask.
    pub fn fromMask(mask_: u4) CastlingRights {
        return @bitCast(mask_);
    }

    /// Returns the 2-bit mask for this color's castling rights (white: 0b0011, black: 0b1100).
    pub fn colorMask(color: Color) u4 {
        return @as(u4, 0b0011) << (2 * @as(u2, color.int()));
    }

    /// Returns the 2-bit mask for this flank's castling rights (kingside: 0b0101, queenside: 0b1010).
    pub fn sideMask(flank: Flank) u4 {
        return @as(u4, 0b0101) << @as(u2, flank.int());
    }

    /// Returns true if any right in the given mask is set.
    pub fn anyInMask(self: CastlingRights, mask_: u4) bool {
        return self.mask() & mask_ != 0;
    }

    /// Clears all rights in the given mask.
    pub fn clearMask(self: *CastlingRights, mask_: u4) void {
        self.* = CastlingRights.fromMask(self.mask() & ~mask_);
    }

    /// Returns true if castling is allowed for the given flank and color.
    pub fn query(self: CastlingRights, flank: Flank, color: Color) bool {
        return self.anyInMask(CastlingRights.sideMask(flank) & CastlingRights.colorMask(color));
    }

    /// Revokes castling rights when a rook moves or is captured from the given square.
    pub fn clearForRook(self: *CastlingRights, on: Square) void {
        switch (on) {
            .A8 => {
                self.blackQueenside = false;
            },
            .H8 => {
                self.blackKingside = false;
            },
            .A1 => {
                self.whiteQueenside = false;
            },
            .H1 => {
                self.whiteKingside = false;
            },
            else => {},
        }
    }
};

const testing = @import("std").testing;

test "castling rights mask and fromMask" {
    const all = CastlingRights.ALL;
    try testing.expectEqual(@as(u4, 0b1111), all.mask());
    try testing.expectEqual(all, CastlingRights.fromMask(all.mask()));

    const none = CastlingRights.NONE;
    try testing.expectEqual(@as(u4, 0b0000), none.mask());
    try testing.expectEqual(none, CastlingRights.fromMask(none.mask()));

    var custom = CastlingRights{ .whiteKingside = true, .whiteQueenside = false, .blackKingside = true, .blackQueenside = false };
    try testing.expectEqual(@as(u4, 0b0101), custom.mask());
    try testing.expectEqual(custom, CastlingRights.fromMask(custom.mask()));
}

test "castling rights colorMask and sideMask" {
    try testing.expectEqual(@as(u4, 0b0011), CastlingRights.colorMask(Color.White));
    try testing.expectEqual(@as(u4, 0b1100), CastlingRights.colorMask(Color.Black));
    try testing.expectEqual(@as(u4, 0b0101), CastlingRights.sideMask(Flank.Kingside));
    try testing.expectEqual(@as(u4, 0b1010), CastlingRights.sideMask(Flank.Queenside));
}

test "castling rights query" {
    const all = CastlingRights.ALL;
    try testing.expect(all.query(Flank.Kingside, Color.White));
    try testing.expect(all.query(Flank.Queenside, Color.White));
    try testing.expect(all.query(Flank.Kingside, Color.Black));
    try testing.expect(all.query(Flank.Queenside, Color.Black));

    const none = CastlingRights.NONE;
    try testing.expect(!none.query(Flank.Kingside, Color.White));
    try testing.expect(!none.query(Flank.Queenside, Color.Black));

    var whiteOnly = CastlingRights{ .whiteKingside = true, .whiteQueenside = true, .blackKingside = false, .blackQueenside = false };
    try testing.expect(whiteOnly.query(Flank.Kingside, Color.White));
    try testing.expect(whiteOnly.query(Flank.Queenside, Color.White));
    try testing.expect(!whiteOnly.query(Flank.Kingside, Color.Black));
    try testing.expect(!whiteOnly.query(Flank.Queenside, Color.Black));
}

test "castling rights clearForRook" {
    var rights = CastlingRights.ALL;

    rights.clearForRook(Square.A1);
    try testing.expect(!rights.whiteQueenside);
    try testing.expect(rights.whiteKingside);

    rights.clearForRook(Square.H1);
    try testing.expect(!rights.whiteKingside);

    rights = CastlingRights.ALL;
    rights.clearForRook(Square.A8);
    try testing.expect(!rights.blackQueenside);
    try testing.expect(rights.blackKingside);

    rights.clearForRook(Square.H8);
    try testing.expect(!rights.blackKingside);
}

test "castling rights clearMask" {
    var rights = CastlingRights.ALL;
    rights.clearMask(CastlingRights.colorMask(Color.White));
    try testing.expect(!rights.whiteKingside);
    try testing.expect(!rights.whiteQueenside);
    try testing.expect(rights.blackKingside);
    try testing.expect(rights.blackQueenside);

    rights = CastlingRights.ALL;
    rights.clearMask(CastlingRights.sideMask(Flank.Kingside));
    try testing.expect(!rights.whiteKingside);
    try testing.expect(rights.whiteQueenside);
    try testing.expect(!rights.blackKingside);
    try testing.expect(rights.blackQueenside);
}
