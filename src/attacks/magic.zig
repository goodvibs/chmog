const Bitboard = @import("../mod.zig").Bitboard;
const Square = @import("../mod.zig").Square;
const Rank = @import("../mod.zig").Rank;
const Prng = @import("../mod.zig").utils.Prng;
const SquareToBitboard = @import("../mod.zig").utils.SquareToBitboard;
const iterBitCombinations = @import("../mod.zig").utils.iterBitCombinations;
const manual = @import("../mod.zig").attacks.manual;
const masks = @import("../mod.zig").masks;
const BISHOP_MAGIC_INFO_LOOKUP = @import("generated/mod.zig").BISHOP_MAGIC_INFO_LOOKUP;
const ROOK_MAGIC_INFO_LOOKUP = @import("generated/mod.zig").ROOK_MAGIC_INFO_LOOKUP;

fn stopIfMask(comptime next: fn (Square) ?Square, comptime mask: Bitboard) fn (Square) ?Square {
    return struct {
        fn next_(current: Square) ?Square {
            if (next(current)) |nextSquare| {
                if (nextSquare.mask() & mask == 0) return nextSquare;
            }
            return null;
        }
    }.next_;
}

pub fn computeBishopRelevantMask(from_: [1]Square) Bitboard {
    const from = from_[0];
    return from.diagonalsMask() & ~(from.mask() | masks.FILE_A | masks.FILE_H | masks.RANK_1 | masks.RANK_8);
}

pub fn computeRookRelevantMask(from_: [1]Square) Bitboard {
    const from = from_[0];
    const up = from.buildMask(0, stopIfMask(Square.up, masks.RANK_8));
    const down = from.buildMask(0, stopIfMask(Square.down, masks.RANK_1));
    const left = from.buildMask(0, stopIfMask(Square.left, masks.FILE_A));
    const right = from.buildMask(0, stopIfMask(Square.right, masks.FILE_H));
    return up | down | left | right;
}

const BISHOP_RELEVANT_MASK_LOOKUP = SquareToBitboard.init(computeBishopRelevantMask);
const ROOK_RELEVANT_MASK_LOOKUP = SquareToBitboard.init(computeRookRelevantMask);

fn bishopRelevantMask(from: Square) Bitboard {
    return BISHOP_RELEVANT_MASK_LOOKUP.get([1]Square{from});
}

fn rookRelevantMask(from: Square) Bitboard {
    return ROOK_RELEVANT_MASK_LOOKUP.get([1]Square{from});
}

pub const BISHOP_ATTACK_TABLE_SIZE: usize = (4 << 6) + (44 << 5) + (12 << 7) + (4 << 9);
pub const ROOK_ATTACK_TABLE_SIZE: usize = (36 << 10) + (24 << 11) + (4 << 12);

pub const BishopMagicAttacksLookup = MagicAttacksLookup(BISHOP_ATTACK_TABLE_SIZE);
pub const RookMagicAttacksLookup = MagicAttacksLookup(ROOK_ATTACK_TABLE_SIZE);

const BISHOP_MAGIC_ATTACKS_LOOKUP = BishopMagicAttacksLookup.initWithPrecomputed(manual.singleBishopAttacks, BISHOP_MAGIC_INFO_LOOKUP);
// const ROOK_MAGIC_ATTACKS_LOOKUP = RookMagicAttacksLookup.init(manual.singleRookAttacks);

pub fn singleBishopAttacks(from: Square, occupied: Bitboard) Bitboard {
    return BISHOP_MAGIC_ATTACKS_LOOKUP.get(from, occupied);
}

// pub fn singleRookAttacks(from: Square, occupied: Bitboard) Bitboard {
//     return ROOK_MAGIC_ATTACKS_LOOKUP.get(from, occupied);
// }

