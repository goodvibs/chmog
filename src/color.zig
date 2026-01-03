const Bitboard = @import("./mod.zig").Bitboard;
const Rank = @import("./mod.zig").Rank;
const masks = @import("./mod.zig").masks;

pub const Color = enum(u1) {
    White = 0,
    Black = 1,

    pub fn fromInt(index: u1) Color {
        return @enumFromInt(index);
    }

    pub fn fromIsWhite(isWhite: bool) Color {
        return Color.fromInt(@intFromBool(!isWhite));
    }

    pub fn fromIsBlack(isBlack: bool) Color {
        return Color.fromInt(@intFromBool(isBlack));
    }

    pub fn int(self: Color) u1 {
        return @intFromEnum(self);
    }

    pub fn other(self: Color) Color {
        return Color.fromInt(~self.int());
    }
};

const testing = @import("std").testing;

test "color" {
    try testing.expectEqual(@as(u1, 0), Color.White.int());
    try testing.expectEqual(@as(u1, 1), Color.Black.int());
    try testing.expectEqual(Color.White.other(), Color.Black);
    try testing.expectEqual(Color.Black.other(), Color.White);
}
