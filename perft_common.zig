//! Standard perft corpus: FEN strings, position factories, and configured perft depths for tests and benches.

const std = @import("std");
const chmog = @import("chmog");
const Position = chmog.Position;
const parseFen = chmog.fen.parseFen;

pub const FenError = chmog.FenError;
pub const PositionInitError = FenError || std.mem.Allocator.Error;

const kiwipete_fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1";
const position_3_fen = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1";
const position_4_fen = "r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1";
const position_5_fen = "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8";

const shallow = struct {
    pub const INITIAL_POSITION: u8 = 5;
    pub const KIWIPETE: u8 = 4;
    pub const POSITION_3: u8 = 5;
    pub const POSITION_4: u8 = 4;
    pub const POSITION_5: u8 = 4;
};

const deep = struct {
    pub const INITIAL_POSITION: u8 = shallow.INITIAL_POSITION + 1;
    pub const KIWIPETE: u8 = shallow.KIWIPETE + 1;
    pub const POSITION_3: u8 = shallow.POSITION_3 + 1;
    pub const POSITION_4: u8 = shallow.POSITION_4 + 1;
    pub const POSITION_5: u8 = shallow.POSITION_5 + 1;
};

const perftDepthLevel = @import("perft_options").depthLevel;

pub const depths = switch (perftDepthLevel) {
    .Shallow => shallow,
    .Deep => deep,
};

pub fn createInitialPosition(allocator: std.mem.Allocator, contexts_capacity: usize) PositionInitError!Position {
    return try Position.initial(allocator, contexts_capacity);
}

pub fn createKiwipete(allocator: std.mem.Allocator, contexts_capacity: usize) PositionInitError!Position {
    return try parseFen(kiwipete_fen, allocator, contexts_capacity);
}

pub fn createPosition3(allocator: std.mem.Allocator, contexts_capacity: usize) PositionInitError!Position {
    return try parseFen(position_3_fen, allocator, contexts_capacity);
}

pub fn createPosition4(allocator: std.mem.Allocator, contexts_capacity: usize) PositionInitError!Position {
    return try parseFen(position_4_fen, allocator, contexts_capacity);
}

pub fn createPosition5(allocator: std.mem.Allocator, contexts_capacity: usize) PositionInitError!Position {
    return try parseFen(position_5_fen, allocator, contexts_capacity);
}
