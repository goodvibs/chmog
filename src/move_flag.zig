//! Move type: Normal, Promotion, EnPassant, or Castling.

/// Move flag indicating the type of move.
pub const MoveFlag = enum(u2) {
    Normal = 0,
    Promotion = 1,
    EnPassant = 2,
    Castling = 3,

    /// Creates from 0-3 index.
    pub fn fromInt(index: u2) MoveFlag {
        return @enumFromInt(index);
    }

    /// Returns 0-3 index.
    pub fn int(self: MoveFlag) u2 {
        return @intFromEnum(self);
    }
};
