//! Zobrist hash computation for board and position context.

const Bitboard = @import("../root.zig").Bitboard;
const Board = @import("../root.zig").Board;
const Piece = @import("../root.zig").Piece;
const Color = @import("../root.zig").Color;
const Square = @import("../root.zig").Square;
const PositionContext = @import("../root.zig").PositionContext;
const iterSetBits = @import("../root.zig").utils.iterSetBits;
const zobristKeyforPieceSquare = @import("../root.zig").zobrist.zobristKeyForPieceSquare;
const zobristKeyForEnPassantFile = @import("../root.zig").zobrist.zobristKeyForEnPassantFile;
const zobristKeyForCastlingRights = @import("../root.zig").zobrist.zobristKeyForCastlingRights;
const zobristKeyForSideToMove = @import("../root.zig").zobrist.zobristKeyForSideToMove;

/// Computes the Zobrist hash for the board (piece positions).
pub fn computeBoardZobristHash(board: *const Board) Bitboard {
    var hash: Bitboard = 0;
    for (1..7) |i| {
        const piece = Piece.fromInt(@truncate(i));
        const mask = board.pieceMasks[i];
        var iter = iterSetBits(mask);
        for (0..@popCount(mask)) |_| {
            const squareMask = iter.next() orelse unreachable;
            const square = Square.fromMask(squareMask);
            const key = zobristKeyforPieceSquare(piece, square);
            hash ^= key;
        }
    }
    return hash;
}

/// Computes the Zobrist hash for position context (en passant, castling, side).
pub fn computePositionContextZobristHash(context: *const PositionContext) Bitboard {
    var hash: Bitboard = 0;
    hash ^= zobristKeyForEnPassantFile(context.doublePawnPushFile);
    hash ^= zobristKeyForCastlingRights(context.castlingRights);
    return hash;
}
