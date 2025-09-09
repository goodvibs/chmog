const std = @import("std");
const Bitboard = @import("./mod.zig").Bitboard;
const masks = @import("./mod.zig").masks;
const Piece = @import("./mod.zig").Piece;
const Color = @import("./mod.zig").Color;
const Square = @import("./mod.zig").Square;
const computeBoardZobristHash = @import("./mod.zig").zobrist.computeBoardZobristHash;
const zobristKeyForPieceSquare = @import("./mod.zig").zobrist.zobristKeyForPieceSquare;
const multiPawnAttacks = @import("./mod.zig").attacks.multiPawnAttacks;
const multiKnightAttacks = @import("./mod.zig").attacks.multiKnightAttacks;
const multiKingAttacks = @import("./mod.zig").attacks.multiKingAttacks;
const singleBishopAttacks = @import("./mod.zig").attacks.singleBishopAttacks;
const singleRookAttacks = @import("./mod.zig").attacks.singleRookAttacks;
const iterSetBits = @import("./mod.zig").utils.iterSetBits;
const between = @import("./mod.zig").utils.between;

pub const Board = struct {
    pieceMasks: [7]Bitboard,
    colorMasks: [2]Bitboard,
    partialZobristHash: Bitboard,

    pub fn blank() Board {
        return Board{
            .pieceMasks = std.mem.zeroes([7]Bitboard),
            .colorMasks = std.mem.zeroes([2]Bitboard),
            .partialZobristHash = 0,
        };
    }

    pub fn initial() Board {
        var res = Board{
            .pieceMasks = [7]Bitboard{
                masks.STARTING_ALL,
                masks.STARTING_PAWNS,
                masks.STARTING_KNIGHTS,
                masks.STARTING_BISHOPS,
                masks.STARTING_ROOKS,
                masks.STARTING_QUEENS,
                masks.STARTING_KINGS,
            },
            .colorMasks = [2]Bitboard{
                masks.STARTING_WHITE,
                masks.STARTING_BLACK,
            },
            .partialZobristHash = 0,
        };
        res.partialZobristHash = computeBoardZobristHash(&res);
        return res;
    }

    pub fn occupiedMask(self: *const Board) Bitboard {
        return self.pieceMasks[0];
    }

    pub fn pieceMask(self: *const Board, piece: Piece) Bitboard {
        return self.pieceMasks[@as(usize, piece.int())];
    }

    pub fn colorMask(self: *const Board, color: Color) Bitboard {
        return self.colorMasks[@as(usize, color.int())];
    }

    pub fn mask(self: *const Board, piece: Piece, color: Color) Bitboard {
        return self.pieceMask(piece) & self.colorMask(color);
    }

    pub fn xorColor(self: *Board, color: Color, mask_: Bitboard) void {
        self.colorMasks[@as(usize, color.int())] ^= mask_;
    }

    pub fn togglePiece(self: *Board, piece: Piece, at: Square) void {
        self.pieceMasks[@as(usize, piece.int())] ^= at.mask();
        const key = zobristKeyForPieceSquare(piece, at);
        self.partialZobristHash ^= key;
    }

    pub fn xorOccupied(self: *Board, mask_: Bitboard) void {
        self.pieceMasks[0] ^= mask_;
    }

    pub fn isMaskAttacked(self: *const Board, mask_: Bitboard, byColor: Color) bool {
        const occupied = self.occupiedMask();
        const attackers = self.colorMask(byColor);

        const attackingPawns = multiPawnAttacks(mask_, byColor.other()) & self.pieceMask(Piece.Pawn) & attackers;
        const attackingKnights = multiKnightAttacks(mask_) & self.pieceMask(Piece.Knight) & attackers;
        const attackingKing = multiKingAttacks(mask_) & self.pieceMask(Piece.King) & attackers;
        if (attackingPawns != 0 or attackingKnights != 0 or attackingKing != 0) {
            return true;
        } else {
            const attackingQueens = self.pieceMask(Piece.Queen) & attackers;
            const diagonalAttackers = (self.pieceMask(Piece.Bishop) | attackingQueens) & attackers;
            const orthogonalAttackers = (self.pieceMask(Piece.Rook) | attackingQueens) & attackers;

            var defendersSquaresMasksIter = iterSetBits(mask_);
            while (defendersSquaresMasksIter.next()) |defendingSquareMask| {
                const defenderSquare = Square.fromMask(defendingSquareMask) catch unreachable;
                const relevantDiagonals = defenderSquare.diagonalsMask();
                const relevantOrthogonals = defenderSquare.orthogonalsMask();

                const relevantSlidingAttackers =
                    (diagonalAttackers & relevantDiagonals) | (orthogonalAttackers & relevantOrthogonals);

                var attackersSquareMasksIter = iterSetBits(relevantSlidingAttackers);
                while (attackersSquareMasksIter.next()) |attackerSquareMask| {
                    const attackerSquare = Square.fromMask(attackerSquareMask) catch unreachable;
                    const blockers = between(defenderSquare, attackerSquare) & occupied;
                    if (blockers == 0) {
                        return true;
                    }
                }
            }

            return false;
        }
    }
};
