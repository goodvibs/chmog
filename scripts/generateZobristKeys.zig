const std = @import("std");
const NUM_KEYS = @import("chmog").zobrist.NUM_KEYS;
const clap = @import("clap");
const writeBinaryData = @import("binUtils").writeBinaryData;

const params = clap.parseParamsComptime(
    \\-h, --help                 Display this help and exit.
    \\    --seed <u64>           Seed for random number generation (default: current timestamp).
    \\    --algorithm <str>      Algorithm: xoshiro256, pcg, isaac64 (default: xoshiro256).
    \\    --output <str>         Output file for zobrist keys.
    \\
);

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    const allocator = da.allocator();
    defer _ = da.deinit();

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
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

    const algorithm = res.args.algorithm orelse "xoshiro256";
    const seed = res.args.seed orelse @abs(std.time.milliTimestamp());
    const outputPath = res.args.output orelse return error.MissingOutput;

    var zobristKeys: [NUM_KEYS]u64 = undefined;

    if (std.mem.eql(u8, algorithm, "xoshiro256")) {
        zobristKeys = generateKeys(std.Random.Xoshiro256, seed);
    } else if (std.mem.eql(u8, algorithm, "pcg")) {
        zobristKeys = generateKeys(std.Random.Pcg, seed);
    } else if (std.mem.eql(u8, algorithm, "isaac64")) {
        zobristKeys = generateKeys(std.Random.Isaac64, seed);
    } else {
        return error.UnknownAlgorithm;
    }

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
