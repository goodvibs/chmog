const std = @import("std");
const ArrayList = @import("std").ArrayList;
const Bitboard = @import("./mod.zig").Bitboard;
const Board = @import("./mod.zig").Board;
const Color = @import("./mod.zig").Color;
const GameResult = @import("./mod.zig").GameResult;
const PositionContext = @import("./mod.zig").PositionContext;

pub const Position = struct {
    board: Board,
    contexts: ArrayList(PositionContext),
    halfmove: u10,
    gameResult: ?GameResult,
    sideToMove: Color,

    pub fn initial(allocator: std.mem.Allocator, capacity: usize) !Position {
        return Position{
            .board = Board.initial(),
            .contexts = try ArrayList(PositionContext).initCapacity(allocator, capacity),
            .halfmove = 0,
            .gameResult = null,
            .sideToMove = Color.White,
        };
    }

    pub fn context(self: *const Position) *const PositionContext {
        return &self.contexts.items[self.contexts.items.len - 1];
    }

    pub fn contextMut(self: *Position) *PositionContext {
        return &self.contexts.items[self.contexts.items.len - 1];
    }
};
