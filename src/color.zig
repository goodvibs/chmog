pub const Color = enum(u1) {
    White = 0,
    Black = 1,

    pub fn fromInt(index: u1) Color {
        return @enumFromInt(index);
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
    try testing.expectEqual(@as(u1, 1), Color.White.other().int());
    try testing.expectEqual(@as(u1, 0), Color.Black.other().int());
}
