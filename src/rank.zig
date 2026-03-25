//! Chess rank: 1-8 (rows).

const assert = @import("std").debug.assert;
const Bitboard = @import("./root.zig").Bitboard;
const Color = @import("./root.zig").Color;

/// One of 8 chess ranks (1-8, Eight=0, One=7).
pub const Rank = enum(u3) {
    Eight = 0,
    Seven = 1,
    Six = 2,
    Five = 3,
    Four = 4,
    Three = 5,
    Two = 6,
    One = 7,

    /// Creates rank from 0-7 index (Eight=0, One=7).
    pub fn fromInt(index: u3) Rank {
        return @enumFromInt(index);
    }

    /// Returns 0-7 index.
    pub fn int(self: Rank) u3 {
        return @intFromEnum(self);
    }

    /// Returns the bitboard of all squares in this rank.
    pub fn mask(self: Rank) Bitboard {
        const rank_8: Bitboard = 0xFF_00_00_00_00_00_00_00;
        return rank_8 >> (@as(u6, self.int()) * 8);
    }

    /// Returns rank char ('1'-'8').
    pub fn char(self: Rank) u8 {
        return @as(u8, 7 - self.int()) + '1';
    }

    /// Parses rank from char. Asserts char is in '1'-'8'.
    pub fn fromChar(char_: u8) Rank {
        assert(char_ >= '1' and char_ <= '8');
        const sevenMinusInt: u3 = @truncate(char_ - '1');
        return Rank.fromInt(7 - sevenMinusInt);
    }

    /// Returns the rank one step toward 8. Asserts not at rank 8.
    pub fn up(self: Rank) Rank {
        return self.upN(1);
    }

    /// Returns the rank one step toward 1. Asserts not at rank 1.
    pub fn down(self: Rank) Rank {
        return self.downN(1);
    }

    /// Returns the rank n steps toward 8. Asserts in range.
    pub fn upN(self: Rank, n: u3) Rank {
        assert(n <= self.int());
        return Rank.fromInt(self.int() - n);
    }

    /// Returns the rank n steps toward 1. Asserts in range.
    pub fn downN(self: Rank, n: u3) Rank {
        assert(n <= Rank.One.int() - self.int());
        return Rank.fromInt(self.int() + n);
    }

    /// Returns the rank reflected across the board (1<->8).
    pub fn reflected(self: Rank) Rank {
        return Rank.fromInt(Rank.One.int() - self.int());
    }

    /// Returns rank from color's perspective (Black sees reflected ranks).
    pub fn fromPerspective(self: Rank, c: Color) Rank {
        return switch (c) {
            .White => self,
            .Black => self.reflected(),
        };
    }
};

const testing = @import("std").testing;

test "rank fromInt and int" {
    const ranks = [8]Rank{ Rank.Eight, Rank.Seven, Rank.Six, Rank.Five, Rank.Four, Rank.Three, Rank.Two, Rank.One };
    const chars = [8]u8{ '8', '7', '6', '5', '4', '3', '2', '1' };
    for (0..8) |i| {
        const iu3 = @as(u3, @intCast(i));
        const rank = Rank.fromInt(iu3);
        try testing.expectEqual(rank, ranks[i]);
        try testing.expectEqual(rank.char(), chars[i]);
        try testing.expectEqual(rank.int(), iu3);
    }
}

test "rank mask" {
    const rank = Rank.Eight;
    const mask = rank.mask();
    try testing.expect(mask != 0);

    // Each rank should have exactly 8 bits set (one per file)
    try testing.expectEqual(@as(u32, 8), @popCount(mask));

    // Test all ranks have masks
    for (0..8) |i| {
        const r = Rank.fromInt(@as(u3, @intCast(i)));
        const m = r.mask();
        try testing.expectEqual(@as(u32, 8), @popCount(m));
    }
}

test "rank char" {
    try testing.expectEqual('8', Rank.Eight.char());
    try testing.expectEqual('7', Rank.Seven.char());
    try testing.expectEqual('6', Rank.Six.char());
    try testing.expectEqual('5', Rank.Five.char());
    try testing.expectEqual('4', Rank.Four.char());
    try testing.expectEqual('3', Rank.Three.char());
    try testing.expectEqual('2', Rank.Two.char());
    try testing.expectEqual('1', Rank.One.char());
}

test "rank fromChar" {
    try testing.expectEqual(Rank.Eight, Rank.fromChar('8'));
    try testing.expectEqual(Rank.Seven, Rank.fromChar('7'));
    try testing.expectEqual(Rank.Six, Rank.fromChar('6'));
    try testing.expectEqual(Rank.Five, Rank.fromChar('5'));
    try testing.expectEqual(Rank.Four, Rank.fromChar('4'));
    try testing.expectEqual(Rank.Three, Rank.fromChar('3'));
    try testing.expectEqual(Rank.Two, Rank.fromChar('2'));
    try testing.expectEqual(Rank.One, Rank.fromChar('1'));
}

test "rank up" {
    try testing.expectEqual(Rank.Eight, Rank.Seven.up());
    try testing.expectEqual(Rank.Seven, Rank.Six.up());
    try testing.expectEqual(Rank.Six, Rank.Five.up());
    try testing.expectEqual(Rank.Five, Rank.Four.up());
    try testing.expectEqual(Rank.Four, Rank.Three.up());
    try testing.expectEqual(Rank.Three, Rank.Two.up());
    try testing.expectEqual(Rank.Two, Rank.One.up());
}

test "rank down" {
    try testing.expectEqual(Rank.Seven, Rank.Eight.down());
    try testing.expectEqual(Rank.Six, Rank.Seven.down());
    try testing.expectEqual(Rank.Five, Rank.Six.down());
    try testing.expectEqual(Rank.Four, Rank.Five.down());
    try testing.expectEqual(Rank.Three, Rank.Four.down());
    try testing.expectEqual(Rank.Two, Rank.Three.down());
    try testing.expectEqual(Rank.One, Rank.Two.down());
}

test "rank upN" {
    try testing.expectEqual(Rank.Three, Rank.One.upN(2));
    try testing.expectEqual(Rank.Five, Rank.One.upN(4));
    try testing.expectEqual(Rank.Eight, Rank.One.upN(7));
    try testing.expectEqual(Rank.One, Rank.One.upN(0));
}

test "rank downN" {
    try testing.expectEqual(Rank.Six, Rank.Eight.downN(2));
    try testing.expectEqual(Rank.Four, Rank.Eight.downN(4));
    try testing.expectEqual(Rank.One, Rank.Eight.downN(7));
    try testing.expectEqual(Rank.Eight, Rank.Eight.downN(0));
}
