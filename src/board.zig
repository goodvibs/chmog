//! Board state representation using bitboards for piece and color masks.

const mem = @import("std").mem;
const Writer = @import("std").Io.Writer;
const Rank = @import("./root.zig").Rank;
const File = @import("./root.zig").File;
const Flank = @import("./root.zig").Flank;
const assert = @import("std").debug.assert;
const Move = @import("./root.zig").Move;
const MoveFlag = @import("./root.zig").MoveFlag;
const Bitboard = @import("./root.zig").Bitboard;
const Piece = @import("./root.zig").Piece;
const PromotionPiece = @import("./root.zig").PromotionPiece;
const Color = @import("./root.zig").Color;
const Square = @import("./root.zig").Square;
const knightAttacks = @import("./root.zig").attacks.knightAttacks;
const kingAttacks = @import("./root.zig").attacks.kingAttacks;
const pawnsAttacks = @import("./root.zig").attacks.pawnsAttacks;
const knightsAttacks = @import("./root.zig").attacks.knightsAttacks;
const kingsAttacks = @import("./root.zig").attacks.kingsAttacks;
const slidingBishopAttacks = @import("./root.zig").attacks.slidingBishopAttacks;
const slidingRookAttacks = @import("./root.zig").attacks.slidingRookAttacks;
const iterSetBits = @import("./root.zig").utils.iterSetBits;
const between = @import("./root.zig").utils.between;

/// Options for board rendering. useAscii: use ASCII (PNBRQK) instead of Unicode symbols.
pub const BoardRenderOptions = struct { useAscii: bool = false };

