const std = @import("std");

pub const Bitboard = u64;

pub fn iterSetBits(bitboard: Bitboard) MaskBitsIterator {
    return MaskBitsIterator{ .currentMask = bitboard };
}

pub fn iterBitCombinations(bitboard: Bitboard) BitCombinationsIterator {
    return BitCombinationsIterator{
        .set = bitboard,
        .subset = 0,
    };
}

pub const MaskBitsIterator = struct {
    currentMask: Bitboard,

    pub fn next(self: *MaskBitsIterator) ?Bitboard {
        if (self.currentMask == 0) return null;

        const mask = self.currentMask & (0 -% self.currentMask);
        self.currentMask ^= mask;

        return mask;
    }
};

pub const BitCombinationsIterator = struct {
    set: Bitboard,
    subset: Bitboard,

    pub fn next(self: *BitCombinationsIterator) ?Bitboard {
        if (self.set == 0 and self.subset == 0) return null;

        const current = self.subset;
        self.subset = (self.subset -% self.set) & self.set;
        if (self.subset == 0) self.set = 0;

        return current;
    }
};

const testing = std.testing;
const ArrayList = std.ArrayList;

test "iterBitCombinations" {
    {
        const mask = 0;
        var iter = iterBitCombinations(mask);
        try testing.expectEqual(null, iter.next());
    }

    {
        const mask = 1;
        var iter = iterBitCombinations(mask);
        const expected = [2]Bitboard{ 0, 1 };

        var result = ArrayList(Bitboard).init(testing.allocator);
        defer result.deinit();

        while (iter.next()) |item| {
            try result.append(item);
        }

        try testing.expectEqualSlices(Bitboard, &expected, result.items);
    }

    {
        const mask = 0b1010;
        var iter = iterBitCombinations(mask);
        const expected = [4]Bitboard{ 0b0000, 0b0010, 0b1000, 0b1010 };

        var result = ArrayList(Bitboard).init(testing.allocator);
        defer result.deinit();

        while (iter.next()) |item| {
            try result.append(item);
        }

        try testing.expectEqualSlices(Bitboard, &expected, result.items);
    }

    {
        const mask = 0b1111;
        var iter = iterBitCombinations(mask);
        const expected = [16]Bitboard{
            0b0000, 0b0001, 0b0010, 0b0011, 0b0100, 0b0101, 0b0110, 0b0111, 0b1000, 0b1001, 0b1010,
            0b1011, 0b1100, 0b1101, 0b1110, 0b1111,
        };

        var result = ArrayList(Bitboard).init(testing.allocator);
        defer result.deinit();

        while (iter.next()) |item| {
            try result.append(item);
        }

        try testing.expectEqualSlices(Bitboard, &expected, result.items);
    }
}
