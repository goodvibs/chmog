const std = @import("std");
const MagicInfo = @import("../../mod.zig").attacks.magic.MagicInfo;

pub const ROOK_MAGIC_INFO_LOOKUP = std.mem.zeroes([64]MagicInfo);