/// Bitboard-based chess board with piece masks (Null, Pawn..King) and color masks (White, Black).
pub const Board = struct {
    pieceMasks: [7]Bitboard,
    colorMasks: [2]Bitboard,
    /// Cached piece per square (index `square.int()`), derived from `pieceMasks`; kept in sync by rebuilds.
    pieces: [64]Piece,

    /// Returns an empty board with no pieces.
    pub fn blank() Board {
        return Board{
            .pieceMasks = mem.zeroes([7]Bitboard),
            .colorMasks = mem.zeroes([2]Bitboard),
            .pieces = @splat(Piece.Null),
        };
    }

    /// Returns the standard starting position.
    pub fn initial() Board {
        const starting_wp = Rank.Two.mask();
        const starting_wn = Square.B1.mask() | Square.G1.mask();
        const starting_wb = Square.C1.mask() | Square.F1.mask();
        const starting_wr = Square.A1.mask() | Square.H1.mask();
        const starting_wq = Square.D1.mask();
        const starting_wk = Square.E1.mask();

        const starting_bp = Rank.Seven.mask();
        const starting_bn = Square.B8.mask() | Square.G8.mask();
        const starting_bb = Square.C8.mask() | Square.F8.mask();
        const starting_br = Square.A8.mask() | Square.H8.mask();
        const starting_bq = Square.D8.mask();
        const starting_bk = Square.E8.mask();

        const starting_pawns = starting_wp | starting_bp;
        const starting_knights = starting_wn | starting_bn;
        const starting_bishops = starting_wb | starting_bb;
        const starting_rooks = starting_wr | starting_br;
        const starting_queens = starting_wq | starting_bq;
        const starting_kings = starting_wk | starting_bk;

        const starting_white = starting_wp | starting_wn | starting_wb | starting_wr | starting_wq | starting_wk;
        const starting_black = starting_bp | starting_bn | starting_bb | starting_br | starting_bq | starting_bk;

        const starting_all = starting_white | starting_black;

        var board = Board{
            .pieceMasks = [7]Bitboard{
                starting_all,
                starting_pawns,
                starting_knights,
                starting_bishops,
                starting_rooks,
                starting_queens,
                starting_kings,
            },
            .colorMasks = [2]Bitboard{
                starting_white,
                starting_black,
            },
            .pieces = undefined,
        };
        board.rebuildPieceMailboxFromMasks();
        return board;
    }

    /// Fills `pieces` from `pieceMasks` (authoritative). Call after any bitboard mutation that skips make/unmake.
    pub fn rebuildPieceMailboxFromMasks(self: *Board) void {
        for (0..64) |i| {
            const square = Square.fromInt(@as(u6, @intCast(i)));
            self.pieces[i] = pieceFromMasksAt(self, square);
        }
    }

    /// Returns true if color masks union equals occupied mask (internal validation).
    pub fn doColorMasksUnionToOccupiedMask(self: *const Board) bool {
        return self.colorMask(Color.White) | self.colorMask(Color.Black) == self.occupiedMask();
    }

    /// Returns true if color masks do not overlap (internal validation).
    pub fn doColorMasksNotConflict(self: *const Board) bool {
        return self.colorMask(Color.White) & self.colorMask(Color.Black) == 0;
    }

    /// Returns true if piece masks are disjoint and union to occupied (internal validation).
    pub fn doPieceMasksAgree(self: *const Board) bool {
        var pieceMasksUnion: Bitboard = 0;
        inline for (self.pieceMasks[comptime Piece.Pawn.int()..]) |pieceMask_| {
            if (pieceMasksUnion & pieceMask_ != 0) return false;
            pieceMasksUnion |= pieceMask_;
        }
        return pieceMasksUnion == self.occupiedMask();
    }

    /// Returns true if each color has exactly one king.
    pub fn hasOneKingPerColor(self: *const Board) bool {
        const kingsMask = self.pieceMask(Piece.King);
        return @popCount(kingsMask) == 2 and
            @popCount(kingsMask & self.colorMask(Color.White)) == 1 and
            @popCount(kingsMask & self.colorMask(Color.Black)) == 1;
    }

    /// Returns true if no pawns are on rank 1 or 8.
    pub fn hasNoPawnsInFirstNorLastRank(self: *const Board) bool {
        return self.pieceMask(Piece.Pawn) & (Rank.One.mask() | Rank.Eight.mask()) == 0;
    }

    /// Asserts board invariants hold.
    pub fn validate(self: *const Board) void {
        assert(self.doColorMasksUnionToOccupiedMask());
        assert(self.doColorMasksNotConflict());
        assert(self.doPieceMasksAgree());
        assert(self.hasOneKingPerColor());
        assert(self.hasNoPawnsInFirstNorLastRank());
    }

    /// Returns true if the given color's king is attacked.
    pub fn isColorInCheck(self: *const Board, color: Color) bool {
        const kingMask = self.mask(Piece.King, color);
        assert(@popCount(kingMask) == 1);
        return self.isSquareAttacked(Square.fromMask(kingMask), color.other());
    }

    /// Returns the bitboard of squares occupied by the given piece type.
    pub inline fn pieceMask(self: *const Board, piece: Piece) Bitboard {
        return self.pieceMasks[piece.int()];
    }

    /// Returns the bitboard of squares occupied by the given color.
    pub inline fn colorMask(self: *const Board, color: Color) Bitboard {
        return self.colorMasks[color.int()];
    }

    /// Returns the bitboard of squares with the given piece and color.
    pub inline fn mask(self: *const Board, piece: Piece, color: Color) Bitboard {
        return self.pieceMask(piece) & self.colorMask(color);
    }

    /// Returns the bitboard of all occupied squares (pieceMasks[Piece.Null]).
    pub inline fn occupiedMask(self: *const Board) Bitboard {
        return self.pieceMask(Piece.Null);
    }

    /// Returns true if the square has a piece.
    pub inline fn isOccupiedAtSquare(self: *const Board, square: Square) bool {
        return self.occupiedMask() & square.mask() != 0;
    }

    /// Returns the color at the square, or null if empty.
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

    /// Returns the piece at the square, or Piece.Null if empty.
    pub fn pieceAtSquare(self: *const Board, square: Square) Piece {
        return self.pieces[square.int()];
    }

    /// Toggles the given squares in the color mask (XOR).
    pub inline fn xorColorMask(self: *Board, color: Color, mask_: Bitboard) void {
        self.colorMasks[color.int()] ^= mask_;
    }

    /// Toggles the given squares in the piece mask (XOR).
    pub inline fn xorPieceMask(self: *Board, piece: Piece, mask_: Bitboard) void {
        self.pieceMasks[piece.int()] ^= mask_;
    }

    /// Toggles the given squares in the occupied mask (XOR).
    pub inline fn xorOccupiedMask(self: *Board, mask_: Bitboard) void {
        self.xorPieceMask(Piece.Null, mask_);
    }

    /// Applies a castling move. Requires move.flag == MoveFlag.Castling.
    pub fn makeCastlingMove(self: *Board, move: Move, forColor: Color) void {
        applyCastlingXor(self, move, forColor);
        shiftMailboxCastlingMake(self, move, forColor);
    }

    /// Reverts a castling move (same XOR toggle as `makeCastlingMove`; mailbox is updated for the pre-move layout).
    pub fn unmakeCastlingMove(self: *Board, move: Move, forColor: Color) void {
        applyCastlingXor(self, move, forColor);
        shiftMailboxCastlingUnmake(self, move, forColor);
    }

    /// Applies an en passant capture. Requires move.flag == MoveFlag.EnPassant.
    pub fn makeEnPassantMove(self: *Board, move: Move, forColor: Color) void {
        applyEnPassantXor(self, move, forColor);
        shiftMailboxEnPassantMake(self, move, forColor);
    }

    /// Reverts an en passant capture.
    pub fn unmakeEnPassantMove(self: *Board, move: Move, forColor: Color) void {
        applyEnPassantXor(self, move, forColor);
        shiftMailboxEnPassantUnmake(self, move, forColor);
    }

    /// Applies a normal or promotion move. movedPiece: piece on from before move. capturedPiece: piece on to before move, or Piece.Null.
    pub fn makeNormalOrPromotionMove(self: *Board, move: Move, forColor: Color, movedPiece: Piece, capturedPiece: Piece) void {
        applyNormalOrPromotionXor(self, move, forColor, movedPiece, capturedPiece);
        shiftMailboxNormalOrPromotionMake(self, move, movedPiece, capturedPiece);
    }

    /// Reverts a normal or promotion move.
    pub fn unmakeNormalOrPromotionMove(self: *Board, move: Move, forColor: Color, movedPiece: Piece, capturedPiece: Piece) void {
        applyNormalOrPromotionXor(self, move, forColor, movedPiece, capturedPiece);
        shiftMailboxNormalOrPromotionUnmake(self, move, movedPiece, capturedPiece);
    }

    /// Returns true if the square is attacked by any piece of the given color.
    pub fn isSquareAttacked(self: *const Board, square: Square, byColor: Color) bool {
        const mask_ = square.mask();
        const occupied = self.occupiedMask();
        const attackers = self.colorMask(byColor);

        const relevantPawnsMask = pawnsAttacks(mask_, byColor.other()) & self.pieceMask(Piece.Pawn);
        const relevantKnightsMask = knightAttacks(square) & self.pieceMask(Piece.Knight);
        const relevantKingsMask = kingAttacks(square) & self.pieceMask(Piece.King);

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
                const attackerSquare = Square.fromMask(attackerSquareMask);
                const blockers = between(square, attackerSquare) & occupied;
                if (blockers == 0) {
                    return true;
                }
            }

            return false;
        }
    }

    /// Returns true if any square in the mask is attacked by the given color.
    pub fn isMaskAttacked(self: *const Board, mask_: Bitboard, byColor: Color) bool {
        const occupied = self.occupiedMask();
        const attackers = self.colorMask(byColor);

        const relevantPawnsMask = pawnsAttacks(mask_, byColor.other()) & self.pieceMask(Piece.Pawn);
        const relevantKnightsMask = knightsAttacks(mask_) & self.pieceMask(Piece.Knight);
        const relevantKingsMask = kingsAttacks(mask_) & self.pieceMask(Piece.King);

        if ((relevantPawnsMask | relevantKnightsMask | relevantKingsMask) & attackers != 0) {
            return true;
        } else {
            const queens = self.pieceMask(Piece.Queen);
            const diagonalAttackers = (self.pieceMask(Piece.Bishop) | queens) & attackers;
            const orthogonalAttackers = (self.pieceMask(Piece.Rook) | queens) & attackers;

            var defendersSquaresMasksIter = iterSetBits(mask_);
            while (defendersSquaresMasksIter.next()) |defendingSquareMask| {
                const defenderSquare = Square.fromMask(defendingSquareMask);
                const relevantDiagonals = defenderSquare.diagonalsMask();
                const relevantOrthogonals = defenderSquare.orthogonalsMask();

                const relevantSlidingAttackers =
                    (diagonalAttackers & relevantDiagonals) | (orthogonalAttackers & relevantOrthogonals);

                var attackersSquareMasksIter = iterSetBits(relevantSlidingAttackers);
                while (attackersSquareMasksIter.next()) |attackerSquareMask| {
                    const attackerSquare = Square.fromMask(attackerSquareMask);
                    const blockers = between(defenderSquare, attackerSquare) & occupied;
                    if (blockers == 0) {
                        return true;
                    }
                }
            }

            return false;
        }
    }

    /// Renders the board to the writer (ASCII or Unicode).
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

