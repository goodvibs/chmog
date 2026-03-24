//! Game outcome: None, Win, Loss, or Draw.

/// Game result from a player's perspective.
pub const GameResult = enum(u2) {
    None = 0,
    Win = 1,
    Loss = 2,
    Draw = 3,
};
