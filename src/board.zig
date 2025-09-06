const std = @import("std");
const Bitboard = @import("./mod.zig").Bitboard;
const masks = @import("./mod.zig").masks;
const Piece = @import("./mod.zig").Piece;
const Color = @import("./mod.zig").Color;
const Square = @import("./mod.zig").Square;
const computeBoardZobristHash = @import("./mod.zig").zobrist.computeBoardZobristHash;
const zobristKeyForPieceSquare = @import("./mod.zig").zobrist.zobristKeyForPieceSquare;

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

    pub fn pieceMask(self: *const Board, piece: Piece) Bitboard {
        return self.pieceMasks[@as(usize, piece.int())];
    }

    pub fn colorMask(self: *const Board, color: Color) Bitboard {
        return self.colorMasks[@as(usize, color.int())];
    }

    pub fn xorColor(self: *Board, color: Color, mask: Bitboard) void {
        self.colorMasks[@as(usize, color.int())] ^= mask;
    }

    pub fn togglePiece(self: *Board, piece: Piece, at: Square) void {
        self.pieceMasks[@as(usize, piece.int())] ^= at.mask();
        const key = zobristKeyForPieceSquare(piece, at);
        self.partialZobristHash ^= key;
    }

    pub fn xorOccupied(self: *Board, mask: Bitboard) void {
        self.pieceMasks[0] ^= mask;
    }
};
