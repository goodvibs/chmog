//! Piece attack generation: magic bitboards for sliding pieces, precomputed for knights/kings.

const Bitboard = @import("../mod.zig").Bitboard;
const Square = @import("../mod.zig").Square;
const Piece = @import("../mod.zig").Piece;

/// When true, use magic bitboards for bishop/rook; otherwise use manual ray casting.
pub const USE_MAGIC_BITBOARDS = true;

pub const manual = @import("./manual.zig");
pub const precomputed = @import("./precomputed.zig");
pub const magic = @import("./magic.zig");

pub const pawnsPushes = manual.pawnsPushes;
pub const pawnsAttacks = manual.pawnsAttacks;
pub const pawnsAttacksLeft = manual.pawnsAttacksLeft;
pub const pawnsAttacksRight = manual.pawnsAttacksRight;
pub const knightsAttacks = manual.knightsAttacks;
pub const kingsAttacks = manual.kingsAttacks;

pub const knightAttacks = precomputed.knightAttacks;
pub const slidingBishopAttacks: fn (Square, Bitboard) Bitboard = if (USE_MAGIC_BITBOARDS) magic.slidingBishopAttacks else manual.slidingBishopAttacks;
pub const slidingRookAttacks: fn (Square, Bitboard) Bitboard = if (USE_MAGIC_BITBOARDS) magic.slidingRookAttacks else manual.slidingRookAttacks;
pub const kingAttacks = precomputed.kingAttacks;

/// Returns the union of bishop and rook attacks from the given square.
pub fn slidingQueenAttacks(from: Square, occupied: Bitboard) Bitboard {
    return slidingBishopAttacks(from, occupied) | slidingRookAttacks(from, occupied);
}

/// Returns the attack bitboard for a non-pawn piece. Sliding pieces require occupied mask; knights and kings ignore it.
pub fn nonPawnPieceAttacks(by: Piece, from: Square, occupied: ?Bitboard) Bitboard {
    return switch (by) {
        Piece.Knight => knightAttacks(from),
        Piece.Bishop => slidingBishopAttacks(from, occupied orelse unreachable),
        Piece.Rook => slidingRookAttacks(from, occupied orelse unreachable),
        Piece.Queen => slidingQueenAttacks(from, occupied orelse unreachable),
        Piece.King => kingAttacks(from),
        else => unreachable,
    };
}

const testing = @import("std").testing;

test "slidingQueenAttacks" {
    const empty = @as(Bitboard, 0);
    const attacks = slidingQueenAttacks(Square.E4, empty);

    try testing.expect(attacks & Square.E5.mask() != 0);
    try testing.expect(attacks & Square.E3.mask() != 0);
    try testing.expect(attacks & Square.D4.mask() != 0);
    try testing.expect(attacks & Square.F4.mask() != 0);
    try testing.expect(attacks & Square.D5.mask() != 0);
    try testing.expect(attacks & Square.F5.mask() != 0);
    try testing.expect(attacks & Square.D3.mask() != 0);
    try testing.expect(attacks & Square.F3.mask() != 0);
}

test "nonPawnPieceAttacks" {
    const empty = @as(Bitboard, 0);

    const knightAtks = nonPawnPieceAttacks(Piece.Knight, Square.E4, null);
    try testing.expectEqual(@as(u32, 8), @popCount(knightAtks));
    try testing.expect(knightAtks & Square.D6.mask() != 0);
    try testing.expect(knightAtks & Square.F6.mask() != 0);

    const bishopAttacks = nonPawnPieceAttacks(Piece.Bishop, Square.E4, empty);
    try testing.expect(bishopAttacks & Square.D5.mask() != 0);
    try testing.expect(bishopAttacks & Square.E5.mask() == 0);

    const rookAttacks = nonPawnPieceAttacks(Piece.Rook, Square.E4, empty);
    try testing.expect(rookAttacks & Square.E5.mask() != 0);
    try testing.expect(rookAttacks & Square.D5.mask() == 0);

    const queenAttacks = nonPawnPieceAttacks(Piece.Queen, Square.E4, empty);
    try testing.expect(queenAttacks & Square.E5.mask() != 0);
    try testing.expect(queenAttacks & Square.D5.mask() != 0);

    const kingAtks = nonPawnPieceAttacks(Piece.King, Square.E4, null);
    try testing.expectEqual(@as(u32, 8), @popCount(kingAtks));
    try testing.expect(kingAtks & Square.D5.mask() != 0);
}