fn MagicAttacksLookup(comptime tableSize: usize) type {
    return struct {
        const Self = @This();

        attacks: [tableSize]Bitboard,
        magicInfoLookup: [64]MagicInfo,

        pub fn init(comptime relevantMaskLookup: fn (Square) Bitboard, comptime computeAttacks: fn (Square, Bitboard) Bitboard) Self {
            const seeds = [8]Bitboard{ 728, 10316, 55013, 32803, 12281, 15100, 16645, 255 };

            var table: [tableSize]Bitboard = undefined;
            var magicInfoLookup: [64]MagicInfo = undefined;

            var blockersLookup: [4096]Bitboard = undefined;
            var magicAttemptStamps: [4096]u32 = std.mem.zeroes([4096]u32);
            var numMagicsTried: u32 = 0;
            var attacksLookup: [4096]Bitboard = undefined;
            var offset: u32 = 0;

            for (0..64) |square_idx| {
                const s = Square.fromInt(@truncate(square_idx));

                const relevantMask = relevantMaskLookup(s);
                const numRelevantBits: u4 = @truncate(@popCount(relevantMask));
                const shift: u6 = @truncate(@as(u7, 64) - numRelevantBits);
                const numUniqueBlockerMasks = @as(u13, 1) << numRelevantBits;

                var bitSubsetsIter = iterBitCombinations(relevantMask);
                for (0..numUniqueBlockerMasks) |subsetIdx| {
                    const blockers = bitSubsetsIter.next() orelse unreachable;
                    blockersLookup[subsetIdx] = blockers;
                    attacksLookup[subsetIdx] = computeAttacks(s, blockers);
                }

                var rng = Prng.init(seeds[s.rank().int()]) catch unreachable;
                var magicNumber: Bitboard = undefined;

                var blockerMaskIndex: usize = 0;
                while (blockerMaskIndex < numUniqueBlockerMasks) {
                    magicNumber = 0;
                    while (@popCount((magicNumber *% relevantMask) >> 56) < 6) {
                        magicNumber = rng.sparseRandBitboard();
                    }

                    numMagicsTried += 1;
                    blockerMaskIndex = 0;

                    while (blockerMaskIndex < numUniqueBlockerMasks) : (blockerMaskIndex += 1) {
                        const blockers = blockersLookup[blockerMaskIndex];
                        const indexWithoutOffset: u32 = @truncate((blockers *% magicNumber) >> shift);
                        const tableIndex = offset + indexWithoutOffset;

                        if (magicAttemptStamps[indexWithoutOffset] < numMagicsTried) {
                            magicAttemptStamps[indexWithoutOffset] = numMagicsTried;
                            table[tableIndex] = attacksLookup[blockerMaskIndex];
                        } else if (table[tableIndex] != attacksLookup[blockerMaskIndex]) {
                            break;
                        }
                    }
                }

                magicInfoLookup[square_idx] = MagicInfo{
                    .relevantMask = relevantMask,
                    .magicNumber = magicNumber,
                    .shift = shift,
                    .offset = offset,
                };

                offset += numUniqueBlockerMasks;
            }

            return Self{
                .attacks = table,
                .magicInfoLookup = magicInfoLookup,
            };
        }

        fn initWithPrecomputed(comptime computeAttacks: fn (Square, Bitboard) Bitboard, comptime magicInfoLookup: [64]MagicInfo) Self {
            comptime {
                var table: [tableSize]Bitboard = undefined;

                for (0..64) |square_idx| {
                    const square = Square.fromInt(@truncate(square_idx));
                    const magicInfo = magicInfoLookup[square_idx];

                    var bitSubsetsIter = iterBitCombinations(magicInfo.relevantMask);
                    while (bitSubsetsIter.next()) |blockers| {
                        table[magicInfo.key(blockers)] = computeAttacks(square, blockers);
                    }
                }

                return Self{
                    .attacks = table,
                    .magicInfoLookup = magicInfoLookup,
                };
            }
        }

        fn get(self: *const Self, square: Square, occupied: Bitboard) Bitboard {
            const magicInfo = self.magicInfoLookup[square.int()];
            return self.attacks[magicInfo.key(occupied)];
        }
    };
}

pub const MagicInfo = struct {
    relevantMask: Bitboard,
    magicNumber: Bitboard,
    shift: u6,
    offset: u32,

    pub fn key(self: MagicInfo, occupiedMask: Bitboard) usize {
        return self.keyWithoutOffset(occupiedMask) + self.offset;
    }

    pub fn keyWithoutOffset(self: MagicInfo, occupiedMask: Bitboard) usize {
        const blockers = occupiedMask & self.relevantMask;
        const unshiftedKey = blockers *% self.magicNumber;
        return @truncate(unshiftedKey >> self.shift);
    }
};

const std = @import("std");
const testing = @import("std").testing;
const renderBitboard = @import("../mod.zig").utils.renderBitboard;

fn assertCountEquals(comptime T: type, slice: []const T, value: T, expectedCount: T) !void {
    var count: T = 0;
    for (slice) |item| {
        if (item == value) count += 1;
    }
    try testing.expectEqual(expectedCount, count);
}

test "relevantMask" {
    var bishopRelevantBits: [64]u7 = undefined;
    var rookRelevantBits: [64]u7 = undefined;
    for (0..64) |i| {
        const square = Square.fromInt(@as(u6, @intCast(i)));
        const b = bishopRelevantMask(square);
        const r = rookRelevantMask(square);
        bishopRelevantBits[i] = @popCount(b);
        rookRelevantBits[i] = @popCount(r);
    }

    try assertCountEquals(u7, &bishopRelevantBits, 6, 4);
    try assertCountEquals(u7, &bishopRelevantBits, 5, 44);
    try assertCountEquals(u7, &bishopRelevantBits, 7, 12);
    try assertCountEquals(u7, &bishopRelevantBits, 9, 4);

    try assertCountEquals(u7, &rookRelevantBits, 10, 36);
    try assertCountEquals(u7, &rookRelevantBits, 11, 24);
    try assertCountEquals(u7, &rookRelevantBits, 12, 4);
}
