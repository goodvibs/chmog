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
