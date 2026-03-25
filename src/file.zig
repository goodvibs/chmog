//! Chess file: a-h (columns).

const assert = @import("std").debug.assert;
const Bitboard = @import("./root.zig").Bitboard;

/// One of 8 chess files (a-h).
pub const File = enum(u3) {
    A = 0,
    B = 1,
    C = 2,
    D = 3,
    E = 4,
    F = 5,
    G = 6,
    H = 7,

    /// Creates file from 0-7 index (A=0, H=7).
    pub fn fromInt(index: u3) File {
        return @enumFromInt(index);
    }

    /// Returns 0-7 index.
    pub fn int(self: File) u3 {
        return @intFromEnum(self);
    }

    /// Returns the bitboard of all squares in this file.
    pub fn mask(self: File) Bitboard {
        const file_a: Bitboard = 0x80_80_80_80_80_80_80_80;
        return file_a >> @as(u6, self.int());
    }

    /// Returns lowercase char ('a'-'h').
    pub fn lowercaseChar(self: File) u8 {
        return @as(u8, self.int()) + 'a';
    }

    /// Returns uppercase char ('A'-'H').
    pub fn uppercaseChar(self: File) u8 {
        return @as(u8, self.int()) + 'A';
    }

    /// Parses file from lowercase char. Asserts char is in 'a'-'h'.
    pub fn fromLowercaseChar(char: u8) File {
        assert(char >= 'a' and char <= 'h');
        const int_: u3 = @truncate(char - 'a');
        return File.fromInt(int_);
    }

    /// Parses file from uppercase char. Asserts char is in 'A'-'H'.
    pub fn fromUppercaseChar(char: u8) File {
        assert(char >= 'A' and char <= 'H');
        const int_: u3 = @truncate(char - 'A');
        return File.fromInt(int_);
    }

    /// Returns the file one step toward A. Asserts not at A.
    pub fn left(self: File) File {
        return self.leftN(1);
    }

    /// Returns the file one step toward H. Asserts not at H.
    pub fn right(self: File) File {
        return self.rightN(1);
    }

    /// Returns the file n steps toward A. Asserts in range.
    pub fn leftN(self: File, n: u3) File {
        assert(n <= self.int());
        return File.fromInt(self.int() - n);
    }

    /// Returns the file n steps toward H. Asserts in range.
    pub fn rightN(self: File, n: u3) File {
        assert(n <= (File.H.int() - self.int()));
        return File.fromInt(self.int() + n);
    }
};

const testing = @import("std").testing;

test "file fromInt and int" {
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

test "file mask" {
    const file = File.A;
    const mask = file.mask();
    try testing.expect(mask != 0);

    // Each file should have exactly 8 bits set (one per rank)
    try testing.expectEqual(@as(u32, 8), @popCount(mask));

    // Test all files have masks
    for (0..8) |i| {
        const f = File.fromInt(@as(u3, @intCast(i)));
        const m = f.mask();
        try testing.expectEqual(@as(u32, 8), @popCount(m));
    }
}

test "file lowercaseChar and uppercaseChar" {
    try testing.expectEqual('a', File.A.lowercaseChar());
    try testing.expectEqual('b', File.B.lowercaseChar());
    try testing.expectEqual('h', File.H.lowercaseChar());

    try testing.expectEqual('A', File.A.uppercaseChar());
    try testing.expectEqual('B', File.B.uppercaseChar());
    try testing.expectEqual('H', File.H.uppercaseChar());
}

test "file fromLowercaseChar" {
    try testing.expectEqual(File.A, File.fromLowercaseChar('a'));
    try testing.expectEqual(File.B, File.fromLowercaseChar('b'));
    try testing.expectEqual(File.C, File.fromLowercaseChar('c'));
    try testing.expectEqual(File.D, File.fromLowercaseChar('d'));
    try testing.expectEqual(File.E, File.fromLowercaseChar('e'));
    try testing.expectEqual(File.F, File.fromLowercaseChar('f'));
    try testing.expectEqual(File.G, File.fromLowercaseChar('g'));
    try testing.expectEqual(File.H, File.fromLowercaseChar('h'));
}

test "file fromUppercaseChar" {
    try testing.expectEqual(File.A, File.fromUppercaseChar('A'));
    try testing.expectEqual(File.B, File.fromUppercaseChar('B'));
    try testing.expectEqual(File.C, File.fromUppercaseChar('C'));
    try testing.expectEqual(File.D, File.fromUppercaseChar('D'));
    try testing.expectEqual(File.E, File.fromUppercaseChar('E'));
    try testing.expectEqual(File.F, File.fromUppercaseChar('F'));
    try testing.expectEqual(File.G, File.fromUppercaseChar('G'));
    try testing.expectEqual(File.H, File.fromUppercaseChar('H'));
}

test "file left" {
    try testing.expectEqual(File.A, File.B.left());
    try testing.expectEqual(File.B, File.C.left());
    try testing.expectEqual(File.C, File.D.left());
    try testing.expectEqual(File.D, File.E.left());
    try testing.expectEqual(File.E, File.F.left());
    try testing.expectEqual(File.F, File.G.left());
    try testing.expectEqual(File.G, File.H.left());
}

test "file right" {
    try testing.expectEqual(File.B, File.A.right());
    try testing.expectEqual(File.C, File.B.right());
    try testing.expectEqual(File.D, File.C.right());
    try testing.expectEqual(File.E, File.D.right());
    try testing.expectEqual(File.F, File.E.right());
    try testing.expectEqual(File.G, File.F.right());
    try testing.expectEqual(File.H, File.G.right());
}

test "file leftN" {
    try testing.expectEqual(File.A, File.C.leftN(2));
    try testing.expectEqual(File.B, File.D.leftN(2));
    try testing.expectEqual(File.A, File.E.leftN(4));
    try testing.expectEqual(File.A, File.A.leftN(0));
    try testing.expectEqual(File.A, File.H.leftN(7));
}

test "file rightN" {
    try testing.expectEqual(File.C, File.A.rightN(2));
    try testing.expectEqual(File.D, File.B.rightN(2));
    try testing.expectEqual(File.E, File.A.rightN(4));
    try testing.expectEqual(File.A, File.A.rightN(0));
    try testing.expectEqual(File.H, File.A.rightN(7));
}