/// Piece type at `square` from `pieceMasks` only (same rule as full mailbox rebuild).
fn pieceFromMasksAt(board: *const Board, square: Square) Piece {
    const m = square.mask();
    inline for (@as(usize, comptime Piece.Pawn.int())..@as(usize, comptime Piece.King.int() + 1)) |pieceInt| {
        const p = Piece.fromInt(@as(u3, @truncate(pieceInt)));
        if (board.pieceMask(p) & m != 0) return p;
    }
    return Piece.Null;
}

fn shiftMailboxCastlingMake(board: *Board, move: Move, forColor: Color) void {
    const flank = move.castlingFlank();
    const rook_from = castlingRookFromSquare(flank, forColor);
    const rook_to = castlingRookToSquare(flank, forColor);
    board.pieces[move.from.int()] = Piece.Null;
    board.pieces[move.to.int()] = Piece.King;
    board.pieces[rook_from.int()] = Piece.Null;
    board.pieces[rook_to.int()] = Piece.Rook;
}

fn shiftMailboxCastlingUnmake(board: *Board, move: Move, forColor: Color) void {
    const flank = move.castlingFlank();
    const rook_from = castlingRookFromSquare(flank, forColor);
    const rook_to = castlingRookToSquare(flank, forColor);
    board.pieces[move.to.int()] = Piece.Null;
    board.pieces[move.from.int()] = Piece.King;
    board.pieces[rook_to.int()] = Piece.Null;
    board.pieces[rook_from.int()] = Piece.Rook;
}

