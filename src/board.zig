const std = @import("std");
const Bitboard = @import("./mod.zig").Bitboard;
const masks = @import("./mod.zig").masks;
const Piece = @import("./mod.zig").Piece;
const Color = @import("./mod.zig").Color;
const Square = @import("./mod.zig").Square;
const singleKnightAttacks = @import("./mod.zig").attacks.singleKnightAttacks;
const singleKingAttacks = @import("./mod.zig").attacks.singleKingAttacks;
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

    pub fn blank() Board {
        return Board{
            .pieceMasks = std.mem.zeroes([7]Bitboard),
            .colorMasks = std.mem.zeroes([2]Bitboard),
        };
    }

    pub fn initial() Board {
        const res = Board{
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
        };
        return res;
    }

    pub fn doColorMasksUnionToOccupiedMask(self: *const Board) bool {
        return self.colorMask(Color.White) | self.colorMask(Color.Black) == self.pieceMask(Piece.Null);
    }

    pub fn doColorMasksNotConflict(self: *const Board) bool {
        return self.colorMask(Color.White) & self.colorMask(Color.Black) == 0;
    }

    pub fn doPieceMasksUnionToOccupiedMask(self: *const Board) bool {
        var pieceMasksUnion = 0;
        inline for (self.pieceMasks[@as(Piece.Pawn.int(), usize)..]) |pieceMask_| {
            pieceMasksUnion |= pieceMask_;
        }
        return pieceMasksUnion;
    }

    pub fn doPieceMasksNumSetBitsEqualOccupiedMaskNumSetBits(self: *const Board) bool {
        var numSetBits = 0;
        inline for (self.pieceMasks[@as(Piece.Pawn.int(), usize)..]) |pieceMask_| {
            numSetBits += @popCount(pieceMask_);
        }
        return numSetBits == @popCount(self.pieceMask(Piece.Null));
    }

    pub fn doMasksNotConflict(self: *const Board) bool {
        return self.doColorMasksUnionToOccupiedMask() and
            self.doColorMasksNotConflict() and
            self.doPieceMasksUnionToOccupiedMask() and
            self.doPieceMasksNumSetBitsEqualOccupiedMaskNumSetBits();
    }

    pub fn hasOneKingPerColor(self: *const Board) bool {
        const kingsMask = self.pieceMask(Piece.King);
        return @popCount(kingsMask == 2) and
            @popCount(kingsMask & self.colorMask(Color.White)) == 1 and
            @popCount(kingsMask & self.colorMask(Color.Black)) == 1;
    }
    pub fn hasNoPawnsInFirstNorLastRank(self: *const Board) bool {
        return self.pieceMask(Piece.Pawn) & (masks.RANK_1 | masks.RANK_8) == 0;
    }

    pub fn hasMaxOneKingInCheck(self: *const Board) bool {
        return self.isColorInCheck(Color.White) and self.isColorInCheck(Color.Black);
    }

    pub fn isColorInCheck(self: *const Board, color: Color) bool {
        const kingSquare = self.colorMask(color) & self.pieceMask(Piece.King);
        return self.isSquareAttacked(kingSquare, color.other());
    }

    pub fn isValid(self: *const Board, checks: anytype) bool {
        inline for (checks) |check| {
            if (!check(self)) {
                return false;
            }
            return true;
        }
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
    }

    pub fn xorOccupiedMask(self: *Board, mask_: Bitboard) void {
        self.pieceMasks[0] ^= mask_;
    }

    pub fn isSquareAttacked(self: *const Board, square: Square, byColor: Color) bool {
        const mask_ = square.mask();
        const occupied = self.occupiedMask();
        const attackers = self.colorMask(byColor);

        const relevantPawnsMask = multiPawnAttacks(mask_, byColor.other()) & self.pieceMask(Piece.Pawn);
        const relevantKnightsMask = singleKnightAttacks(square) & self.pieceMask(Piece.Knight);
        const relevantKingsMask = singleKingAttacks(mask_) & self.pieceMask(Piece.King);

        if ((relevantPawnsMask | relevantKnightsMask | relevantKingsMask) & attackers != 0) {
            return true;
        } else {
            const queens = self.pieceMask(Piece.Queen);
            const diagonalAttackers = (self.pieceMask(Piece.Bishop) | queens) & attackers;
            const orthogonalAttackers = (self.pieceMask(Piece.Rook) | queens) & attackers;

            const relevantDiagonals = square.diagonalsMask();
            const relevantOrthogonals = square.orthogonalsMask();

            const relevantSlidingAttackers =
                (diagonalAttackers & relevantDiagonals) | (orthogonalAttackers & relevantOrthogonals);

            var attackersSquareMasksIter = iterSetBits(relevantSlidingAttackers);
            while (attackersSquareMasksIter.next()) |attackerSquareMask| {
                const attackerSquare = Square.fromMask(attackerSquareMask) catch unreachable;
                const blockers = between(square, attackerSquare) & occupied;
                if (blockers == 0) {
                    return true;
                }
            }

            return false;
        }
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
