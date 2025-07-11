const std = @import("std");
const DefaultPrng = @import("std").Random.DefaultPrng;
const Bitboard = @import("./mod.zig").Bitboard;
const Board = @import("./mod.zig").Board;
const CastlingRights = @import("./mod.zig").CastlingRights;
const Color = @import("./mod.zig").Color;
const File = @import("./mod.zig").File;
const Square = @import("./mod.zig").Square;
const Piece = @import("./mod.zig").Piece;
const SquaresMappingLookup = @import("./mod.zig").utils.SquaresMappingLookup;
const iterSetBits = @import("./mod.zig").utils.iterSetBits;

pub const StaleableHash = union {
    upToDate: Bitboard,
    stale: Bitboard,

    pub fn blankStale() StaleableHash {
        return StaleableHash{
            .stale = 0,
        };
    }

    pub fn xor(self: *StaleableHash, bitboard: Bitboard) void {
        self.markStale();
        self.stale ^= bitboard;
    }

    pub fn markStale(self: *StaleableHash) void {
        if (self.* == .stale) return;
        self.* = .{ .stale = self.upToDate };
    }

    pub fn markUpToDate(self: *StaleableHash) void {
        if (self.* == .upToDate) return;
        self.* = .{ .upToDate = self.stale };
    }
};

const ZobristKeysForSquareLookup = SquaresMappingLookup(1, [12]Bitboard);
const SeededZobristTableGenerator = ZobristTableGenerator(31415);

const ZOBRIST_KEYS_FOR_SQUARE_LOOKUP = ZobristKeysForSquareLookup.init(SeededZobristTableGenerator.generateZobristKeysforSquare);

pub fn zobristKeyforPlacedPiece(piece: Piece, color: Color, at: Square) Bitboard {
    return ZOBRIST_KEYS_FOR_SQUARE_LOOKUP.get([1]Square{at})[@as(usize, color.int())][@as(usize, piece.int() - 1)];
}

const ZOBRIST_KEY_FOR_BLACK_TO_MOVE = SeededZobristTableGenerator.generateRandomBitboard();

pub fn zobristKeyForSideToMove(sideToMove: Color) Bitboard {
    return if (sideToMove == Color.Black) ZOBRIST_KEY_FOR_BLACK_TO_MOVE else 0;
}

const ZOBRIST_HASH_FOR_CASTLING_RIGHTS_LOOKUP = SeededZobristTableGenerator.generateZobristKeysforCastlingRights();

pub fn zobristHashForCastlingRights(castlingRights: CastlingRights) Bitboard {
    return ZOBRIST_HASH_FOR_CASTLING_RIGHTS_LOOKUP[@as(usize, castlingRights.mask())];
}

const ZOBRIST_KEY_FOR_EN_PASSANT_FILE = SeededZobristTableGenerator.generateZobristKeysforEnPassantFiles();

pub fn zobristKeyForEnPassantFile(enPassantFile: ?File) Bitboard {
    return if (enPassantFile) |file| ZOBRIST_KEY_FOR_EN_PASSANT_FILE[@as(usize, file.int())] else 0;
}

fn ZobristTableGenerator(comptime seed: u64) type {
    return struct {
        var rng = DefaultPrng.init(seed);

        fn generateRandomBitboard() Bitboard {
            return rng.random().int(Bitboard);
        }

        fn generateZobristKeysforSquare(_: [1]Square) [2][6]Bitboard {
            var table: [2][6]Bitboard = undefined;
            for (0..2) |color| {
                for (0..6) |pieceMinusOne| {
                    table[color][pieceMinusOne] = generateRandomBitboard();
                }
            }
            return table;
        }

        fn generateZobristKeysforCastlingRights() [16]Bitboard {
            var pre: [4]Bitboard = undefined;
            for (0..4) |i| {
                pre[i] = generateRandomBitboard();
            }
            var table: [16]Bitboard = std.mem.zeroes([16]Bitboard);
            for (0..16) |castlingRights| {
                for (0..4) |i| {
                    if (castlingRights & (1 << i) != 0) {
                        table[castlingRights] ^= pre[i];
                    }
                }
            }
            return table;
        }

        fn generateZobristKeysforEnPassantFiles() [8]Bitboard {
            var table: [8]Bitboard = undefined;
            for (0..8) |i| {
                table[i] = generateRandomBitboard();
            }
            return table;
        }
    };
}

pub fn zobristHashForPieceType(where: Bitboard, piece: Piece, color: Color) Bitboard {
    var hash: Bitboard = 0;
    const pieceCount = @popCount(where);
    var iter = iterSetBits(where);
    for (0..pieceCount) |_| {
        const mask = iter.next() orelse unreachable;
        const square = Square.fromMask(mask) catch unreachable;
        const key = zobristKeyforPlacedPiece(piece, color, square);
        hash ^= key;
    }
    return hash;
}

pub fn zobristHashForBoard(board: Board) Bitboard {
    var hash: Bitboard = 0;
    for (1..8) |i| {
        const piece = Piece.fromInt(@truncate(i)) catch unreachable;
        for (0..2) |j| {
            const color = Color.fromInt(@truncate(i));
            const mask = board.pieceMasks[i] & board.colorMasks[j];
            const hashForPieceType = zobristHashForPieceType(mask, piece, color);
            hash ^= hashForPieceType;
        }
    }
    return hash;
}