fn shiftMailboxEnPassantMake(board: *Board, move: Move, forColor: Color) void {
    const captureSquare = Square.fromRankAndFile(forColor.enPassantCaptureRank(), move.to.file());
    board.pieces[move.from.int()] = Piece.Null;
    board.pieces[captureSquare.int()] = Piece.Null;
    board.pieces[move.to.int()] = Piece.Pawn;
}

fn shiftMailboxEnPassantUnmake(board: *Board, move: Move, forColor: Color) void {
    const captureSquare = Square.fromRankAndFile(forColor.enPassantCaptureRank(), move.to.file());
    board.pieces[move.to.int()] = Piece.Null;
    board.pieces[captureSquare.int()] = Piece.Pawn;
    board.pieces[move.from.int()] = Piece.Pawn;
}

fn shiftMailboxNormalOrPromotionMake(board: *Board, move: Move, movedPiece: Piece, capturedPiece: Piece) void {
    _ = capturedPiece;
    board.pieces[move.from.int()] = Piece.Null;
    if (move.flag == MoveFlag.Promotion) {
        board.pieces[move.to.int()] = move.promotion.piece();
    } else {
        board.pieces[move.to.int()] = movedPiece;
    }
}

fn shiftMailboxNormalOrPromotionUnmake(board: *Board, move: Move, movedPiece: Piece, capturedPiece: Piece) void {
    if (move.flag == MoveFlag.Promotion) {
        board.pieces[move.to.int()] = capturedPiece;
        board.pieces[move.from.int()] = Piece.Pawn;
    } else {
        board.pieces[move.to.int()] = capturedPiece;
        board.pieces[move.from.int()] = movedPiece;
    }
}

fn applyCastlingXor(board: *Board, move: Move, forColor: Color) void {
    assert(move.flag == MoveFlag.Castling);
    const kingMoveMask = move.from.mask() | move.to.mask();
    const rookMoveMask = castlingRookMoveMask(move.castlingFlank(), forColor);
    board.xorPieceMask(Piece.King, kingMoveMask);
    board.xorPieceMask(Piece.Rook, rookMoveMask);
    board.xorColorMask(forColor, kingMoveMask | rookMoveMask);
    board.xorOccupiedMask(kingMoveMask | rookMoveMask);
}

