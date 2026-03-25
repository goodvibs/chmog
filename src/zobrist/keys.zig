//! Zobrist key lookup for piece-square, en passant, castling, side to move.

const assert = @import("std").debug.assert;
const Bitboard = @import("../root.zig").Bitboard;
const Piece = @import("../root.zig").Piece;
const Square = @import("../root.zig").Square;
const File = @import("../root.zig").File;
const CastlingRights = @import("../root.zig").CastlingRights;
const Color = @import("../root.zig").Color;
const bytesToValue = @import("std").mem.bytesToValue;

const NUM_PIECE_SQUARE_KEYS = 6 * 64;
const NUM_EN_PASSANT_FILE_KEYS = 8;
const NUM_CASTLING_RIGHTS_KEYS = 16;
const NUM_SIDE_TO_MOVE_KEYS = 1;

/// Total number of Zobrist keys (piece-square + en passant + castling + side).
pub const NUM_KEYS = NUM_PIECE_SQUARE_KEYS + NUM_EN_PASSANT_FILE_KEYS + NUM_CASTLING_RIGHTS_KEYS + NUM_SIDE_TO_MOVE_KEYS;

const ZOBRIST_KEYS_ARRAY_BYTES = @embedFile("zobristKeys");
const ZOBRIST_KEYS_ARRAY = blk: {
    const expectedType = [NUM_KEYS]Bitboard;
    const expectedSize = @sizeOf(expectedType);
    if (ZOBRIST_KEYS_ARRAY_BYTES.len != expectedSize) {
        @compileError("Zobrist data size mismatch");
    }
    break :blk bytesToValue(expectedType, ZOBRIST_KEYS_ARRAY_BYTES);
};

const pieceSquareKeys = ZOBRIST_KEYS_ARRAY[0..NUM_PIECE_SQUARE_KEYS];
const enPassantFileKeys = ZOBRIST_KEYS_ARRAY[NUM_PIECE_SQUARE_KEYS .. NUM_PIECE_SQUARE_KEYS + NUM_EN_PASSANT_FILE_KEYS];
const castlingRightsKeys = ZOBRIST_KEYS_ARRAY[NUM_PIECE_SQUARE_KEYS + NUM_EN_PASSANT_FILE_KEYS .. NUM_PIECE_SQUARE_KEYS + NUM_EN_PASSANT_FILE_KEYS + NUM_CASTLING_RIGHTS_KEYS];
const sideToMoveKey = ZOBRIST_KEYS_ARRAY[NUM_PIECE_SQUARE_KEYS + NUM_EN_PASSANT_FILE_KEYS + NUM_CASTLING_RIGHTS_KEYS];

/// Returns the Zobrist key for a piece on a square. Asserts piece is not Null.
pub fn zobristKeyForPieceSquare(piece: Piece, square: Square) Bitboard {
    assert(piece != Piece.Null);
    return pieceSquareKeys[@as(usize, piece.int() - 1) * 64 + @as(usize, square.int())];
}

/// Returns the Zobrist key for en passant file (0 if none).
pub fn zobristKeyForEnPassantFile(enPassantFile: ?File) Bitboard {
    return if (enPassantFile) |file| enPassantFileKeys[@as(usize, file.int())] else 0;
}

/// Returns the Zobrist key for castling rights (0 if none).
pub fn zobristKeyForCastlingRights(castlingRights: CastlingRights) Bitboard {
    const mask = castlingRights.mask();
    return if (mask == 0) 0 else castlingRightsKeys[@as(usize, mask - 1)];
}

/// Returns the Zobrist key for side to move (0 for White, key for Black).
pub fn zobristKeyForSideToMove(sideToMove: Color) Bitboard {
    return if (sideToMove == Color.Black) sideToMoveKey else 0;
}
