//! How much runtime validation to run (set from build options via `build_options.level`).

const std = @import("std");

pub const RuntimeSafetyLevel = enum {
    None,
    Light,
    Heavy,
};

/// Maps compiler optimize mode to a default runtime validation level.
pub fn fromOptimize(mode: std.builtin.OptimizeMode) RuntimeSafetyLevel {
    return switch (mode) {
        .Debug => .Heavy,
        .ReleaseSafe => .Light,
        .ReleaseFast, .ReleaseSmall => .None,
    };
}
