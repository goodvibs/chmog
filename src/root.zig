pub usingnamespace @import("mod.zig");

const std = @import("std");

test {
    std.testing.refAllDeclsRecursive(@This());
}
