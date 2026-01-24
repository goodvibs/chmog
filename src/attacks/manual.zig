const masks = @import("../mod.zig").masks;
const Bitboard = @import("../mod.zig").Bitboard;
const Color = @import("../mod.zig").Color;
const Square = @import("../mod.zig").Square;

pub fn pawnsPushes(pawns: Bitboard, by: Color) Bitboard {
    return switch (by) {
        .White => pawns << 8,
        .Black => pawns >> 8,
    };
}

pub fn pawnsAttacksLeft(pawns: Bitboard, by: Color) Bitboard {
    return switch (by) {
        .White => (pawns << 9) & ~masks.FILE_H,
        .Black => (pawns >> 9) & ~masks.FILE_A,
    };
}

pub fn pawnsAttacksRight(pawns: Bitboard, by: Color) Bitboard {
    return switch (by) {
        .White => (pawns << 7) & ~masks.FILE_A,
        .Black => (pawns >> 7) & ~masks.FILE_H,
    };
}

pub fn pawnsAttacks(pawns: Bitboard, by: Color) Bitboard {
    return switch (by) {
        .White => ((pawns << 7) & ~masks.FILE_A) | ((pawns << 9) & ~masks.FILE_H),
        .Black => ((pawns >> 7) & ~masks.FILE_H) | ((pawns >> 9) & ~masks.FILE_A),
    };
}

pub fn knightsAttacks(knights: Bitboard) Bitboard {
    const twoUpOneLeft = (knights << 17) & ~masks.FILE_H;
    const twoUpOneRight = (knights << 15) & ~masks.FILE_A;
    const twoLeftOneUp = (knights << 10) & ~(masks.FILE_G | masks.FILE_H);
    const twoRightOneUp = (knights << 6) & ~(masks.FILE_A | masks.FILE_B);

    const twoDownOneLeft = (knights >> 15) & ~masks.FILE_H;
    const twoDownOneRight = (knights >> 17) & ~masks.FILE_A;
    const twoLeftOneDown = (knights >> 6) & ~(masks.FILE_G | masks.FILE_H);
    const twoRightOneDown = (knights >> 10) & ~(masks.FILE_A | masks.FILE_B);

    return twoUpOneLeft | twoUpOneRight | twoLeftOneUp | twoRightOneUp | twoDownOneLeft | twoDownOneRight | twoLeftOneDown | twoRightOneDown;
}

pub fn kingsAttacks(kings: Bitboard) Bitboard {
    const upLeft = (kings << 9) & ~masks.FILE_H;
    const up = kings << 8;
    const upRight = (kings << 7) & ~masks.FILE_A;
    const left = (kings << 1) & ~masks.FILE_H;
    const right = (kings >> 1) & ~masks.FILE_A;
    const downLeft = (kings >> 7) & ~masks.FILE_H;
    const down = kings >> 8;
    const downRight = (kings >> 9) & ~masks.FILE_A;
    return upLeft | up | upRight | left | right | downLeft | down | downRight;
}

pub fn slidingBishopAttacks(from: Square, occupied: Bitboard) Bitboard {
    const occupied_ = occupied & ~from.mask();
    var attacks: Bitboard = 0;
    for (0..@min(from.distanceFromLeft(), from.distanceFromTop()) + @as(usize, 1)) |i| {
        const mask = from.mask() << @intCast(9 * i);
        attacks |= mask;
        if (occupied_ & mask != 0) break;
    }
    for (0..@min(from.distanceFromTop(), from.distanceFromRight()) + @as(usize, 1)) |i| {
        const mask = from.mask() << @intCast(7 * i);
        attacks |= mask;
        if (occupied_ & mask != 0) break;
    }
    for (0..@min(from.distanceFromRight(), from.distanceFromBottom()) + @as(usize, 1)) |i| {
        const mask = from.mask() >> @intCast(9 * i);
        attacks |= mask;
        if (occupied_ & mask != 0) break;
    }
    for (0..@min(from.distanceFromBottom(), from.distanceFromLeft()) + @as(usize, 1)) |i| {
        const mask = from.mask() >> @intCast(7 * i);
        attacks |= mask;
        if (occupied_ & mask != 0) break;
    }
    return attacks;
}

