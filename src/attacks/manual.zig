const FILE_A = @import("../mod.zig").masks.FILE_A;
const FILE_B = @import("../mod.zig").masks.FILE_B;
const FILE_C = @import("../mod.zig").masks.FILE_C;
const FILE_D = @import("../mod.zig").masks.FILE_D;
const FILE_E = @import("../mod.zig").masks.FILE_E;
const FILE_F = @import("../mod.zig").masks.FILE_F;
const FILE_G = @import("../mod.zig").masks.FILE_G;
const FILE_H = @import("../mod.zig").masks.FILE_H;
const Bitboard = @import("../mod.zig").Bitboard;
const Color = @import("../mod.zig").Color;
const Square = @import("../mod.zig").Square;

pub fn multiPawnPushes(pawns: Bitboard, comptime color: Color) Bitboard {
    if (color == Color.White) {
        return pawns << 8;
    } else {
        return pawns >> 8;
    }
}

pub fn multiPawnAttacks(pawns: Bitboard, comptime color: Color) Bitboard {
    if (color == Color.White) {
        return ((pawns << 7) & ~FILE_A) | ((pawns << 9) & ~FILE_H);
    } else {
        return ((pawns >> 7) & ~FILE_A) | ((pawns >> 9) & ~FILE_H);
    }
}

pub fn multiKnightAttacks(knights: Bitboard) Bitboard {
    const twoUpOneLeft = (knights << 17) & ~FILE_H;
    const twoUpOneRight = (knights << 15) & ~FILE_A;
    const twoLeftOneUp = (knights << 10) & ~(FILE_G | FILE_H);
    const twoRightOneUp = (knights << 6) & ~(FILE_A | FILE_B);

    const twoDownOneLeft = (knights >> 15) & ~FILE_H;
    const twoDownOneRight = (knights >> 17) & ~FILE_A;
    const twoLeftOneDown = (knights >> 6) & ~(FILE_G | FILE_H);
    const twoRightOneDown = (knights >> 10) & ~(FILE_A | FILE_B);

    return twoUpOneLeft | twoUpOneRight | twoLeftOneUp | twoRightOneUp | twoDownOneLeft | twoDownOneRight | twoLeftOneDown | twoRightOneDown;
}

pub fn multiKingAttacks(kings: Bitboard) Bitboard {
    const upLeft = (kings << 9) & ~FILE_H;
    const up = kings << 8;
    const upRight = (kings << 7) & ~FILE_A;
    const left = (kings << 1) & ~FILE_H;
    const right = (kings >> 1) & ~FILE_A;
    const downLeft = (kings >> 7) & ~FILE_H;
    const down = kings >> 8;
    const downRight = (kings >> 9) & ~FILE_A;
    return upLeft | up | upRight | left | right | downLeft | down | downRight;
}

pub fn singleBishopAttacks(from: Square, occupied: Bitboard) Bitboard {
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

pub fn singleRookAttacks(from: Square, occupied: Bitboard) Bitboard {
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
