const std = @import("std");
const ArrayList = @import("std").ArrayList;
const Move = @import("./mod.zig").Move;
const MoveFlag = @import("./mod.zig").MoveFlag;
const Bitboard = @import("./mod.zig").Bitboard;
const Board = @import("./mod.zig").Board;
const Rank = @import("./mod.zig").Rank;
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
    currentContext: PositionContext,
    previousContexts: ArrayList(PositionContext),
    halfmove: u10,
    gameResult: GameResult,
    sideToMove: Color,

    pub fn initial(allocator: std.mem.Allocator, previousContextsCapacity: usize) !Position {
        return Position{
            .board = Board.initial(),
            .currentContext = PositionContext.blank(),
            .previousContexts = try ArrayList(PositionContext).initCapacity(allocator, previousContextsCapacity),
            .halfmove = 0,
            .gameResult = GameResult.None,
            .sideToMove = Color.White,
        };
    }

    pub fn doHalfmoveAndSideToMoveAgree(self: *const Position) bool {
        const isEven = self.halfmove % 2 == 0;
        const isWhite = self.sideToMove == Color.White;
        return isEven == isWhite;
    }

    pub fn isHalfmoveClockPlausible(self: *const Position) bool {
        return self.currentContext.halfmoveClock <= self.halfmove;
    }

    pub fn isInCheckmate(self: *const Position) bool {
        return self.hasMoves();
    }

    pub fn isNotInIllegalCheck(self: *const Position) bool {
        return !self.board.isColorInCheck(self.sideToMove.other());
    }

    fn addLegalKnightMoves(self: *const Position, comptime allocator: std.mem.Allocator, moves: *ArrayList(Move)) !void {
        const movableKnights = self.board.mask(Piece.Knight, self.sideToMove) & ~self.currentContext().pinned;
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
            if (sourceMask & self.currentContext().pinned != 0) {
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

    fn addLegalCastlingMoves(self: *const Position, comptime allocator: std.mem.Allocator, moves: *ArrayList(Move)) !void {
        const castlingRights = self.currentContext().castlingRights;

        if (castlingRights.kingsideForColor(self.sideToMove) and !self.kingsideCastlingOccupied() and !self.kingsideCastlingInCheck()) {
            try moves.append(allocator, Move.kingsideCastling(self.sideToMove));
        }

        if (castlingRights.queensideForColor(self.sideToMove) and !self.queensideCastlingOccupied() and !self.queensideCastlingInCheck()) {
            try moves.append(allocator, Move.queensideCastling(self.sideToMove));
        }
    }

    fn kingsideCastlingOccupied(self: *const Position) bool {
        return self.board.occupiedMask() & kingsideCastlingGapMask(self.sideToMove) != 0;
    }

    fn queensideCastlingOccupied(self: *const Position) bool {
        return self.board.occupiedMask() & queensideCastlingGapMask(self.sideToMove) != 0;
    }

    fn kingsideCastlingInCheck(self: *const Position) bool {
        return self.board.isMaskAttacked(kingsideCastlingCheckMask(self.sideToMove), self.sideToMove.other());
    }

    fn queensideCastlingInCheck(self: *const Position) bool {
        return self.board.isMaskAttacked(queensideCastlingCheckMask(self.sideToMove), self.sideToMove.other());
    }
};

fn kingsideCastlingGapMask(forColor: Color) Bitboard {
    return switch (forColor) {
        .White => Square.F1.mask() | Square.G1.mask(),
        .Black => Square.F8.mask() | Square.G8.mask(),
    };
}

fn queensideCastlingGapMask(forColor: Color) Bitboard {
    return switch (forColor) {
        .White => Square.D1.mask() | Square.C1.mask() | Square.B1.mask(),
        .Black => Square.D8.mask() | Square.C8.mask() | Square.B8.mask(),
    };
}

fn kingsideCastlingCheckMask(forColor: Color) Bitboard {
    return switch (forColor) {
        .White => Square.E1.mask() | Square.F1.mask() | Square.G1.mask(),
        .Black => Square.E8.mask() | Square.F8.mask() | Square.G8.mask(),
    };
}

fn queensideCastlingCheckMask(forColor: Color) Bitboard {
    return switch (forColor) {
        .White => Square.E1.mask() | Square.D1.mask() | Square.C1.mask(),
        .Black => Square.E8.mask() | Square.D8.mask() | Square.C8.mask(),
    };
}
