const std = @import("std");
const Bitboard = @import("../mod.zig").Bitboard;
const Square = @import("../mod.zig").Square;

pub fn SquaresMappingLookup(comptime numSquaresPerKey: usize, comptime OutputType: type) type {
    return struct {
        const Self = @This();

        const numKeys = std.math.pow(usize, 64, numSquaresPerKey);

        lookup: [numKeys]OutputType,

        pub fn init(comptime computeMapping: fn ([numSquaresPerKey]Square) OutputType) Self {
            var memory: [numKeys]OutputType = undefined;
            var currentKey: [numSquaresPerKey]Square = undefined;
            fillMappings(&memory, &currentKey, 0, computeMapping);
            return Self{ .lookup = memory };
        }

        pub fn get(self: Self, key: [numSquaresPerKey]Square) OutputType {
            return self.lookup[indexOfKey(key)];
        }

        fn indexOfKey(key: [numSquaresPerKey]Square) usize {
            var index: usize = 0;
            for (key) |square| {
                index = index * 64 + square.int();
            }
            return index;
        }

        fn fillMappings(lookupPtr: *[numKeys]OutputType, currentKeyPtr: *[numSquaresPerKey]Square, indexWithinKey: usize, comptime computeMapping: fn ([numSquaresPerKey]Square) OutputType) void {
            for (0..64) |i| {
                const square = Square.fromInt(i);
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

const testing = std.testing;

fn computeMapping_(key: [2]Square) Bitboard {
    return @as(Bitboard, key[0].int()) + @as(Bitboard, key[1].int());
}

test "squaresMapping" {
    const SimpleMapping = comptime SquaresMappingLookup(2, Bitboard);

    const lookup = comptime SimpleMapping.init(computeMapping_);

    for (0..64) |i| {
        for (0..64) |j| {
            std.debug.print("{d}, {d}: {d}\n", .{ i, j, lookup.get([2]Square{ Square.fromInt(i), Square.fromInt(j) }) });
            try testing.expectEqual(lookup.get([2]Square{ Square.fromInt(i), Square.fromInt(j) }), @as(Bitboard, i) + @as(Bitboard, j));
        }
    }
}
