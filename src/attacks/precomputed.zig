const Bitboard = @import("../mod.zig").Bitboard;
const Square = @import("../mod.zig").Square;
const SquareToBitboard = @import("../mod.zig").utils.SquareToBitboard;
const knightsAttacks = @import("./mod.zig").manual.knightsAttacks;
const kingsAttacks = @import("./mod.zig").manual.kingsAttacks;

fn singlePieceAttacksFromMulti(comptime multiPieceAttacks: fn (Bitboard) Bitboard) fn ([1]Square) Bitboard {
    return struct {
        fn singlePieceAttacks(from: [1]Square) Bitboard {
            return multiPieceAttacks(from[0].mask());
        }
    }.singlePieceAttacks;
}

const SINGLE_KNIGHT_ATTACKS_LOOKUP = SquareToBitboard.init(singlePieceAttacksFromMulti(knightsAttacks));
const SINGLE_KING_ATTACKS_LOOKUP = SquareToBitboard.init(singlePieceAttacksFromMulti(kingsAttacks));

pub fn knightAttacks(from: Square) Bitboard {
    return SINGLE_KNIGHT_ATTACKS_LOOKUP.get([1]Square{from});
}

pub fn kingAttacks(from: Square) Bitboard {
    return SINGLE_KING_ATTACKS_LOOKUP.get([1]Square{from});
}

const testing = @import("std").testing;

test "knightAttacks" {
    for (0..64) |i| {
        const square = Square.fromInt(@as(u6, @intCast(i)));
        const expected = knightsAttacks(square.mask());
        try testing.expectEqual(expected, knightAttacks(square));
    }
}

test "kingAttacks" {
    for (0..64) |i| {
        const square = Square.fromInt(@as(u6, @intCast(i)));
        const expected = kingsAttacks(square.mask());
        try testing.expectEqual(expected, kingAttacks(square));
    }
}
