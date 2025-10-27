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
    zobristHash: Bitboard,

    pub fn blank() Board {
        return Board{
            .pieceMasks = std.mem.zeroes([7]Bitboard),
            .colorMasks = std.mem.zeroes([2]Bitboard),
            .zobristHash = 0,
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
            .zobristHash = 0,
        };
        res.zobristHash = computeBoardZobristHash(&res);
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

    pub fn xorColorMask(self: *Board, color: Color, mask_: Bitboard) void {
        self.colorMasks[@as(usize, color.int())] ^= mask_;
    }

    pub fn togglePieceAt(self: *Board, piece: Piece, at: Square) void {
        self.pieceMasks[@as(usize, piece.int())] ^= at.mask();
        const key = zobristKeyForPieceSquare(piece, at);
        self.zobristHash ^= key;
    }

    pub fn xorOccupiedMask(self: *Board, mask_: Bitboard) void {
        self.pieceMasks[0] ^= mask_;
    }

    pub fn isMaskAttacked(self: *const Board, mask_: Bitboard, byColor: Color) bool {
        const occupied = self.occupiedMask();
        const attackers = self.colorMask(byColor);

        const relevantPawnsMask = multiPawnAttacks(mask_, byColor.other()) & self.pieceMask(Piece.Pawn);
        const relevantKnightsMask = multiKnightAttacks(mask_) & self.pieceMask(Piece.Knight);
        const relevantKingsMask = multiKingAttacks(mask_) & self.pieceMask(Piece.King);

        if ((relevantPawnsMask | relevantKnightsMask | relevantKingsMask) & attackers != 0) {
            return true;
        } else {
            const queens = self.pieceMask(Piece.Queen);
            const diagonalAttackers = (self.pieceMask(Piece.Bishop) | queens) & attackers;
            const orthogonalAttackers = (self.pieceMask(Piece.Rook) | queens) & attackers;

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
