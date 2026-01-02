const Bitboard = @import("./mod.zig").Bitboard;
const masks = @import("./mod.zig").masks;

pub const File = enum(u3) {
    A = 0,
    B = 1,
    C = 2,
    D = 3,
    E = 4,
    F = 5,
    G = 6,
    H = 7,

    pub fn fromInt(index: u3) File {
        return @enumFromInt(index);
    }

    pub fn int(self: File) u3 {
        return @intFromEnum(self);
    }

    pub fn mask(self: File) Bitboard {
        return masks.FILES[@as(usize, self.int())];
    }

    pub fn lowercaseChar(self: File) u8 {
        return @as(u8, self.int()) + 'a';
    }

    pub fn uppercaseChar(self: File) u8 {
        return @as(u8, self.int()) + 'A';
    }

    pub fn fromLowercaseChar(char: u8) !File {
        if (char < 'a' or char > 'h') return error.InvalidChar;
        const int_: u3 = @truncate(char - 'a');
        return File.fromInt(int_);
    }

    pub fn fromUppercaseChar(char: u8) !File {
        if (char < 'A' or char > 'H') return error.InvalidChar;
        const int_: u3 = @truncate(char - 'A');
        return File.fromInt(int_);
    }

    pub fn left(self: File) !File {
        return self.leftN(1);
    }

    pub fn right(self: File) !File {
        return self.rightN(1);
    }

    pub fn leftN(self: File, n: u3) !File {
        if (n > self.int()) return error.InvalidFile;
        return File.fromInt(self.int() - n);
    }

    pub fn rightN(self: File, n: u3) !File {
        if (n > (File.H.int() - self.int())) return error.InvalidFile;
        return File.fromInt(self.int() + n);
    }
};

const testing = @import("std").testing;

test "file" {
    const files = [8]File{ File.A, File.B, File.C, File.D, File.E, File.F, File.G, File.H };
    const lowercaseChars = [8]u8{ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h' };
    const uppercaseChars = [8]u8{ 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H' };
    for (0..8) |i| {
        const iu3 = @as(u3, @intCast(i));
        const file = File.fromInt(iu3);
        try testing.expectEqual(files[i], file);
        try testing.expectEqual(lowercaseChars[i], files[i].lowercaseChar());
        try testing.expectEqual(uppercaseChars[i], files[i].uppercaseChar());
        try testing.expectEqual(iu3, file.int());
    }
}