pub fn slidingRookAttacks(from: Square, occupied: Bitboard) Bitboard {
    const occupied_ = occupied & ~from.mask();
    var attacks: Bitboard = 0;
    for (0..from.distanceFromLeft() + @as(usize, 1)) |i| {
        const mask = from.mask() << @intCast(i);
        attacks |= mask;
        if (occupied_ & mask != 0) break;
    }
    for (0..from.distanceFromTop() + @as(usize, 1)) |i| {
        const mask = from.mask() << @intCast(8 * i);
        attacks |= mask;
        if (occupied_ & mask != 0) break;
    }
    for (0..from.distanceFromRight() + @as(usize, 1)) |i| {
        const mask = from.mask() >> @intCast(i);
        attacks |= mask;
        if (occupied_ & mask != 0) break;
    }
    for (0..from.distanceFromBottom() + @as(usize, 1)) |i| {
        const mask = from.mask() >> @intCast(8 * i);
        attacks |= mask;
        if (occupied_ & mask != 0) break;
    }
    return attacks;
}

const testing = @import("std").testing;

test "pawnsPushes" {
    const whitePawns = Square.E2.mask();
    const whitePushes = pawnsPushes(whitePawns, Color.White);
    try testing.expectEqual(Square.E3.mask(), whitePushes);

    const blackPawns = Square.E7.mask();
    const blackPushes = pawnsPushes(blackPawns, Color.Black);
    try testing.expectEqual(Square.E6.mask(), blackPushes);

    const multipleWhite = Square.E2.mask() | Square.D2.mask();
    const multiplePushes = pawnsPushes(multipleWhite, Color.White);
    try testing.expectEqual(Square.E3.mask() | Square.D3.mask(), multiplePushes);
}

test "pawnsAttacks" {
    const whitePawn = Square.E2.mask();
    const whiteAttacks = pawnsAttacks(whitePawn, Color.White);
    try testing.expect(whiteAttacks & Square.D3.mask() != 0);
    try testing.expect(whiteAttacks & Square.F3.mask() != 0);
    try testing.expect(whiteAttacks & Square.E3.mask() == 0);

    const blackPawn = Square.E7.mask();
    const blackAttacks = pawnsAttacks(blackPawn, Color.Black);
    try testing.expect(blackAttacks & Square.D6.mask() != 0);
    try testing.expect(blackAttacks & Square.F6.mask() != 0);
    try testing.expect(blackAttacks & Square.E6.mask() == 0);

    const whitePawnA = Square.A2.mask();
    const whiteAttacksA = pawnsAttacks(whitePawnA, Color.White);
    try testing.expect(whiteAttacksA & Square.B3.mask() != 0);
    try testing.expect(whiteAttacksA & Square.A3.mask() == 0);

    const whitePawnH = Square.H2.mask();
    const whiteAttacksH = pawnsAttacks(whitePawnH, Color.White);
    try testing.expect(whiteAttacksH & Square.G3.mask() != 0);
    try testing.expect(whiteAttacksH & Square.H3.mask() == 0);
}

test "knightsAttacks" {
    const knight = Square.E4.mask();
    const attacks = knightsAttacks(knight);

    // E4 knight should attack 8 squares
    try testing.expectEqual(@as(u32, 8), @popCount(attacks));

    // Check specific squares
    try testing.expect(attacks & Square.D6.mask() != 0);
    try testing.expect(attacks & Square.F6.mask() != 0);
    try testing.expect(attacks & Square.C5.mask() != 0);
    try testing.expect(attacks & Square.G5.mask() != 0);
    try testing.expect(attacks & Square.C3.mask() != 0);
    try testing.expect(attacks & Square.G3.mask() != 0);
    try testing.expect(attacks & Square.D2.mask() != 0);
    try testing.expect(attacks & Square.F2.mask() != 0);

    // Should not attack itself
    try testing.expect(attacks & Square.E4.mask() == 0);
}

