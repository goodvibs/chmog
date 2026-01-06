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
    try testing.expectEqual(File.A, try File.fromLowercaseChar('a'));
    try testing.expectEqual(File.B, try File.fromLowercaseChar('b'));
    try testing.expectEqual(File.C, try File.fromLowercaseChar('c'));
    try testing.expectEqual(File.D, try File.fromLowercaseChar('d'));
    try testing.expectEqual(File.E, try File.fromLowercaseChar('e'));
    try testing.expectEqual(File.F, try File.fromLowercaseChar('f'));
    try testing.expectEqual(File.G, try File.fromLowercaseChar('g'));
    try testing.expectEqual(File.H, try File.fromLowercaseChar('h'));
    
    try testing.expectError(error.InvalidChar, File.fromLowercaseChar('`'));
    try testing.expectError(error.InvalidChar, File.fromLowercaseChar('i'));
    try testing.expectError(error.InvalidChar, File.fromLowercaseChar('A'));
    try testing.expectError(error.InvalidChar, File.fromLowercaseChar('0'));
}

test "file fromUppercaseChar" {
    try testing.expectEqual(File.A, try File.fromUppercaseChar('A'));
    try testing.expectEqual(File.B, try File.fromUppercaseChar('B'));
    try testing.expectEqual(File.C, try File.fromUppercaseChar('C'));
    try testing.expectEqual(File.D, try File.fromUppercaseChar('D'));
    try testing.expectEqual(File.E, try File.fromUppercaseChar('E'));
    try testing.expectEqual(File.F, try File.fromUppercaseChar('F'));
    try testing.expectEqual(File.G, try File.fromUppercaseChar('G'));
    try testing.expectEqual(File.H, try File.fromUppercaseChar('H'));
    
    try testing.expectError(error.InvalidChar, File.fromUppercaseChar('@'));
    try testing.expectError(error.InvalidChar, File.fromUppercaseChar('I'));
    try testing.expectError(error.InvalidChar, File.fromUppercaseChar('a'));
    try testing.expectError(error.InvalidChar, File.fromUppercaseChar('0'));
}

test "file left" {
    try testing.expectEqual(File.A, try File.B.left());
    try testing.expectEqual(File.B, try File.C.left());
    try testing.expectEqual(File.C, try File.D.left());
    try testing.expectEqual(File.D, try File.E.left());
    try testing.expectEqual(File.E, try File.F.left());
    try testing.expectEqual(File.F, try File.G.left());
    try testing.expectEqual(File.G, try File.H.left());
    
    try testing.expectError(error.InvalidFile, File.A.left());
}

test "file right" {
    try testing.expectEqual(File.B, try File.A.right());
    try testing.expectEqual(File.C, try File.B.right());
    try testing.expectEqual(File.D, try File.C.right());
    try testing.expectEqual(File.E, try File.D.right());
    try testing.expectEqual(File.F, try File.E.right());
    try testing.expectEqual(File.G, try File.F.right());
    try testing.expectEqual(File.H, try File.G.right());
    
    try testing.expectError(error.InvalidFile, File.H.right());
}

test "file leftN" {
    try testing.expectEqual(File.A, try File.C.leftN(2));
    try testing.expectEqual(File.B, try File.D.leftN(2));
    try testing.expectEqual(File.A, try File.E.leftN(4));
    try testing.expectEqual(File.A, try File.A.leftN(0));
    try testing.expectEqual(File.A, try File.H.leftN(7));
    
    try testing.expectError(error.InvalidFile, File.A.leftN(1));
    try testing.expectError(error.InvalidFile, File.B.leftN(3));
    try testing.expectError(error.InvalidFile, File.C.leftN(4));
}

test "file rightN" {
    try testing.expectEqual(File.C, try File.A.rightN(2));
    try testing.expectEqual(File.D, try File.B.rightN(2));
    try testing.expectEqual(File.E, try File.A.rightN(4));
    try testing.expectEqual(File.A, try File.A.rightN(0));
    try testing.expectEqual(File.H, try File.A.rightN(7));
    
    try testing.expectError(error.InvalidFile, File.H.rightN(1));
    try testing.expectError(error.InvalidFile, File.G.rightN(2));
    try testing.expectError(error.InvalidFile, File.F.rightN(3));
}