fn applyEnPassantXor(board: *Board, move: Move, forColor: Color) void {
    assert(move.flag == MoveFlag.EnPassant);
    const captureSquare = Square.fromRankAndFile(forColor.enPassantCaptureRank(), move.to.file());
    const captureMask = captureSquare.mask();
    board.xorPieceMask(Piece.Pawn, move.from.mask() | move.to.mask() | captureMask);
    board.xorColorMask(forColor, move.from.mask() | move.to.mask());
    board.xorColorMask(forColor.other(), captureMask);
    board.xorOccupiedMask(move.from.mask() | move.to.mask() | captureMask);
}

fn applyNormalOrPromotionXor(board: *Board, move: Move, forColor: Color, movedPiece: Piece, capturedPiece: Piece) void {
    assert(move.flag == MoveFlag.Normal or move.flag == MoveFlag.Promotion);

    board.xorColorMask(forColor, move.from.mask() | move.to.mask());

    // Greedily occupy/unoccupy source and destination
    // If move is a capture, we will need to xor the destination again
    board.xorOccupiedMask(move.from.mask() | move.to.mask());

    if (capturedPiece != Piece.Null) {
        board.xorPieceMask(capturedPiece, move.to.mask());
        board.xorColorMask(forColor.other(), move.to.mask());

        // Undo greedy xor
        board.xorOccupiedMask(move.to.mask());
    }

    if (move.flag == MoveFlag.Promotion) {
        board.xorPieceMask(Piece.Pawn, move.from.mask());
        board.xorPieceMask(move.promotion.piece(), move.to.mask());
    } else {
        board.xorPieceMask(movedPiece, move.from.mask() | move.to.mask());
    }
}

/// Returns the bitboard of squares the rook moves through when castling on the given flank and color.
fn castlingRookMoveMask(flank: Flank, color: Color) Bitboard {
    return flank.castlingRookFilesMask() & color.backRank().mask();
}

fn castlingRookFromSquare(flank: Flank, color: Color) Square {
    const rank = color.backRank();
    return switch (flank) {
        .Kingside => Square.fromRankAndFile(rank, File.H),
        .Queenside => Square.fromRankAndFile(rank, File.A),
    };
}

fn castlingRookToSquare(flank: Flank, color: Color) Square {
    const rank = color.backRank();
    return switch (flank) {
        .Kingside => Square.fromRankAndFile(rank, File.F),
        .Queenside => Square.fromRankAndFile(rank, File.D),
    };
}

const testing = @import("std").testing;
const std = @import("std");

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
    board.validate();

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
    board.rebuildPieceMailboxFromMasks();

    try testing.expect(board.pieceMask(Piece.Pawn) & e4.mask() != 0);
    try testing.expect(board.colorMask(Color.White) & e4.mask() != 0);
    try testing.expect(board.occupiedMask() & e4.mask() != 0);
    try testing.expectEqual(e4.mask(), board.mask(Piece.Pawn, Color.White));

    board.xorPieceMask(Piece.Pawn, e4.mask());
    board.xorColorMask(Color.White, e4.mask());
    board.xorOccupiedMask(e4.mask());
    board.rebuildPieceMailboxFromMasks();

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
    testBoard.rebuildPieceMailboxFromMasks();

    try testing.expect(testBoard.isSquareAttacked(Square.D3, Color.White));
    try testing.expect(testBoard.isSquareAttacked(Square.F3, Color.White));
    try testing.expect(!testBoard.isSquareAttacked(Square.E3, Color.White));
}

test "board pieceAtSquare and colorAtSquare" {
    const board = Board.initial();
    try testing.expectEqual(Piece.King, board.pieceAtSquare(Square.E1));
    try testing.expectEqual(Color.White, board.colorAtSquare(Square.E1) orelse unreachable);
    try testing.expectEqual(Piece.Pawn, board.pieceAtSquare(Square.E2));
    try testing.expectEqual(Color.White, board.colorAtSquare(Square.E2) orelse unreachable);
    try testing.expectEqual(Piece.King, board.pieceAtSquare(Square.E8));
    try testing.expectEqual(Color.Black, board.colorAtSquare(Square.E8) orelse unreachable);
    try testing.expectEqual(Piece.Null, board.pieceAtSquare(Square.E4));
    try testing.expectEqual(@as(?Color, null), board.colorAtSquare(Square.E4));

    const blankBoard = Board.blank();
    try testing.expectEqual(Piece.Null, blankBoard.pieceAtSquare(Square.E4));
    try testing.expectEqual(@as(?Color, null), blankBoard.colorAtSquare(Square.E4));
}

