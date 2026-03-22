//! Perft (perft function) correctness tests using standard positions.

const std = @import("std");
const chmog = @import("chmog");
const Position = chmog.Position;
const PositionContext = chmog.PositionContext;
const parseFen = chmog.fen.parseFen;

const NodeCountLookups = struct {
    const INITIAL_POSITION = [_]u64{
        1, // Depth 0
        20, // Depth 1
        400, // Depth 2
        8902, // Depth 3
        197281, // Depth 4
        4865609, // Depth 5
        119060324, // Depth 6
    };

    const KIWIPETE = [_]u64{
        1, // Depth 0
        48, // Depth 1
        2039, // Depth 2
        97862, // Depth 3
        4085603, // Depth 4
        193690690, // Depth 5
    };

    const POSITION_3 = [_]u64{
        1, // Depth 0
        14, // Depth 1
        191, // Depth 2
        2812, // Depth 3
        43238, // Depth 4
        674624, // Depth 5
        11030083, // Depth 6
        178633661, // Depth 7
    };

    const POSITION_4 = [_]u64{
        1, // Depth 0
        6, // Depth 1
        264, // Depth 2
        9467, // Depth 3
        422333, // Depth 4
        15833292, // Depth 5
    };

    const POSITION_5 = [_]u64{
        1, // Depth 0
        44, // Depth 1
        1486, // Depth 2
        62379, // Depth 3
        2103487, // Depth 4
        89941194, // Depth 5
    };
};

fn runPerftTest(allocator: std.mem.Allocator, position: *Position, depth: u8, expected_nodes: u64) !void {
    const nodes = try position.perft(allocator, depth);
    try std.testing.expectEqual(expected_nodes, nodes);
}

fn fenPositionConstructor(comptime fen: []const u8) *const fn (std.mem.Allocator, usize) anyerror!Position {
    return struct {
        fn call(alloc: std.mem.Allocator, cap: usize) anyerror!Position {
            return parseFen(fen, alloc, cap);
        }
    }.call;
}

fn runPerftTestCase(
    comptime createPosition: *const fn (std.mem.Allocator, usize) anyerror!Position,
    comptime depth: u8,
    comptime expected: u64,
) !void {
    const numContexts = depth + 1;

    var buf: [numContexts * @sizeOf(PositionContext)]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var pos = try createPosition(alloc, numContexts);
    defer pos.contexts.deinit(alloc);

    try runPerftTest(
        alloc,
        &pos,
        depth,
        expected,
    );
}

test "perft initial position" {
    try runPerftTestCase(
        Position.initial,
        3,
        NodeCountLookups.INITIAL_POSITION[3],
    );
}

test "perft kiwipete" {
    try runPerftTestCase(
        fenPositionConstructor("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"),
        2,
        NodeCountLookups.KIWIPETE[2],
    );
}

test "perft position 3" {
    try runPerftTestCase(
        fenPositionConstructor("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"),
        1,
        NodeCountLookups.POSITION_3[1],
    );
}

test "perft position 4" {
    try runPerftTestCase(
        fenPositionConstructor("r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1"),
        3,
        NodeCountLookups.POSITION_4[3],
    );
}

test "perft position 5" {
    try runPerftTestCase(
        fenPositionConstructor("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8"),
        2,
        NodeCountLookups.POSITION_5[2],
    );
}
