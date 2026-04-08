//! Perft (perft function) correctness tests using standard positions.

const std = @import("std");
const chmog = @import("chmog");
const Position = chmog.Position;
const PositionContext = chmog.PositionContext;
const perft = @import("perft_common");

const PositionInitError = perft.PositionInitError;

const nodeCountLookups = struct {
    pub const INITIAL_POSITION = [_]u64{
        1, // depth 0
        20, // depth 1
        400, // depth 2
        8902, // depth 3
        197281, // depth 4
        4865609, // depth 5
        119060324, // depth 6
    };

    pub const KIWIPETE = [_]u64{
        1, // depth 0
        48, // depth 1
        2039, // depth 2
        97862, // depth 3
        4085603, // depth 4
        193690690, // depth 5
    };

    pub const POSITION_3 = [_]u64{
        1, // depth 0
        14, // depth 1
        191, // depth 2
        2812, // depth 3
        43238, // depth 4
        674624, // depth 5
        11030083, // depth 6
        178633661, // depth 7
    };

    pub const POSITION_4 = [_]u64{
        1, // depth 0
        6, // depth 1
        264, // depth 2
        9467, // depth 3
        422333, // depth 4
        15833292, // depth 5
    };

    pub const POSITION_5 = [_]u64{
        1, // depth 0
        44, // depth 1
        1486, // depth 2
        62379, // depth 3
        2103487, // depth 4
        89941194, // depth 5
    };
};

const depths = perft.depths;

fn runPerftTest(position: *Position, depth: u8, expected_nodes: u64) !void {
    const nodes = try position.perft(depth);
    try std.testing.expectEqual(expected_nodes, nodes);
}

fn runPerftTestCase(
    comptime createPosition: *const fn (std.mem.Allocator, usize) PositionInitError!Position,
    comptime depth: u8,
    comptime nodeCountLookup: anytype,
) !void {
    const numContexts: usize = depth + 1;

    var buf: [numContexts * @sizeOf(PositionContext)]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var pos = try createPosition(alloc, numContexts);
    defer pos.deinit(alloc);

    try runPerftTest(&pos, depth, nodeCountLookup[depth]);
}

test "perft initial position" {
    try runPerftTestCase(
        perft.createInitialPosition,
        depths.INITIAL_POSITION,
        &nodeCountLookups.INITIAL_POSITION,
    );
}

test "perft kiwipete" {
    try runPerftTestCase(
        perft.createKiwipete,
        depths.KIWIPETE,
        &nodeCountLookups.KIWIPETE,
    );
}

test "perft position 3" {
    try runPerftTestCase(
        perft.createPosition3,
        depths.POSITION_3,
        &nodeCountLookups.POSITION_3,
    );
}

test "perft position 4" {
    try runPerftTestCase(
        perft.createPosition4,
        depths.POSITION_4,
        &nodeCountLookups.POSITION_4,
    );
}

test "perft position 5" {
    try runPerftTestCase(
        perft.createPosition5,
        depths.POSITION_5,
        &nodeCountLookups.POSITION_5,
    );
}
