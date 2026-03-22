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

const MAX_DEPTH: usize = 32;

var buf: [5 * MAX_DEPTH * @sizeOf(PositionContext)]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buf);
var alloc = fba.allocator();

fn runPerftTest(allocator: std.mem.Allocator, position: *Position, depth: u8, expected_nodes: u64) !void {
    var pos = try Position.initial(alloc, MAX_DEPTH);
    defer pos.contexts.deinit(alloc);

    const nodes = try position.perft(allocator, depth);
    try std.testing.expectEqual(
        expected_nodes,
        nodes,
    );
}

test "perft initial position" {
    var pos = try Position.initial(alloc, MAX_DEPTH);
    defer pos.contexts.deinit(alloc);

    const depth = 3;

    try runPerftTest(alloc, &pos, depth, NodeCountLookups.INITIAL_POSITION[depth]);
}

test "perft kiwipete" {
    const fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1";
    var pos = try parseFen(fen, alloc, MAX_DEPTH);
    defer pos.contexts.deinit(alloc);

    const depth = 2;

    try runPerftTest(alloc, &pos, depth, NodeCountLookups.KIWIPETE[depth]);
}

test "perft position 3" {
    const fen = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1";
    var pos = try parseFen(fen, alloc, MAX_DEPTH);
    defer pos.contexts.deinit(alloc);

    const depth = 1;

    try runPerftTest(alloc, &pos, depth, NodeCountLookups.POSITION_3[depth]);
}

test "perft position 4" {
    const fen = "r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1";
    var pos = try parseFen(fen, alloc, MAX_DEPTH);
    defer pos.contexts.deinit(alloc);

    const depth = 3;

    try runPerftTest(alloc, &pos, depth, NodeCountLookups.POSITION_4[depth]);
}

test "perft position 5" {
    const fen = "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8";
    var pos = try parseFen(fen, alloc, MAX_DEPTH);
    defer pos.contexts.deinit(alloc);

    const depth = 2;

    try runPerftTest(alloc, &pos, depth, NodeCountLookups.POSITION_5[depth]);
}
