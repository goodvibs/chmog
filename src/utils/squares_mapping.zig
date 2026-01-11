const std = @import("std");
const Bitboard = @import("../mod.zig").Bitboard;
const Square = @import("../mod.zig").Square;

pub const SquareToBitboard = SquaresMappingLookup(1, Bitboard);
pub const TwoSquaresToBitboard = SquaresMappingLookup(2, Bitboard);

pub fn SquaresMappingLookup(comptime numSquaresPerKey: usize, comptime OutputType: type) type {
    return struct {
        const Self = @This();

        pub const NUM_KEYS = std.math.pow(usize, 64, numSquaresPerKey);

        lookup: [NUM_KEYS]OutputType,

        pub fn init(comptime computeMapping: fn ([numSquaresPerKey]Square) OutputType) Self {
            comptime {
                // @setEvalBranchQuota(15 * NUM_KEYS);
                @setEvalBranchQuota(9999999);
                var memory: [NUM_KEYS]OutputType = undefined;
                var currentKey: [numSquaresPerKey]Square = undefined;
                fillMappings(&memory, &currentKey, 0, computeMapping);
                return Self{ .lookup = memory };
            }
        }

        pub fn get(self: Self, key: [numSquaresPerKey]Square) OutputType {
            return self.lookup[indexOfKey(key)];
        }

        fn indexOfKey(key: [numSquaresPerKey]Square) usize {
            var index: usize = 0;
            inline for (key) |square| {
                index = index * 64 + square.int();
            }
            return index;
        }

        fn fillMappings(lookupPtr: *[NUM_KEYS]OutputType, currentKeyPtr: *[numSquaresPerKey]Square, indexWithinKey: usize, comptime computeMapping: fn ([numSquaresPerKey]Square) OutputType) void {
            for (0..64) |i| {
                const square = Square.fromInt(@as(u6, @intCast(i)));
                currentKeyPtr[indexWithinKey] = square;
                if (indexWithinKey >= numSquaresPerKey - 1) {
                    const currentKey = currentKeyPtr.*;
                    const index = indexOfKey(currentKey);
                    lookupPtr[index] = computeMapping(currentKey);
                } else {
                    fillMappings(lookupPtr, currentKeyPtr, indexWithinKey + 1, computeMapping);
                }
            }
        }
    };
}

const testing = @import("std").testing;

fn computeMapping_(key: [2]Square) Bitboard {
    return @as(Bitboard, key[0].int()) + @as(Bitboard, key[1].int());
}

test "squaresMappingLookup" {
    const lookup = comptime TwoSquaresToBitboard.init(computeMapping_);

    for (0..64) |i| {
        for (0..64) |j| {
            const square1 = Square.fromInt(@as(u6, @intCast(i)));
            const square2 = Square.fromInt(@as(u6, @intCast(j)));
            const expected = @as(Bitboard, square1.int()) + @as(Bitboard, square2.int());
            try testing.expectEqual(expected, lookup.get([2]Square{ square1, square2 }));
        }
    }
}
