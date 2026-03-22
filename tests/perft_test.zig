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
        8902,
        197281,
        4865609,
        119060324,
    };

    const KIWIPETE = [_]u64{
        1,
        48,
        2039,
        97862,
        4085603,
        193690690,
    };

    const POSITION_3 = [_]u64{
        1,
        14,
        191,
        2812,
        43238,
        674624,
        11030083,
        178633661,
    };

    const POSITION_4 = [_]u64{
        1,
        6,
        264,
        9467,
        422333,
        15833292,
    };

    const POSITION_5 = [_]u64{
        1,
        44,
        1486,
        62379,
        2103487,
        89941194,
    };
};

fn runPerftTest(allocator: std.mem.Allocator, position: *Position, depth: u8, expected_nodes: u64) !void {
    const nodes = try position.perft(allocator, depth);
    try std.testing.expectEqual(expected_nodes, nodes);
}

fn runPerftTestCase(comptime fen: ?[]const u8, comptime depth: u8, comptime expected: u64) !void {
    const numContexts = depth + 1;

    var buf: [(numContexts) * @sizeOf(PositionContext)]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var pos = if (fen) |f|
        try parseFen(f, alloc, numContexts)
    else
        try Position.initial(alloc, numContexts);
    defer pos.contexts.deinit(alloc);

    try runPerftTest(alloc, &pos, depth, expected);
}

test "perft initial position" {
    try runPerftTestCase(null, 3, NodeCountLookups.INITIAL_POSITION[3]);
}

test "perft kiwipete" {
    try runPerftTestCase("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", 2, NodeCountLookups.KIWIPETE[2]);
}

test "perft position 3" {
    try runPerftTestCase("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", 1, NodeCountLookups.POSITION_3[1]);
}

test "perft position 4" {
    try runPerftTestCase("r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1", 3, NodeCountLookups.POSITION_4[3]);
}

test "perft position 5" {
    try runPerftTestCase("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", 2, NodeCountLookups.POSITION_5[2]);
}
