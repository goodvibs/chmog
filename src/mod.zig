pub usingnamespace @import("board.zig");
pub usingnamespace @import("castlingRights.zig");
pub usingnamespace @import("color.zig");
pub usingnamespace @import("file.zig");
pub usingnamespace @import("piece.zig");
pub usingnamespace @import("position.zig");
pub usingnamespace @import("positionContext.zig");
pub usingnamespace @import("rank.zig");
pub usingnamespace @import("square.zig");

pub const attacks = @import("attacks/mod.zig");
pub const masks = @import("masks.zig");
pub const move = @import("move/mod.zig");
pub const utils = @import("utils/mod.zig");
pub const zobrist = @import("zobrist.zig");

pub const Bitboard = u64;
