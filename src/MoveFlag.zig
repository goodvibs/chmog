pub const MoveFlag = enum(u2) {
    Normal = 0,
    Promotion = 1,
    EnPassant = 2,
    Castling = 3,

    pub fn fromInt(index: u2) MoveFlag {
        return @enumFromInt(index);
    }

    pub fn int(self: MoveFlag) u2 {
        return @intFromEnum(self);
    }
};