test "kingsAttacks" {
    const king = Square.E4.mask();
    const attacks = kingsAttacks(king);

    // E4 king should attack 8 squares
    try testing.expectEqual(@as(u32, 8), @popCount(attacks));

    // Check all 8 directions
    try testing.expect(attacks & Square.D5.mask() != 0);
    try testing.expect(attacks & Square.E5.mask() != 0);
    try testing.expect(attacks & Square.F5.mask() != 0);
    try testing.expect(attacks & Square.D4.mask() != 0);
    try testing.expect(attacks & Square.F4.mask() != 0);
    try testing.expect(attacks & Square.D3.mask() != 0);
    try testing.expect(attacks & Square.E3.mask() != 0);
    try testing.expect(attacks & Square.F3.mask() != 0);

    // Edge case - king on corner
    const cornerKing = Square.A1.mask();
    const cornerAttacks = kingsAttacks(cornerKing);
    try testing.expectEqual(@as(u32, 3), @popCount(cornerAttacks));
    try testing.expect(cornerAttacks & Square.B1.mask() != 0);
    try testing.expect(cornerAttacks & Square.A2.mask() != 0);
    try testing.expect(cornerAttacks & Square.B2.mask() != 0);
}

test "slidingBishopAttacks" {
    const bishop = Square.E4;
    const empty = @as(Bitboard, 0);
    const attacks = slidingBishopAttacks(bishop, empty);

    // Should attack diagonally in 4 directions
    try testing.expect(attacks & Square.D5.mask() != 0);
    try testing.expect(attacks & Square.F5.mask() != 0);
    try testing.expect(attacks & Square.D3.mask() != 0);
    try testing.expect(attacks & Square.F3.mask() != 0);
    try testing.expect(attacks & Square.B1.mask() != 0);
    try testing.expect(attacks & Square.H1.mask() != 0);
    try testing.expect(attacks & Square.A8.mask() != 0);

    // Should not attack orthogonally
    try testing.expect(attacks & Square.E5.mask() == 0);
    try testing.expect(attacks & Square.D4.mask() == 0);

    // With blocker
    const blocker = Square.D5.mask();
    const attacksWithBlocker = slidingBishopAttacks(bishop, blocker);
    try testing.expect(attacksWithBlocker & Square.D5.mask() != 0); // Includes blocker
    try testing.expect(attacksWithBlocker & Square.C6.mask() == 0); // Blocked beyond
    try testing.expect(attacksWithBlocker & Square.F5.mask() != 0); // Other direction still works
}

test "slidingRookAttacks" {
    const rook = Square.E4;
    const empty = @as(Bitboard, 0);
    const attacks = slidingRookAttacks(rook, empty);

    // Should attack orthogonally in 4 directions
    try testing.expect(attacks & Square.E5.mask() != 0);
    try testing.expect(attacks & Square.E3.mask() != 0);
    try testing.expect(attacks & Square.D4.mask() != 0);
    try testing.expect(attacks & Square.F4.mask() != 0);
    try testing.expect(attacks & Square.E8.mask() != 0);
    try testing.expect(attacks & Square.A4.mask() != 0);

    // Should not attack diagonally
    try testing.expect(attacks & Square.D5.mask() == 0);
    try testing.expect(attacks & Square.F5.mask() == 0);

    // With blocker
    const blocker = Square.E5.mask();
    const attacksWithBlocker = slidingRookAttacks(rook, blocker);
    try testing.expect(attacksWithBlocker & Square.E5.mask() != 0); // Includes blocker
    try testing.expect(attacksWithBlocker & Square.E6.mask() == 0); // Blocked beyond
    try testing.expect(attacksWithBlocker & Square.E3.mask() != 0); // Other direction still works
}
