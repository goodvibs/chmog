const masks = @import("../mod.zig").masks;
const Bitboard = @import("../mod.zig").Bitboard;
const Color = @import("../mod.zig").Color;
const Square = @import("../mod.zig").Square;

const FILE_A = masks.fileA;
const FILE_B = masks.fileB;
const FILE_C = masks.fileC;
const FILE_D = masks.fileD;
const FILE_E = masks.fileE;
const FILE_F = masks.fileF;
const FILE_G = masks.fileG;
const FILE_H = masks.fileH;

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
    const twoUpOneLeft = (knights << 17) & comptime ~FILE_H;
    const twoUpOneRight = (knights << 15) & comptime ~FILE_A;
    const twoLeftOneUp = (knights << 10) & comptime ~(FILE_G | FILE_H);
    const twoRightOneUp = (knights << 6) & comptime ~(FILE_A | FILE_B);

    const twoDownOneLeft = (knights >> 15) & comptime ~FILE_H;
    const twoDownOneRight = (knights >> 17) & comptime ~FILE_A;
    const twoLeftOneDown = (knights >> 6) & comptime ~(FILE_G | FILE_H);
    const twoRightOneDown = (knights >> 10) & comptime ~(FILE_A | FILE_B);

    return twoUpOneLeft | twoUpOneRight | twoLeftOneUp | twoRightOneUp | twoDownOneLeft | twoDownOneRight | twoLeftOneDown | twoRightOneDown;
}

pub fn multiKingAttacks(kings: Bitboard) Bitboard {
    const upLeft = (kings << 9) & !FILE_H;
    const up = kings << 8;
    const upRight = (kings << 7) & !FILE_A;
    const left = (kings << 1) & !FILE_H;
    const right = (kings >> 1) & !FILE_A;
    const downLeft = (kings >> 7) & !FILE_H;
    const down = kings >> 8;
    const downRight = (kings >> 9) & !FILE_A;
    return upLeft | up | upRight | left | right | downLeft | down | downRight;
}

pub fn singleBishopAttacks(from: Square, occupied: Bitboard) Bitboard {
    var attacks: Bitboard = 0;
    for (0..@min(from.distanceFromLeft(), from.distanceFromTop())) |i| {
        const mask = from.mask() << (9 * i);
        attacks |= mask;
        if (occupied & mask != 0) break;
    }
    for (0..@min(from.distanceFromTop(), from.distanceFromRight())) |i| {
        const mask = from.mask() << (7 * i);
        attacks |= mask;
        if (occupied & mask != 0) break;
    }
    for (0..@min(from.distanceFromRight(), from.distanceFromBottom())) |i| {
        const mask = from.mask() >> (9 * i);
        attacks |= mask;
        if (occupied & mask != 0) break;
    }
    for (0..@min(from.distanceFromBottom(), from.distanceFromLeft())) |i| {
        const mask = from.mask() >> (7 * i);
        attacks |= mask;
        if (occupied & mask != 0) break;
    }
    return attacks;
}

pub fn singleRookAttacks(from: Square, occupied: Bitboard) Bitboard {
    var attacks: Bitboard = 0;
    for (0..from.distanceFromLeft()) |i| {
        const mask = from.mask() << i;
        attacks |= mask;
        if (occupied & mask != 0) break;
    }
    for (0..from.distanceFromTop()) |i| {
        const mask = from.mask() << (8 * i);
        attacks |= mask;
        if (occupied & mask != 0) break;
    }
    for (0..from.distanceFromRight()) |i| {
        const mask = from.mask() >> i;
        attacks |= mask;
        if (occupied & mask != 0) break;
    }
    for (0..from.distanceFromBottom()) |i| {
        const mask = from.mask() >> (8 * i);
        attacks |= mask;
        if (occupied & mask != 0) break;
    }
    return attacks;
}
