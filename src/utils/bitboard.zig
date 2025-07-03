const std = @import("std");

const Bitboard = @import("../mod.zig").Bitboard;
const Square = @import("../mod.zig").Square;

pub const Charboard = [8][8]u8;

pub fn bbToCb(bitboard: Bitboard) Charboard {
    var result: Charboard = undefined;
    for (0..8) |y| {
        for (0..8) |x| {
            const bitIndex: u6 = @truncate(y * 8 + x);
            if (bitboard & (Square.A8.mask() >> bitIndex) != 0) {
                result[y][x] = 'x';
            } else {
                result[y][x] = '.';
            }
        }
    }
    return result;
}

pub fn cbToBb(charboard: Charboard) Bitboard {
    var result: Bitboard = 0;
    for (0..8) |y| {
        for (0..8) |x| {
            const bitIndex: u6 = @truncate(y * 8 + x);
            if (charboard[y][x] != '.' and charboard[y][x] != ' ') {
                result |= Square.A8.mask() >> bitIndex;
            }
        }
    }
    return result;
}

pub fn renderBitboard(bitboard: Bitboard) [90]u8 {
    const charboard = bbToCb(bitboard);
    var result: [9][10]u8 = undefined;
    for (0..8) |y| {
        for (0..8) |x| {
            result[y][x + 1] = charboard[y][x];
        }
        result[y][0] = '8' - @as(u8, @truncate(y));
        result[y][9] = '\n';
    }
    for (0..8) |x| {
        result[8][x + 1] = 'A' + @as(u8, @truncate(x));
    }
    result[8][0] = ' ';
    result[8][9] = '\n';
    return @bitCast(result);
}

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

const testing = @import("std").testing;
const ArrayList = std.ArrayList;

test "bitboardCharboardConversions" {
    const bitboard = 0xdeadbeef0000c002;
    const charboard = bbToCb(bitboard);
    try testing.expectEqual(bitboard, cbToBb(charboard));
}

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