test "board isOccupiedAtSquare" {
    const board = Board.initial();
    try testing.expect(!board.isOccupiedAtSquare(Square.E4));
    try testing.expect(board.isOccupiedAtSquare(Square.E2));

    const blankBoard = Board.blank();
    try testing.expect(!blankBoard.isOccupiedAtSquare(Square.E4));
}

test "board validate does not panic" {
    Board.initial().validate();

    var board = Board.blank();
    // White king
    board.xorPieceMask(Piece.King, Square.E1.mask());
    board.xorColorMask(Color.White, Square.E1.mask());
    board.xorOccupiedMask(Square.E1.mask());
    // Black king (required by hasOneKingPerColor)
    board.xorPieceMask(Piece.King, Square.E8.mask());
    board.xorColorMask(Color.Black, Square.E8.mask());
    board.xorOccupiedMask(Square.E8.mask());
    board.rebuildPieceMailboxFromMasks();
    board.validate();
}

test "board hasOneKingPerColor and hasNoPawnsInFirstNorLastRank" {
    const board = Board.initial();
    try testing.expect(board.hasOneKingPerColor());
    try testing.expect(board.hasNoPawnsInFirstNorLastRank());
}

test "board make and unmake castling" {
    var board = Board.blank();
    board.xorPieceMask(Piece.King, Square.E1.mask() | Square.E8.mask());
    board.xorPieceMask(Piece.Rook, Square.A1.mask() | Square.H1.mask());
    board.xorColorMask(Color.White, Square.E1.mask() | Square.A1.mask() | Square.H1.mask());
    board.xorColorMask(Color.Black, Square.E8.mask());
    board.rebuildPieceMailboxFromMasks();

    const boardCopy = board;

    const move = Move.castling(Flank.Kingside, Color.White);
    board.makeCastlingMove(move, Color.White);
    board.unmakeCastlingMove(move, Color.White);

    try testing.expectEqual(boardCopy, board);
}

test "board make and unmake en passant" {
    var board = Board.blank();
    // White pawn on e5, black pawn on d5. White captures en passant e5xd6.
    board.xorPieceMask(Piece.Pawn, Square.E5.mask() | Square.D5.mask());
    board.xorColorMask(Color.White, Square.E5.mask());
    board.xorColorMask(Color.Black, Square.D5.mask());
    board.xorOccupiedMask(Square.E5.mask() | Square.D5.mask());
    // Kings required by hasOneKingPerColor
    board.xorPieceMask(Piece.King, Square.A1.mask() | Square.A8.mask());
    board.xorColorMask(Color.White, Square.A1.mask());
    board.xorColorMask(Color.Black, Square.A8.mask());
    board.xorOccupiedMask(Square.A1.mask() | Square.A8.mask());
    board.rebuildPieceMailboxFromMasks();

    const originalOccupied = board.occupiedMask();
    const originalPawnMask = board.pieceMask(Piece.Pawn);

    const move = Move.newNonPromotion(Square.E5, Square.D6, MoveFlag.EnPassant);
    board.makeEnPassantMove(move, Color.White);
    board.unmakeEnPassantMove(move, Color.White);

    try testing.expectEqual(originalOccupied, board.occupiedMask());
    try testing.expectEqual(originalPawnMask, board.pieceMask(Piece.Pawn));
    board.validate();
}

