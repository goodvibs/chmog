//! Chess color: White or Black.

const Bitboard = @import("./root.zig").Bitboard;
const Rank = @import("./root.zig").Rank;

/// Chess color (White or Black).
pub const Color = enum(u1) {
    White = 0,
    Black = 1,

    /// Creates Color from a 0-based index (0 = White, 1 = Black).
    pub fn fromInt(index: u1) Color {
        return @enumFromInt(index);
    }

    /// Returns White if isWhite is true, Black otherwise.
    pub fn fromIsWhite(isWhite: bool) Color {
        return Color.fromInt(@intFromBool(!isWhite));
    }

    /// Returns Black if isBlack is true, White otherwise.
    pub fn fromIsBlack(isBlack: bool) Color {
        return Color.fromInt(@intFromBool(isBlack));
    }

    /// Returns the 0-based index (0 = White, 1 = Black).
    pub fn int(self: Color) u1 {
        return @intFromEnum(self);
    }

    /// Returns the opposite color.
    pub fn other(self: Color) Color {
        return Color.fromInt(~self.int());
    }

    /// Returns the back rank for this color (rank 1 for White, rank 8 for Black).
    pub fn backRank(self: Color) Rank {
        return switch (self) {
            .White => Rank.One,
            .Black => Rank.Eight,
        };
    }

    /// Returns the rank of the capturing pawn before en passant (rank 6 for White, rank 3 for Black).
    pub fn enPassantSourceRank(self: Color) Rank {
        return switch (self) {
            .White => Rank.Six,
            .Black => Rank.Three,
        };
    }

    /// Returns the rank the capturing pawn moves to after en passant (rank 6 for White, rank 3 for Black).
    pub fn enPassantDestRank(self: Color) Rank {
        return switch (self) {
            .White => Rank.Six,
            .Black => Rank.Three,
        };
    }

    /// Returns the rank of the captured pawn square for en passant (rank 5 for White, rank 4 for Black).
    pub fn enPassantCaptureRank(self: Color) Rank {
        return switch (self) {
            .White => Rank.Five,
            .Black => Rank.Four,
        };
    }
};

const testing = @import("std").testing;

test "color" {
    try testing.expectEqual(@as(u1, 0), Color.White.int());
    try testing.expectEqual(@as(u1, 1), Color.Black.int());
    try testing.expectEqual(Color.White.other(), Color.Black);
    try testing.expectEqual(Color.Black.other(), Color.White);
    try testing.expectEqual(Rank.One, Color.White.backRank());
    try testing.expectEqual(Rank.Eight, Color.Black.backRank());
}
