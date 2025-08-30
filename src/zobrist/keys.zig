const Bitboard = @import("../mod.zig").Bitboard;
const Piece = @import("../mod.zig").Piece;
const Square = @import("../mod.zig").Square;
const File = @import("../mod.zig").File;
const CastlingRights = @import("../mod.zig").CastlingRights;
const Color = @import("../mod.zig").Color;
const bytesToValue = @import("std").mem.bytesToValue;

const NUM_PIECE_SQUARE_KEYS = 6 * 64;
const NUM_EN_PASSANT_FILE_KEYS = 8;
const NUM_CASTLING_RIGHTS_KEYS = 16;
const NUM_SIDE_TO_MOVE_KEYS = 1;

pub const NUM_KEYS = NUM_PIECE_SQUARE_KEYS + NUM_EN_PASSANT_FILE_KEYS + NUM_CASTLING_RIGHTS_KEYS + NUM_SIDE_TO_MOVE_KEYS;

const ZOBRIST_KEYS_ARRAY_BYTES = @embedFile("zobristKeys");
const ZOBRIST_KEYS_ARRAY = blk: {
    const expectedType = [NUM_KEYS]Bitboard;
    const expectedSize = @sizeOf(expectedType);
    if (ZOBRIST_KEYS_ARRAY_BYTES.len != expectedSize) {
        @compileError("Zobrist data size mismatch");
    }
    break :blk bytesToValue(expectedType, ZOBRIST_KEYS_ARRAY_BYTES[0..expectedSize]);
};

const pieceSquareKeys = ZOBRIST_KEYS_ARRAY[0..NUM_PIECE_SQUARE_KEYS];
const enPassantFileKeys = ZOBRIST_KEYS_ARRAY[NUM_PIECE_SQUARE_KEYS .. NUM_PIECE_SQUARE_KEYS + NUM_EN_PASSANT_FILE_KEYS];
const castlingRightsKeys = ZOBRIST_KEYS_ARRAY[NUM_PIECE_SQUARE_KEYS + NUM_EN_PASSANT_FILE_KEYS .. NUM_PIECE_SQUARE_KEYS + NUM_EN_PASSANT_FILE_KEYS + NUM_CASTLING_RIGHTS_KEYS];
const sideToMoveKey = ZOBRIST_KEYS_ARRAY[NUM_PIECE_SQUARE_KEYS + NUM_EN_PASSANT_FILE_KEYS + NUM_CASTLING_RIGHTS_KEYS];

pub fn zobristKeyForPieceSquare(piece: Piece, square: Square) Bitboard {
    return pieceSquareKeys[@as(usize, piece.int() - 1) * 64 + @as(usize, square.int())];
}

pub fn zobristKeyForEnPassantFile(enPassantFile: ?File) Bitboard {
    return if (enPassantFile) |file| enPassantFileKeys[@as(usize, file.int())] else 0;
}

pub fn zobristKeyForCastlingRights(castlingRights: CastlingRights) Bitboard {
    const mask = castlingRights.mask();
    return if (mask != 0) castlingRightsKeys[@as(usize, mask - 1)] else 0;
}

pub fn zobristKeyForSideToMove(sideToMove: Color) Bitboard {
    return if (sideToMove == Color.Black) sideToMoveKey else 0;
}
