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
};