test "board make and unmake normal or promotion" {
    // Normal move: e2 to e4
    var board = Board.initial();
    const originalOccupied = board.occupiedMask();
    const move = Move.newNonPromotion(Square.E2, Square.E4, MoveFlag.Normal);
    board.makeNormalOrPromotionMove(move, Color.White, Piece.Pawn, Piece.Null);
    board.unmakeNormalOrPromotionMove(move, Color.White, Piece.Pawn, Piece.Null);
    try testing.expectEqual(originalOccupied, board.occupiedMask());
    board.validate();

    // Capture: white rook on e1 takes black pawn on e7 (simplified: build minimal board)
    var captureBoard = Board.blank();
    captureBoard.xorPieceMask(Piece.Rook, Square.E1.mask());
    captureBoard.xorPieceMask(Piece.Pawn, Square.E7.mask());
    captureBoard.xorPieceMask(Piece.King, Square.A1.mask() | Square.A8.mask());
    captureBoard.xorColorMask(Color.White, Square.E1.mask() | Square.A1.mask());
    captureBoard.xorColorMask(Color.Black, Square.E7.mask() | Square.A8.mask());
    captureBoard.xorOccupiedMask(Square.E1.mask() | Square.E7.mask() | Square.A1.mask() | Square.A8.mask());
    captureBoard.rebuildPieceMailboxFromMasks();
    const captureOriginalOccupied = captureBoard.occupiedMask();
    const captureMove = Move.newNonPromotion(Square.E1, Square.E7, MoveFlag.Normal);
    captureBoard.makeNormalOrPromotionMove(captureMove, Color.White, Piece.Rook, Piece.Pawn);
    captureBoard.unmakeNormalOrPromotionMove(captureMove, Color.White, Piece.Rook, Piece.Pawn);
    try testing.expectEqual(captureOriginalOccupied, captureBoard.occupiedMask());
    captureBoard.validate();

    // Promotion: e7 to e8
    var promoBoard = Board.blank();
    promoBoard.xorPieceMask(Piece.Pawn, Square.E7.mask());
    promoBoard.xorPieceMask(Piece.King, Square.A1.mask() | Square.A8.mask());
    promoBoard.xorColorMask(Color.White, Square.E7.mask() | Square.A1.mask());
    promoBoard.xorColorMask(Color.Black, Square.A8.mask());
    promoBoard.xorOccupiedMask(Square.E7.mask() | Square.A1.mask() | Square.A8.mask());
    promoBoard.rebuildPieceMailboxFromMasks();
    const promoOriginalOccupied = promoBoard.occupiedMask();
    const promoMove = Move.newPromotion(Square.E7, Square.E8, PromotionPiece.Queen);
    promoBoard.makeNormalOrPromotionMove(promoMove, Color.White, Piece.Pawn, Piece.Null);
    promoBoard.unmakeNormalOrPromotionMove(promoMove, Color.White, Piece.Pawn, Piece.Null);
    try testing.expectEqual(promoOriginalOccupied, promoBoard.occupiedMask());
    promoBoard.validate();
}

test "board isMaskAttacked" {
    const board = Board.initial();
    try testing.expect(!board.isMaskAttacked(Square.E4.mask(), Color.White));
    try testing.expect(!board.isMaskAttacked(Square.E4.mask(), Color.Black));

    var testBoard = Board.blank();
    testBoard.xorPieceMask(Piece.Bishop, Square.C4.mask());
    testBoard.xorColorMask(Color.White, Square.C4.mask());
    testBoard.xorOccupiedMask(Square.C4.mask());
    testBoard.rebuildPieceMailboxFromMasks();
    try testing.expect(testBoard.isMaskAttacked(Square.D5.mask(), Color.White));
    try testing.expect(testBoard.isMaskAttacked(Square.D5.mask() | Square.E4.mask(), Color.White));
}

test "board render" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    {
        var file = tmp.dir.createFile("board.txt", .{}) catch @panic("createFile failed");
        var buf: [4096]u8 = undefined;
        var writer = file.writer(&buf);
        try Board.initial().render(.{}, &writer.interface);
        try writer.end();
        file.close();
    }

    var file = tmp.dir.openFile("board.txt", .{}) catch @panic("openFile failed");
    defer file.close();
    const output = try file.readToEndAlloc(testing.allocator, 4096);
    defer testing.allocator.free(output);

    try testing.expect(mem.indexOf(u8, output, "8") != null);
    try testing.expect(mem.indexOf(u8, output, "a") != null);
    try testing.expect(mem.indexOf(u8, output, "h") != null);
    try testing.expect(mem.indexOf(u8, output, "┌") != null);
}
