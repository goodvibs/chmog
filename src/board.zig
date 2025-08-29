const std = @import("std");
const Bitboard = @import("./mod.zig").Bitboard;
const masks = @import("./mod.zig").masks;
const Piece = @import("./mod.zig").Piece;
const Color = @import("./mod.zig").Color;
const Square = @import("./mod.zig").Square;
const ZobristHash = @import("./mod.zig").zobrist.ZobristHash;
const zobristKeyForPlacedPiece = @import("./mod.zig").zobrist.zobristKeyForPlacedPiece;

pub const Board = struct {
    pieceMasks: [7]Bitboard,
    colorMasks: [2]Bitboard,
    partialZobristHash: ZobristHash,

    pub fn blank() Board {
        return Board{
            .pieceMasks = std.mem.zeroes([7]Bitboard),
            .colorMasks = std.mem.zeroes([2]Bitboard),
            .partialZobristHash = ZobristHash.blankStale(),
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
            .partialZobristHash = ZobristHash.blankStale(),
        };
        res.partialZobristHash = res.calculateZobristHash();
        return res;
    }

    pub fn pieceMask(self: *const Board, piece: Piece) Bitboard {
        return self.pieceMasks[@as(usize, piece.int())];
    }

    pub fn colorMask(self: *const Board, color: Color) Bitboard {
        return self.colorMasks[@as(usize, color.int())];
    }

    pub fn putColor(self: *Board, color: Color, at: Square) void {
        self.colorMasks[@as(usize, color.int())] |= at.mask();
        self.partialZobristHash.markStale();
    }

    pub fn putPiece(self: *Board, piece: Piece, at: Square) void {
        self.pieceMasks[@as(usize, piece.int())] |= at.mask();
        const key = zobristKeyForPlacedPiece(piece, at);
        self.partialZobristHash.xor(key);
    }
};
