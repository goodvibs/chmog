const std = @import("std");
const ArrayList = @import("std").ArrayList;
const Move = @import("./mod.zig").Move;
const MoveFlag = @import("./mod.zig").MoveFlag;
const Bitboard = @import("./mod.zig").Bitboard;
const Board = @import("./mod.zig").Board;
const Piece = @import("./mod.zig").Piece;
const Square = @import("./mod.zig").Square;
const Color = @import("./mod.zig").Color;
const GameResult = @import("./mod.zig").GameResult;
const PositionContext = @import("./mod.zig").PositionContext;
const iterSetBits = @import("./mod.zig").utils.iterSetBits;
const singleKnightAttacks = @import("./mod.zig").attacks.singleKnightAttacks;

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

    pub fn addLegalKnightMoves(self: *const Position, moves: *ArrayList(Move), allocator: std.mem.Allocator) !void {
        const movableKnights = self.board.mask(Piece.Knight, self.sideToMove) & ~self.context().pinned;
        const currentSidePieces = self.board.colorMask(self.sideToMove);

        var sourceMasksIter = iterSetBits(movableKnights);
        while (sourceMasksIter.next()) |sourceMask| {
            const source = Square.fromMask(sourceMask) catch unreachable;
            const knightAttacks = singleKnightAttacks(source);
            const knightMoves = knightAttacks & ~currentSidePieces;

            var destMasksIter = iterSetBits(knightMoves);
            while (destMasksIter.next()) |destMask| {
                const dest = Square.fromMask(destMask) catch unreachable;
                try moves.append(allocator, Move.newNonPromotion(source, dest, MoveFlag.Normal));
            }
        }
    }
};
