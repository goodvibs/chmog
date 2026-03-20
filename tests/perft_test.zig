//! Perft (perft function) correctness tests using standard positions.

const std = @import("std");
const chmog = @import("chmog");
const Position = chmog.Position;
const fen = chmog.fen;

fn runPerftTest(allocator: std.mem.Allocator, position: *Position, depth: u8, expected_nodes: u64) !void {
    const nodes = try position.perft(allocator, depth);
    try std.testing.expectEqual(
        expected_nodes,
        nodes,
    );
}


test "perft initial position depth 1" {
    var pos = try Position.initial(std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    pos.board.validate();
    try runPerftTest(std.testing.allocator, &pos, 1, 20);
}

test "perft initial position depth 2" {
    var pos = try Position.initial(std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 2, 400);
}

test "perft initial position depth 3" {
    var pos = try Position.initial(std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 3, 8902);
}

test "perft initial position depth 4" {
    var pos = try Position.initial(std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 4, 197281);
}

test "perft initial position depth 5" {
    var pos = try Position.initial(std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 5, 4865609);
}

test "perft initial position depth 6" {
    var pos = try Position.initial(std.testing.allocator, 64);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 6, 119060324);
}

test "perft kiwipete depth 1" {
    var pos = try fen.parseFen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 1, 48);
}

test "perft kiwipete depth 2" {
    var pos = try fen.parseFen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 2, 2039);
}

test "perft kiwipete depth 3" {
    var pos = try fen.parseFen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 3, 97862);
}

test "perft kiwipete depth 4" {
    var pos = try fen.parseFen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", std.testing.allocator, 64);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 4, 4085603);
}

test "perft kiwipete depth 5" {
    var pos = try fen.parseFen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", std.testing.allocator, 128);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 5, 193690690);
}

test "perft position 3 depth 1" {
    var pos = try fen.parseFen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 1, 14);
}

test "perft position 3 depth 2" {
    var pos = try fen.parseFen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 2, 191);
}

test "perft position 3 depth 3" {
    var pos = try fen.parseFen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 3, 2812);
}

test "perft position 3 depth 4" {
    var pos = try fen.parseFen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 4, 43238);
}

test "perft position 3 depth 5" {
    var pos = try fen.parseFen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", std.testing.allocator, 64);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 5, 674624);
}

test "perft position 3 depth 6" {
    var pos = try fen.parseFen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", std.testing.allocator, 128);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 6, 11030083);
}

test "perft position 3 depth 7" {
    var pos = try fen.parseFen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", std.testing.allocator, 256);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 7, 178633661);
}

test "perft position 4 depth 1" {
    var pos = try fen.parseFen("r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1", std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 1, 6);
}

test "perft position 4 depth 2" {
    var pos = try fen.parseFen("r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1", std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 2, 264);
}

test "perft position 4 depth 3" {
    var pos = try fen.parseFen("r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1", std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 3, 9467);
}

test "perft position 4 depth 4" {
    var pos = try fen.parseFen("r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1", std.testing.allocator, 64);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 4, 422333);
}

test "perft position 4 depth 5" {
    var pos = try fen.parseFen("r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1", std.testing.allocator, 128);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 5, 15833292);
}

test "perft position 5 depth 1" {
    var pos = try fen.parseFen("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 1, 44);
}

test "perft position 5 depth 2" {
    var pos = try fen.parseFen("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 2, 1486);
}

test "perft position 5 depth 3" {
    var pos = try fen.parseFen("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", std.testing.allocator, 32);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 3, 62379);
}

test "perft position 5 depth 4" {
    var pos = try fen.parseFen("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", std.testing.allocator, 64);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 4, 2103487);
}

test "perft position 5 depth 5" {
    var pos = try fen.parseFen("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", std.testing.allocator, 128);
    defer pos.contexts.deinit(std.testing.allocator);
    try runPerftTest(std.testing.allocator, &pos, 5, 89941194);
}
