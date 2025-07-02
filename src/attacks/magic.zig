const Bitboard = @import("../mod.zig").Bitboard;
const Square = @import("../mod.zig").Square;
const Rank = @import("../mod.zig").Rank;
const Prng = @import("../mod.zig").utils.Prng;
const SquareToBitboard = @import("../mod.zig").utils.SquareToBitboard;
const iterBitCombinations = @import("../mod.zig").iterBitCombinations;
const manual = @import("../mod.zig").attacks.manual;
const masks = @import("../mod.zig").masks;

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

fn computeBishopRelevantMask(from: Square) Bitboard {
    return from.diagonalsMask() & ~(from.mask() | masks.FILE_A | masks.FILE_H | masks.RANK_1 | masks.RANK_8);
}

fn computeRookRelevantMask(from: Square) Bitboard {
    const up = from.buildMask(from.mask(), stopIfMask(Square.up, masks.RANK_8));
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

const BISHOP_ATTACK_TABLE_SIZE: usize = (4 << 6) + (44 << 5) + (12 << 7) + (4 << 9);
const ROOK_ATTACK_TABLE_SIZE: usize = (36 << 10) + (24 << 11) + (4 << 12);

const BISHOP_MAGIC_ATTACKS_LOOKUP = MagicAttacksLookup(BISHOP_ATTACK_TABLE_SIZE, bishopRelevantMask)
    .init(manual.singleBishopAttacks);
const ROOK_MAGIC_ATTACKS_LOOKUP = MagicAttacksLookup(ROOK_ATTACK_TABLE_SIZE, rookRelevantMask)
    .init(manual.singleRookAttacks);

pub fn singleBishopAttacks(from: Square) Bitboard {
    return BISHOP_MAGIC_ATTACKS_LOOKUP.get(from);
}

pub fn singleRookAttacks(from: Square) Bitboard {
    return ROOK_MAGIC_ATTACKS_LOOKUP.get(from);
}

fn MagicAttacksLookup(comptime size: usize, comptime relevantMaskLookup: fn (Square) Bitboard) type {
    return struct {
        const Self = @This();

        attacks: [size]Bitboard,
        magicInfoLookup: [64]MagicInfo,

        fn get(self: MagicAttacksLookup, square: Square) Bitboard {
            const magicInfo = self.magicInfoLookup[square.int()];
            return self.attacks[magicInfo.keyWithoutOffset(square.mask())];
        }

        fn init(comptime computeAttacks: fn (Square, Bitboard) Bitboard) Self {
            comptime {
                var attacksTable: [size]Bitboard = undefined;
                var magicInfoLookup: [64]MagicInfo = undefined;
                var currentOffset = 0;

                var prng = Prng.init(314592) catch unreachable;
                for (0..64) |i| {
                    const square = Square.fromInt(@as(u6, @intCast(i)));
                    const relevantMask = relevantMaskLookup(square);
                    const numRelevantSquares = @popCount(relevantMask);
                    const shift = 64 - numRelevantSquares;
                    const numOccupiedMasks = 1 << numRelevantSquares;

                    var occupiedPatternIterator = iterBitCombinations(relevantMask);
                    var tempLookupForSquare: [numOccupiedMasks][2]Bitboard = undefined;

                    for (0..numOccupiedMasks) |j| {
                        const occupiedMask = occupiedPatternIterator.next() orelse unreachable;
                        const attacks = computeAttacks(square, occupiedMask);
                        tempLookupForSquare[j] = [2]Bitboard{ occupiedMask, attacks };
                    }

                    var attacksForSquare: [numOccupiedMasks]Bitboard = undefined;
                    var magicNumberForSquare: Bitboard = undefined;

                    while (true) {
                        magicNumberForSquare = prng.sparseRand(Bitboard);
                        if (@popCount(relevantMask *% magicNumberForSquare & Rank.One.mask()) < 6) continue;
                        @memset(&attacksForSquare, 0);
                        var collision = false;

                        for (0..numOccupiedMasks) |j| {
                            const occupiedMask, const attacks = tempLookupForSquare[j];
                            const index = (occupiedMask *% magicNumberForSquare) >> shift;
                            if (attacksForSquare[index] != 0 and attacksForSquare[index] != attacks) {
                                collision = true;
                                break;
                            } else {
                                attacksForSquare[index] = attacks;
                            }
                        }

                        if (!collision) break;
                    }

                    const magicInfo = MagicInfo{
                        .relevantMask = relevantMask,
                        .magicNumber = magicNumberForSquare,
                        .shift = shift,
                        .offset = currentOffset,
                    };

                    magicInfoLookup[i] = magicInfo;
                    @memcpy(attacksTable[currentOffset .. currentOffset + numOccupiedMasks], attacksForSquare);

                    currentOffset += numOccupiedMasks;
                }

                return Self{
                    .attacks = attacksTable,
                    .magicInfoLookup = magicInfoLookup,
                };
            }
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
