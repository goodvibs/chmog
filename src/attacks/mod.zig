pub const manual = @import("manual.zig");
pub const magic = @import("magic.zig");
pub const precomputed = @import("precomputed.zig");

pub const multiPawnPushes = manual.multiPawnPushes;
pub const multiPawnAttacks = manual.multiPawnAttacks;
pub const multiKnightAttacks = manual.multiKnightAttacks;
pub const singleKnightAttacks = precomputed.singleKnightAttacks;
pub const singleBishopAttacks = magic.singleBishopAttacks;
pub const singleRookAttacks = magic.singleRookAttacks;
pub const multiKingAttacks = manual.multiKingAttacks;
pub const singleKingAttacks = precomputed.singleKingAttacks;
