const std = @import("std");
const NUM_KEYS = @import("chmog").zobrist.NUM_KEYS;
const clap = @import("clap");
const writeBinaryData = @import("utils.zig").writeBinaryData;

const Algorithm = enum {
    xoshiro256,
    pcg,
    isaac64,

    fn toString(self: Algorithm) []const u8 {
        return switch (self) {
            .xoshiro256 => "xoshiro256",
            .pcg => "pcg",
            .isaac64 => "isaac64",
        };
    }
};

const params = clap.parseParamsComptime(
    \\-h, --help                 Display this help and exit.
    \\    --seed <u64>           Seed for random number generation (default: current timestamp).
    \\    --algorithm <str>      Algorithm: xoshiro256, pcg, isaac64 (default: xoshiro256).
    \\    --output <str>         Output file for zobrist keys.
    \\
);

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const parsers = .{
        .str = clap.parsers.string,
        .u64 = clap.parsers.int(u64, 10),
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        try diag.reportToFile(.stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.helpToFile(.stdout(), clap.Help, &params, .{});
        return;
    }

    const algorithm = if (res.args.algorithm) |algo_str| blk: {
        if (std.mem.eql(u8, algo_str, "xoshiro256")) break :blk Algorithm.xoshiro256;
        if (std.mem.eql(u8, algo_str, "pcg")) break :blk Algorithm.pcg;
        if (std.mem.eql(u8, algo_str, "isaac64")) break :blk Algorithm.isaac64;
        std.debug.print("Error: Invalid algorithm '{s}'. Valid options: xoshiro256, pcg, isaac64\n", .{algo_str});
        std.process.exit(1);
    } else Algorithm.xoshiro256;

    const seed = res.args.seed orelse @as(u64, @intCast(std.time.timestamp()));
    const outputPath = res.args.output orelse "zobristKeys.bin";

    std.debug.print("Generating Zobrist keys with {} (seed: {})\n", .{ algorithm.toString(), seed });

    const zobristKeys = switch (algorithm) {
        .xoshiro256 => generateKeys(std.Random.Xoshiro256, seed),
        .pcg => generateKeys(std.Random.Pcg, seed),
        .isaac64 => generateKeys(std.Random.Isaac64, seed),
    };

    try writeBinaryData(outputPath, zobristKeys);
}

fn generateKeys(comptime RngType: type, seed: u64) [NUM_KEYS]u64 {
    var rng = RngType.init(seed);
    var keys: [NUM_KEYS]u64 = undefined;

    for (&keys) |*key| {
        key.* = rng.random().int(u64);
    }

    return keys;
}
