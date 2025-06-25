const Bitboard = @import("mod.zig").Bitboard;

pub const Rank = enum(u3) {
    Eight = 0,
    Seven = 1,
    Six = 2,
    Five = 3,
    Four = 4,
    Three = 5,
    Two = 6,
    One = 7,

    pub fn fromInt(index: u3) Rank {
        return @enumFromInt(index);
    }

    pub fn int(self: Rank) u3 {
        return @intFromEnum(self);
    }

    pub fn mask(self: Rank) Bitboard {
        return 0xFF_00_00_00_00_00_00_00 >> (self.int() * 8);
    }
};

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
};

pub const Square = enum(u6) {
    A8 = 0,
    B8 = 1,
    C8 = 2,
    D8 = 3,
    E8 = 4,
    F8 = 5,
    G8 = 6,
    H8 = 7,
    A7 = 8,
    B7 = 9,
    C7 = 10,
    D7 = 11,
    E7 = 12,
    F7 = 13,
    G7 = 14,
    H7 = 15,
    A6 = 16,
    B6 = 17,
    C6 = 18,
    D6 = 19,
    E6 = 20,
    F6 = 21,
    G6 = 22,
    H6 = 23,
    A5 = 24,
    B5 = 25,
    C5 = 26,
    D5 = 27,
    E5 = 28,
    F5 = 29,
    G5 = 30,
    H5 = 31,
    A4 = 32,
    B4 = 33,
    C4 = 34,
    D4 = 35,
    E4 = 36,
    F4 = 37,
    G4 = 38,
    H4 = 39,
    A3 = 40,
    B3 = 41,
    C3 = 42,
    D3 = 43,
    E3 = 44,
    F3 = 45,
    G3 = 46,
    H3 = 47,
    A2 = 48,
    B2 = 49,
    C2 = 50,
    D2 = 51,
    E2 = 52,
    F2 = 53,
    G2 = 54,
    H2 = 55,
    A1 = 56,
    B1 = 57,
    C1 = 58,
    D1 = 59,
    E1 = 60,
    F1 = 61,
    G1 = 62,
    H1 = 63,

    pub const NAMES = [64][2]u8{
        "a8", "b8", "c8", "d8", "e8", "f8", "g8", "h8",
        "a7", "b7", "c7", "d7", "e7", "f7", "g7", "h7",
        "a6", "b6", "c6", "d6", "e6", "f6", "g6", "h6",
        "a5", "b5", "c5", "d5", "e5", "f5", "g5", "h5",
        "a4", "b4", "c4", "d4", "e4", "f4", "g4", "h4",
        "a3", "b3", "c3", "d3", "e3", "f3", "g3", "h3",
        "a2", "b2", "c2", "d2", "e2", "f2", "g2", "h2",
        "a1", "b1", "c1", "d1", "e1", "f1", "g1", "h1",
    };

    pub fn fromInt(index: u6) Square {
        return @enumFromInt(index);
    }

    pub fn int(self: Square) u6 {
        return @intFromEnum(self);
    }

    pub fn fromRankAndFile(rank_: Rank, file_: File) Square {
        return Square.fromInt(rank_.int() * 8 + file_.int());
    }

    pub fn rank(self: Square) Rank {
        return Rank.fromInt(self.int() / 8);
    }

    pub fn file(self: Square) File {
        return File.fromInt(self.int() % 8);
    }

    pub fn fromMask(bitboard: Bitboard) !Square {
        if (bitboard == 0) return error.InvalidBitboard else if (@popCount(bitboard) != 1) return error.MultipleBitsSet;
        return Square.fromInt(@clz(bitboard));
    }

    pub fn mask(self: Square) Bitboard {
        return 1 << self.int();
    }

    pub fn distanceFromTop(self: Square) u3 {
        return self.rank().int();
    }

    pub fn distanceFromBottom(self: Square) u3 {
        return 7 - self.rank().int();
    }

    pub fn distanceFromLeft(self: Square) u3 {
        return self.file().int();
    }

    pub fn distanceFromRight(self: Square) u3 {
        return 7 - self.file().int();
    }

    pub fn up(self: Square) ?Square {
        if (self.rank() == Rank.One) return null;
        return Square.fromInt(self.int() - 8);
    }

    pub fn down(self: Square) ?Square {
        if (self.rank() == Rank.Eight) return null;
        return Square.fromInt(self.int() + 8);
    }

    pub fn left(self: Square) ?Square {
        if (self.file() == File.A) return null;
        return Square.fromInt(self.int() - 1);
    }

    pub fn right(self: Square) ?Square {
        if (self.file() == File.H) return null;
        return Square.fromInt(self.int() + 1);
    }

    pub fn upLeft(self: Square) ?Square {
        if (self.file() == file.A or self.rank() == Rank.Eight) return null;
        return Square.fromInt(self.int() - 9);
    }

    pub fn upRight(self: Square) ?Square {
        if (self.file() == File.H or self.rank() == Rank.Eight) return null;
        return Square.fromInt(self.int() - 7);
    }

    pub fn downLeft(self: Square) ?Square {
        if (self.file() == File.A or self.rank() == Rank.One) return null;
        return Square.fromInt(self.int() + 7);
    }

    pub fn downRight(self: Square) ?Square {
        if (self.file() == File.H or self.rank() == Rank.One) return null;
        return Square.fromInt(self.int() + 9);
    }

    pub fn name(self: Square) u8 {
        return NAMES[self.int()];
    }
};
