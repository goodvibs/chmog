const Bitboard = @import("../mod.zig").Bitboard;
const Square = @import("../mod.zig").Square;
const SquareToBitboard = @import("../mod.zig").utils.SquareToBitboard;
const multiKnightAttacks = @import("mod.zig").manual.multiKnightAttacks;
const multiKingAttacks = @import("mod.zig").manual.multiKingAttacks;

fn singlePieceAttacksFromMulti(comptime multiPieceAttacks: fn (Bitboard) Bitboard) fn ([1]Square) Bitboard {
    return struct {
        fn singlePieceAttacks(from: [1]Square) Bitboard {
            return multiPieceAttacks(from[0].mask());
        }
    }.singlePieceAttacks;
}

const SINGLE_KNIGHT_ATTACKS_LOOKUP = SquareToBitboard.init(singlePieceAttacksFromMulti(multiKnightAttacks));
const SINGLE_KING_ATTACKS_LOOKUP = SquareToBitboard.init(singlePieceAttacksFromMulti(multiKingAttacks));

pub fn singleKnightAttacks(from: Square) Bitboard {
    return SINGLE_KNIGHT_ATTACKS_LOOKUP.get([1]Square{from});
}

pub fn singleKingAttacks(from: Square) Bitboard {
    return SINGLE_KING_ATTACKS_LOOKUP.get([1]Square{from});
}

const testing = @import("std").testing;
test "alwaysFail" {
    try testing.expect(false);
}
