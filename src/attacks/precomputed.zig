const Bitboard = @import("../mod.zig").Bitboard;
const Square = @import("../mod.zig").Square;
const SquaresMappingLookup = @import("../mod.zig").utils.SquaresMappingLookup;
const multiKnightAttacks = @import("mod.zig").manual.multiKnightAttacks;
const multiKingAttacks = @import("mod.zig").manual.multiKingAttacks;

const SquareMaskLookup = SquaresMappingLookup(1, Bitboard);

fn singlePieceAttacksFromMulti(comptime multiPieceAttacks: fn (Bitboard) Bitboard) fn (Square) Bitboard {
    return struct {
        fn singlePieceAttacks(from: Square) Bitboard {
            return multiPieceAttacks(from);
        }
    }.singlePieceAttacks;
}

const SINGLE_KNIGHT_ATTACKS_LOOKUP = SquareMaskLookup.init(singlePieceAttacksFromMulti(multiKnightAttacks));
const SINGLE_KING_ATTACKS_LOOKUP = SquareMaskLookup.init(singlePieceAttacksFromMulti(multiKingAttacks));

pub fn singleKnightAttacks(from: Square) Bitboard {
    return SINGLE_KNIGHT_ATTACKS_LOOKUP.get(from);
}

pub fn singleKingAttacks(from: Square) Bitboard {
    return SINGLE_KING_ATTACKS_LOOKUP.get(from);
}
