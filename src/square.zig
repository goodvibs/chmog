const Bitboard = @import("mod.zig").Bitboard;
const SquareToBitboard = @import("mod.zig").utils.SquareToBitboard;
const Rank = @import("mod.zig").Rank;
const File = @import("mod.zig").File;

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
        [2]u8{ 'a', '8' }, [2]u8{ 'b', '8' }, [2]u8{ 'c', '8' }, [2]u8{ 'd', '8' }, [2]u8{ 'e', '8' }, [2]u8{ 'f', '8' }, [2]u8{ 'g', '8' }, [2]u8{ 'h', '8' },
        [2]u8{ 'a', '7' }, [2]u8{ 'b', '7' }, [2]u8{ 'c', '7' }, [2]u8{ 'd', '7' }, [2]u8{ 'e', '7' }, [2]u8{ 'f', '7' }, [2]u8{ 'g', '7' }, [2]u8{ 'h', '7' },
        [2]u8{ 'a', '6' }, [2]u8{ 'b', '6' }, [2]u8{ 'c', '6' }, [2]u8{ 'd', '6' }, [2]u8{ 'e', '6' }, [2]u8{ 'f', '6' }, [2]u8{ 'g', '6' }, [2]u8{ 'h', '6' },
        [2]u8{ 'a', '5' }, [2]u8{ 'b', '5' }, [2]u8{ 'c', '5' }, [2]u8{ 'd', '5' }, [2]u8{ 'e', '5' }, [2]u8{ 'f', '5' }, [2]u8{ 'g', '5' }, [2]u8{ 'h', '5' },
        [2]u8{ 'a', '4' }, [2]u8{ 'b', '4' }, [2]u8{ 'c', '4' }, [2]u8{ 'd', '4' }, [2]u8{ 'e', '4' }, [2]u8{ 'f', '4' }, [2]u8{ 'g', '4' }, [2]u8{ 'h', '4' },
        [2]u8{ 'a', '3' }, [2]u8{ 'b', '3' }, [2]u8{ 'c', '3' }, [2]u8{ 'd', '3' }, [2]u8{ 'e', '3' }, [2]u8{ 'f', '3' }, [2]u8{ 'g', '3' }, [2]u8{ 'h', '3' },
        [2]u8{ 'a', '2' }, [2]u8{ 'b', '2' }, [2]u8{ 'c', '2' }, [2]u8{ 'd', '2' }, [2]u8{ 'e', '2' }, [2]u8{ 'f', '2' }, [2]u8{ 'g', '2' }, [2]u8{ 'h', '2' },
        [2]u8{ 'a', '1' }, [2]u8{ 'b', '1' }, [2]u8{ 'c', '1' }, [2]u8{ 'd', '1' }, [2]u8{ 'e', '1' }, [2]u8{ 'f', '1' }, [2]u8{ 'g', '1' }, [2]u8{ 'h', '1' },
    };

    pub fn fromInt(index: u6) Square {
        return @enumFromInt(index);
    }

    pub fn int(self: Square) u6 {
        return @intFromEnum(self);
    }

    pub fn fromRankAndFile(rank_: Rank, file_: File) Square {
        return Square.fromInt(@as(u6, rank_.int()) * 8 + @as(u6, file_.int()));
    }

    pub fn rank(self: Square) Rank {
        return Rank.fromInt(@intCast(self.int() / 8));
    }

    pub fn file(self: Square) File {
        return File.fromInt(@intCast(self.int() % 8));
    }

    pub fn fromMask(bitboard: Bitboard) !Square {
        if (bitboard == 0) return error.InvalidBitboard else if (@popCount(bitboard) != 1) return error.MultipleBitsSet;
        return Square.fromInt(@truncate(@clz(bitboard)));
    }

    pub fn mask(self: Square) Bitboard {
        return @as(Bitboard, 1 << 63) >> self.int();
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
        if (self.rank() == Rank.Eight) return null;
        return Square.fromInt(self.int() - 8);
    }

    pub fn down(self: Square) ?Square {
        if (self.rank() == Rank.One) return null;
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
        if (self.file() == File.A or self.rank() == Rank.Eight) return null;
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

    pub fn name(self: Square) [2]u8 {
        return NAMES[self.int()];
    }

    pub fn buildMask(self: Square, acc: Bitboard, next: fn (Square) ?Square) Bitboard {
        const nextSquare = next(self) orelse return acc;
        return nextSquare.buildMask(acc | nextSquare.mask(), next);
    }

    pub fn diagonalsMask(self: Square) Bitboard {
        return DIAGONALS_MASK_LOOKUP.get([1]Square{self});
    }

    pub fn orthogonalsMask(self: Square) Bitboard {
        return ORTHOGONALS_MASK_LOOKUP.get([1]Square{self});
    }
};

fn computeDiagonalsMask(from_: [1]Square) Bitboard {
    const from = from_[0];
    const ascendingUpper = from.buildMask(from.mask(), Square.upRight);
    const ascendingLower = from.buildMask(0, Square.downLeft);
    const descendingUpper = from.buildMask(0, Square.upLeft);
    const descendingLower = from.buildMask(0, Square.downRight);
    return ascendingUpper | ascendingLower | descendingUpper | descendingLower;
}

fn computeOrthogonalsMask(from_: [1]Square) Bitboard {
    const from = from_[0];
    const up_ = from.buildMask(from.mask(), Square.up);
    const down_ = from.buildMask(0, Square.down);
    const left_ = from.buildMask(0, Square.left);
    const right_ = from.buildMask(0, Square.right);
    return up_ | down_ | left_ | right_;
}

const DIAGONALS_MASK_LOOKUP = SquareToBitboard.init(computeDiagonalsMask);
const ORTHOGONALS_MASK_LOOKUP = SquareToBitboard.init(computeOrthogonalsMask);
