const std = @import("std");
const chmog = @import("chmog");
const PositionContext = chmog.PositionContext;
const perft = @import("perft_common");

const PositionInitError = perft.PositionInitError;

fn printBenchLine(
    stdout: anytype,
    name: []const u8,
    depth: u8,
    nodes: u64,
    elapsedNs: u64,
) !void {
    const ms = @as(f64, @floatFromInt(elapsedNs)) / 1_000_000.0;
    const nodesPerSecond = if (elapsedNs > 0)
        @as(f64, @floatFromInt(nodes)) * 1_000_000_000.0 / @as(f64, @floatFromInt(elapsedNs))
    else
        @as(f64, 0);

    try stdout.print("{s}\tdepth {}\tnodes {}\t{d:.3} ms\t{e:.3} nodes/s\n", .{
        name,
        depth,
        nodes,
        ms,
        nodesPerSecond,
    });
}

fn benchPerftPosition(
    stdout: anytype,
    name: []const u8,
    comptime depth: u8,
    comptime create: fn (std.mem.Allocator, usize) PositionInitError!chmog.Position,
) !void {
    const numContexts: usize = @as(usize, depth) + 1;
    var buf: [numContexts * @sizeOf(PositionContext)]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(buf[0..]);
    const alloc = fba.allocator();

    var pos = try create(alloc, numContexts);
    defer pos.contexts.deinit(alloc);

    var timer = try std.time.Timer.start();
    const nodes = try pos.perft(alloc, depth);
    const elapsedNs = timer.read();

    try printBenchLine(stdout, name, depth, nodes, elapsedNs);
}

pub fn main() !void {
    const stdoutFile = std.fs.File.stdout();
    var printBuf: [4096]u8 = undefined;
    var stdoutWriter = stdoutFile.writer(&printBuf);
    const stdout = &stdoutWriter.interface;

    const depths = perft.depths;

    try benchPerftPosition(stdout, "initial", depths.INITIAL_POSITION, perft.createInitialPosition);
    try benchPerftPosition(stdout, "kiwipete", depths.KIWIPETE, perft.createKiwipete);
    try benchPerftPosition(stdout, "position_3", depths.POSITION_3, perft.createPosition3);
    try benchPerftPosition(stdout, "position_4", depths.POSITION_4, perft.createPosition4);
    try benchPerftPosition(stdout, "position_5", depths.POSITION_5, perft.createPosition5);

    try stdoutWriter.end();
}
