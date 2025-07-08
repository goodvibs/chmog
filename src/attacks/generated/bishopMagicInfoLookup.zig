const std = @import("std");
const MagicInfo = @import("../../mod.zig").attacks.magic.MagicInfo;

pub const BISHOP_MAGIC_INFO_LOOKUP = std.mem.zeroes([64]MagicInfo);
