const Bitboard = @import("../mod.zig").Bitboard;
const Square = @import("../mod.zig").Square;
const Piece = @import("../mod.zig").Piece;

pub const manual = @import("./manual.zig");
pub const precomputed = @import("./precomputed.zig");
pub const magic = @import("./magic.zig");

pub const USE_MAGIC_BITBOARDS = true;

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

pub fn slidingQueenAttacks(from: Square, occupied: Bitboard) Bitboard {
    return slidingBishopAttacks(from, occupied) | slidingRookAttacks(from, occupied);
}

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
