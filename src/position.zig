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
const multiPawnAttacks = @import("./mod.zig").attacks.multiPawnAttacks;
const singleKnightAttacks = @import("./mod.zig").attacks.singleKnightAttacks;
const singleBishopAttacks = @import("./mod.zig").attacks.singleBishopAttacks;
const singleRookAttacks = @import("./mod.zig").attacks.singleRookAttacks;
const singleKingAttacks = @import("./mod.zig").attacks.singleKingAttacks;
const edgeToEdge = @import("./mod.zig").utils.edgeToEdge;
const between = @import("./mod.zig").utils.between;

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

    fn addLegalKnightMoves(self: *const Position, comptime allocator: std.mem.Allocator, moves: *ArrayList(Move)) !void {
        const movableKnights = self.board.mask(Piece.Knight, self.sideToMove) & ~self.context().pinned;
        const currentSidePieces = self.board.colorMask(self.sideToMove);

        var sourceMasksIter = iterSetBits(movableKnights);
        while (sourceMasksIter.next()) |sourceMask| {
            const source = Square.fromMask(sourceMask) catch unreachable;
            const attacks = singleKnightAttacks(source);
            const filteredAttacks = attacks & ~currentSidePieces;

            var destMasksIter = iterSetBits(filteredAttacks);
            while (destMasksIter.next()) |destMask| {
                const dest = Square.fromMask(destMask) catch unreachable;
                try moves.append(allocator, Move.newNonPromotion(source, dest, MoveFlag.Normal));
            }
        }
    }

    fn addLegalSlidingPieceMoves(self: *const Position, comptime piece: Piece, comptime allocator: std.mem.Allocator, moves: *ArrayList(Move)) !void {
        const movablePieces = self.board.mask(piece, self.sideToMove);
        const occupiedMask = self.board.occupiedMask();
        const currentSidePieces = self.board.colorMask(self.sideToMove);
        const currentSideKingSquare = Square.fromMask(self.board.mask(Piece.King, self.sideToMove)) catch return error.MultipleKingsForColor;

        var sourceMasksIter = iterSetBits(movablePieces);
        while (sourceMasksIter.next()) |sourceMask| {
            const source = Square.fromMask(sourceMask) catch unreachable;
            const attacks = comptime if (piece == Piece.Bishop) attacks: {
                break :attacks singleBishopAttacks(source, occupiedMask);
            } else if (piece == Piece.Rook) attacks: {
                break :attacks singleRookAttacks(source, occupiedMask);
            } else if (piece == Piece.Queen) attacks: {
                break :attacks singleBishopAttacks(source, occupiedMask) | singleRookAttacks(source, occupiedMask);
            };

            var filteredAttacks = attacks & ~currentSidePieces;
            if (sourceMask & self.context().pinned != 0) {
                const attacksFilter = edgeToEdge(source, currentSideKingSquare);
                filteredAttacks &= attacksFilter;
            }

            var destMasksIter = iterSetBits(filteredAttacks);
            while (destMasksIter.next()) |destMask| {
                const dest = Square.fromMask(destMask) catch unreachable;
                try moves.append(allocator, Move.newNonPromotion(source, dest, MoveFlag.Normal));
            }
        }
    }

    fn addLegalKingMoves(self: *const Position, comptime allocator: std.mem.Allocator, moves: *ArrayList(Move)) !void {
        const source = Square.fromMask(self.board.mask(Piece.King, self.sideToMove)) catch return error.MultipleKingsForColor;
        const attacks = singleKingAttacks(source);
        var destMasksIter = iterSetBits(attacks);
        while (destMasksIter.next()) |destMask| {
            const dest = Square.fromMask(destMask) catch unreachable;
            if (self.isKingMoveSafe(source, dest)) {
                try moves.append(allocator, Move.newNonPromotion(source, dest, MoveFlag.Normal));
            }
        }
    }

    fn isKingMoveSafe(self: *const Position, source: Square, dest: Square) bool {
        const attackers = self.colorMask(self.sideToMove.other()) & !dest.mask();

        if (multiPawnAttacks(dest, self.sideToMove) & self.board.pieceMask(Piece.Pawn) & attackers != 0 or
            singleKnightAttacks(dest) & self.board.pieceMask(Piece.Knight) & attackers != 0 or
            singleKingAttacks(dest) & self.pieceMask(Piece.King) & attackers != 0)
        {
            return false;
        } else {
            const queens = self.board.pieceMask(Piece.Queen);
            const relevantDiagonalAttackers = (self.board.pieceMask(Piece.Bishop) | queens) & attackers & dest.diagonalsMask();
            const relevantOrthogonalAttackers = (self.board.pieceMask(Piece.Rook) | queens) & attackers & dest.orthogonalsMask();
            const relevantSlidingAttackers = relevantDiagonalAttackers | relevantOrthogonalAttackers;

            const occupied = self.board.occupiedMask() ^ (dest.mask() | source.mask());

            var attackerSourceMasksIter = iterSetBits(relevantSlidingAttackers);
            while (attackerSourceMasksIter.next()) |attackerSourceMask| {
                const attackerSource = Square.fromMask(attackerSourceMask) catch unreachable;
                const blockers = between(dest, attackerSource) & occupied;
                if (blockers == 0) {
                    return false;
                }
            }

            return true;
        }
    }
};
