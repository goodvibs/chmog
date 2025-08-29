const std = @import("std");
const NUM_KEYS = @import("chmog").zobrist.NUM_KEYS;

const GenerateOptions = struct {
    seed: u64,
    algorithm: Algorithm,
};

const Algorithm = enum {
    xoshiro256,
    pcg,
    isaac64,

    fn fromString(str: []const u8) ?Algorithm {
        if (std.mem.eql(u8, str, "xoshiro256")) return .xoshiro256;
        if (std.mem.eql(u8, str, "pcg")) return .pcg;
        if (std.mem.eql(u8, str, "isaac64")) return .isaac64;
        return null;
    }

    fn toString(self: Algorithm) []const u8 {
        return switch (self) {
            .xoshiro256 => "xoshiro256",
            .pcg => "pcg",
            .isaac64 => "isaac64",
        };
    }
};

fn parseArgs(args: [][:0]u8) !GenerateOptions {
    var seed: u64 = @intCast(std.time.timestamp());
    var algorithm: Algorithm = .xoshiro256;

    var i: usize = 1;
    while (i < args.len) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--seed")) {
            i += 1;
            if (i >= args.len) return error.MissingSeedValue;
            seed = std.fmt.parseInt(u64, args[i], 10) catch return error.InvalidSeed;
        } else if (std.mem.eql(u8, arg, "--algorithm")) {
            i += 1;
            if (i >= args.len) return error.MissingAlgorithmValue;
            algorithm = Algorithm.fromString(args[i]) orelse return error.InvalidAlgorithm;
        } else {
            std.debug.print("Unknown argument: {s}\n", .{arg});
            return error.InvalidArgument;
        }

        i += 1;
    }

    return GenerateOptions{
        .seed = seed,
        .algorithm = algorithm,
    };
}

fn printUsage(program_name: []const u8) void {
    std.debug.print("Usage: {s} [OPTIONS]\n", .{program_name});
    std.debug.print("Options:\n", .{});
    std.debug.print("  --seed <number>      Seed for random number generation (default: current timestamp)\n", .{});
    std.debug.print("  --algorithm <name>   Algorithm: xoshiro256, pcg, isaac64 (default: xoshiro256)\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const options = parseArgs(args) catch |err| {
        std.debug.print("Error: {s}\n", .{@errorName(err)});
        printUsage(args[0]);
        std.process.exit(1);
    };

    const zobrist_hashes = switch (options.algorithm) {
        .xoshiro256 => generateHashes(std.Random.Xoshiro256, options.seed),
        .pcg => generateHashes(std.Random.Pcg, options.seed),
        .isaac64 => generateHashes(std.Random.Isaac64, options.seed),
    };

    try writeBinaryData("zobristKeys.bin", zobrist_hashes);
}

fn generateHashes(comptime RngType: type, seed: u64) [NUM_KEYS]u64 {
    var rng = RngType.init(seed);
    var hashes: [NUM_KEYS]u64 = undefined;

    for (&hashes) |*hash| {
        hash.* = rng.random().int(u64);
    }

    return hashes;
}

fn writeBinaryData(asFilename: []const u8, zobrist_hashes: [NUM_KEYS]u64) !void {
    try std.fs.cwd().makePath("data");

    const completeRelativePath = try std.fmt.allocPrint(std.heap.page_allocator, "data/{s}", .{asFilename});
    defer std.heap.page_allocator.free(completeRelativePath);

    var file = try std.fs.cwd().createFile(completeRelativePath, .{});
    defer file.close();

    const bytes = std.mem.sliceAsBytes(zobrist_hashes[0..]);
    try file.writeAll(bytes);

    std.debug.print("Wrote {} bytes to {s}\n", .{ bytes.len, completeRelativePath });
}
