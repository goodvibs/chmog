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

    pub fn char(self: Rank) u8 {
        return @as(u8, 7 - self.int()) + '1';
    }

    pub fn fromChar(char_: u8) !Rank {
        if (char_ < '1' or char_ > '8') return error.InvalidChar;
        const sevenMinusInt: u3 = @truncate(char_ - '1');
        return Rank.fromInt(7 - sevenMinusInt);
    }

    pub fn up(self: Rank) !Rank {
        return self.upN(1);
    }

    pub fn down(self: Rank) !Rank {
        return self.downN(1);
    }

    pub fn upN(self: Rank, n: u3) !Rank {
        if (n > self.int()) return error.InvalidRank;
        return Rank.fromInt(self.int() - n);
    }

    pub fn downN(self: Rank, n: u3) !Rank {
        if (n > Rank.One.int() - self.int()) return error.InvalidRank;
        return Rank.fromInt(self.int() + n);
    }
};

const testing = @import("std").testing;

test "rank" {
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
