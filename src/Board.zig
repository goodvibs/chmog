const mem = @import("std").mem;
const Writer = @import("std").Io.Writer;
const Rank = @import("./mod.zig").Rank;
const File = @import("./mod.zig").File;
const assert = @import("std").debug.assert;
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

pub const BoardRenderOptions = struct { useAscii: bool = false };

pub const Board = struct {
    pieceMasks: [7]Bitboard,
    colorMasks: [2]Bitboard,

    pub fn blank() Board {
        return Board{
            .pieceMasks = mem.zeroes([7]Bitboard),
            .colorMasks = mem.zeroes([2]Bitboard),
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
        return self.colorMask(Color.White) | self.colorMask(Color.Black) == self.occupiedMask();
    }

    pub fn doColorMasksNotConflict(self: *const Board) bool {
        return self.colorMask(Color.White) & self.colorMask(Color.Black) == 0;
    }

    pub fn arePieceMasksValid(self: *const Board) bool {
        var pieceMasksUnion: Bitboard = 0;
        inline for (self.pieceMasks[@as(usize, comptime Piece.Pawn.int())..]) |pieceMask_| {
            if (pieceMasksUnion & pieceMask_ != 0) return false;
            pieceMasksUnion |= pieceMask_;
        }
        return pieceMasksUnion == self.occupiedMask();
    }

    pub fn isValid(self: *const Board) bool {
        return self.doColorMasksUnionToOccupiedMask() and
            self.doColorMasksNotConflict() and
            self.arePieceMasksValid();
    }

    pub fn hasOneKingPerColor(self: *const Board) bool {
        const kingsMask = self.pieceMask(Piece.King);
        return @popCount(kingsMask) == 2 and
            @popCount(kingsMask & self.colorMask(Color.White)) == 1 and
            @popCount(kingsMask & self.colorMask(Color.Black)) == 1;
    }
    pub fn hasNoPawnsInFirstNorLastRank(self: *const Board) bool {
        return self.pieceMask(Piece.Pawn) & (masks.RANK_1 | masks.RANK_8) == 0;
    }

    pub fn isColorInCheck(self: *const Board, color: Color) bool {
        const kingMask = self.mask(Piece.King, color);
        assert(@popCount(kingMask) == 1);
        return self.isSquareAttacked(Square.fromMask(kingMask) catch unreachable, color.other());
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

    pub fn occupiedMask(self: *const Board) Bitboard {
        return self.pieceMask(Piece.Null);
    }

    pub fn isOccupiedAtSquare(self: *const Board, square: Square) bool {
        return self.occupiedMask() & square.mask() != 0;
    }

    pub fn colorAtSquare(self: *const Board, square: Square) ?Color {
        if (self.colorMask(Color.White) & square.mask() != 0) {
            assert(self.isOccupiedAtSquare(square));
            return Color.White;
        } else if (self.colorMask(Color.Black) & square.mask() != 0) {
            assert(self.isOccupiedAtSquare(square));
            return Color.Black;
        } else {
            assert(!self.isOccupiedAtSquare(square));
            return null;
        }
    }

    pub fn pieceAtSquare(self: *const Board, square: Square) Piece {
        inline for (@as(usize, comptime Piece.Pawn.int())..@as(usize, comptime Piece.King.int() + 1)) |pieceInt| {
            const piece = Piece.fromInt(pieceInt) catch unreachable;
            if (self.pieceMask(piece) & square.mask() != 0) {
                assert(self.isOccupiedAtSquare(square));
                return piece;
            }
        }
        assert(!self.isOccupiedAtSquare(square));
        return Piece.Null;
    }

    pub fn xorColorMask(self: *Board, color: Color, mask_: Bitboard) void {
        self.colorMasks[@as(usize, color.int())] ^= mask_;
    }

    pub fn xorPieceMask(self: *Board, piece: Piece, mask_: Bitboard) void {
        self.pieceMasks[@as(usize, piece.int())] ^= mask_;
    }

    pub fn xorOccupiedMask(self: *Board, mask_: Bitboard) void {
        self.xorPieceMask(Piece.Null, mask_);
    }

    pub fn isSquareAttacked(self: *const Board, square: Square, byColor: Color) bool {
        const mask_ = square.mask();
        const occupied = self.occupiedMask();
        const attackers = self.colorMask(byColor);

        const relevantPawnsMask = multiPawnAttacks(mask_, byColor.other()) & self.pieceMask(Piece.Pawn);
        const relevantKnightsMask = singleKnightAttacks(square) & self.pieceMask(Piece.Knight);
        const relevantKingsMask = singleKingAttacks(square) & self.pieceMask(Piece.King);

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

    pub fn render(self: *const Board, options: BoardRenderOptions, out: *Writer) !void {
        _ = try out.write("  ┌───┬───┬───┬───┬───┬───┬───┬───┐\n");

        for (0..8) |rankIdx| {
            const rank = Rank.fromInt(@intCast(rankIdx));
            const rankChar = rank.char();

            try out.print("{c} │", .{rankChar});

            for (0..8) |fileIdx| {
                const file = File.fromInt(@intCast(fileIdx));
                const square = Square.fromRankAndFile(rank, file);

                const occupied = self.isOccupiedAtSquare(square);

                if (occupied) {
                    const piece = self.pieceAtSquare(square);
                    assert(piece != Piece.Null);
                    const color = self.colorAtSquare(square) orelse unreachable;

                    if (options.useAscii) {
                        const char = if (color == Color.White) piece.uppercaseAscii() else piece.lowercaseAscii();
                        try out.print(" {c} │", .{char});
                    } else {
                        // Use filled symbols for black, empty symbols for white
                        const symbol = if (color == Color.White) piece.emptyUnicode() else piece.filledUnicode();
                        try out.print(" {u} │", .{symbol});
                    }
                } else {
                    _ = try out.write("   │");
                }
            }

            _ = try out.write("\n");

            if (rankIdx < 7) {
                _ = try out.write("  ├───┼───┼───┼───┼───┼───┼───┼───┤\n");
            }
        }

        _ = try out.write("  └───┴───┴───┴───┴───┴───┴───┴───┘\n");
        _ = try out.write("    a   b   c   d   e   f   g   h\n");
    }
};

const testing = @import("std").testing;

test "board blank" {
    const board = Board.blank();
    try testing.expectEqual(@as(Bitboard, 0), board.occupiedMask());
    try testing.expectEqual(@as(Bitboard, 0), board.pieceMask(Piece.Pawn));
    try testing.expectEqual(@as(Bitboard, 0), board.colorMask(Color.White));
    try testing.expectEqual(@as(Bitboard, 0), board.colorMask(Color.Black));
}

test "board initial" {
    const board = Board.initial();
    try testing.expect(board.hasOneKingPerColor());
    try testing.expect(board.hasNoPawnsInFirstNorLastRank());
    try testing.expect(board.isValid());

    try testing.expect(board.colorMask(Color.White) != 0);
    try testing.expect(board.colorMask(Color.Black) != 0);

    try testing.expectEqual(board.occupiedMask(), board.colorMask(Color.White) | board.colorMask(Color.Black));
}

test "board mask operations" {
    var board = Board.blank();
    const e4 = Square.E4;

    board.xorPieceMask(Piece.Pawn, e4.mask());
    board.xorColorMask(Color.White, e4.mask());
    board.xorOccupiedMask(e4.mask());

    try testing.expect(board.pieceMask(Piece.Pawn) & e4.mask() != 0);
    try testing.expect(board.colorMask(Color.White) & e4.mask() != 0);
    try testing.expect(board.occupiedMask() & e4.mask() != 0);
    try testing.expectEqual(e4.mask(), board.mask(Piece.Pawn, Color.White));

    board.xorPieceMask(Piece.Pawn, e4.mask());
    board.xorColorMask(Color.White, e4.mask());
    board.xorOccupiedMask(e4.mask());

    try testing.expect(board.pieceMask(Piece.Pawn) & e4.mask() == 0);
    try testing.expect(board.colorMask(Color.White) & e4.mask() == 0);
    try testing.expect(board.occupiedMask() & e4.mask() == 0);
}

test "board isColorInCheck" {
    const board = Board.initial();
    try testing.expect(!board.isColorInCheck(Color.White));
    try testing.expect(!board.isColorInCheck(Color.Black));
}

test "board isSquareAttacked" {
    const board = Board.initial();

    try testing.expect(!board.isSquareAttacked(Square.E4, Color.White));
    try testing.expect(!board.isSquareAttacked(Square.E4, Color.Black));

    var testBoard = Board.blank();
    testBoard.xorPieceMask(Piece.Pawn, Square.E2.mask());
    testBoard.xorColorMask(Color.White, Square.E2.mask());
    testBoard.xorOccupiedMask(Square.E2.mask());

    try testing.expect(testBoard.isSquareAttacked(Square.D3, Color.White));
    try testing.expect(testBoard.isSquareAttacked(Square.F3, Color.White));
    try testing.expect(!testBoard.isSquareAttacked(Square.E3, Color.White));
}
