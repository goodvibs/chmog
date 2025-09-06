const Bitboard = @import("../mod.zig").Bitboard;
const Board = @import("../mod.zig").Board;
const Piece = @import("../mod.zig").Piece;
const Color = @import("../mod.zig").Color;
const Square = @import("../mod.zig").Square;
const PositionContext = @import("../mod.zig").PositionContext;
const iterSetBits = @import("../mod.zig").utils.iterSetBits;
const zobristKeyforPieceSquare = @import("../mod.zig").zobrist.zobristKeyForPieceSquare;
const zobristKeyForEnPassantFile = @import("../mod.zig").zobrist.zobristKeyForEnPassantFile;
const zobristKeyForCastlingRights = @import("../mod.zig").zobrist.zobristKeyForCastlingRights;
const zobristKeyForSideToMove = @import("../mod.zig").zobrist.zobristKeyForSideToMove;

pub fn computeBoardZobristHash(board: *const Board) Bitboard {
    var hash = 0;
    for (1..7) |i| {
        const piece = Piece.fromInt(@truncate(i)) catch unreachable;
        const mask = board.pieceMasks[i];
        var iter = iterSetBits(mask);
        for (0..@popCount(mask)) |_| {
            const squareMask = iter.next() orelse unreachable;
            const square = Square.fromMask(squareMask) catch unreachable;
            const key = zobristKeyforPieceSquare(piece, square);
            hash ^= key;
        }
    }
    return hash;
}

pub fn computePositionContextZobristHash(context: *const PositionContext) Bitboard {
    var hash = 0;
    hash ^= zobristKeyForEnPassantFile(context.enPassantFile);
    hash ^= zobristKeyForCastlingRights(context.castlingRights);
    return hash;
}
