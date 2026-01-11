const std = @import("std");

const Bitboard = @import("../mod.zig").Bitboard;
const Square = @import("../mod.zig").Square;
const TwoSquaresToBitboard = @import("../mod.zig").utils.TwoSquaresToBitboard;
const QueenlikeMoveDirection = @import("../mod.zig").utils.QueenlikeMoveDirection;
const PieceMoveDirection = @import("../mod.zig").utils.PieceMoveDirection;

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

fn computeEdgeToEdge(squares: [2]Square) Bitboard {
    const square1 = squares[0];
    const square2 = squares[1];
    if (square1 == square2 or !square1.isOnSameLineAs(square2)) return 0 else {
        const direction: QueenlikeMoveDirection = (PieceMoveDirection.lookup(square1, square2) orelse unreachable).queenlike;
        var current = square1;
        var mask = current.mask();
        while (current.neighborInDirection(direction)) |next| {
            mask |= next.mask();
            current = next;
        }
        var current2 = square1;
        while (current2.neighborInDirection(direction.opposite())) |next| {
            mask |= next.mask();
            current2 = next;
        }
        return mask;
    }
}

const EDGE_TO_EDGE_LOOKUP = TwoSquaresToBitboard.init(computeEdgeToEdge);

pub fn edgeToEdge(square1: Square, square2: Square) Bitboard {
    return EDGE_TO_EDGE_LOOKUP.get([2]Square{ square1, square2 });
}

fn computeBetween(squares: [2]Square) Bitboard {
    const square1 = squares[0];
    const square2 = squares[1];
    if (square1 == square2 or !square1.isOnSameLineAs(square2)) return 0 else {
        const direction = (PieceMoveDirection.lookup(square1, square2) orelse unreachable).queenlike;
        var current = square1;
        var res: Bitboard = 0;
        while (true) {
            current = current.neighborInDirection(direction) orelse unreachable;
            if (current == square2) break;
            res |= current.mask();
        }
        return res;
    }
}

const BETWEEN_LOOKUP = TwoSquaresToBitboard.init(computeBetween);

pub fn between(square1: Square, square2: Square) Bitboard {
    return BETWEEN_LOOKUP.get([2]Square{ square1, square2 });
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

        var result = try ArrayList(Bitboard).initCapacity(testing.allocator, 2);
        defer result.deinit(testing.allocator);

        while (iter.next()) |item| {
            try result.append(testing.allocator, item);
        }

        try testing.expectEqualSlices(Bitboard, &expected, result.items);
    }

    {
        const mask = 0b1010;
        var iter = iterBitCombinations(mask);
        const expected = [4]Bitboard{ 0b0000, 0b0010, 0b1000, 0b1010 };

        var result = try ArrayList(Bitboard).initCapacity(testing.allocator, 4);
        defer result.deinit(testing.allocator);

        while (iter.next()) |item| {
            try result.append(testing.allocator, item);
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

        var result = try ArrayList(Bitboard).initCapacity(testing.allocator, 16);
        defer result.deinit(testing.allocator);

        while (iter.next()) |item| {
            try result.append(testing.allocator, item);
        }

        try testing.expectEqualSlices(Bitboard, &expected, result.items);
    }
}

test "iterSetBits" {
    {
        const mask = 0;
        var iter = iterSetBits(mask);
        try testing.expectEqual(null, iter.next());
    }

    {
        const mask = Square.A1.mask();
        var iter = iterSetBits(mask);
        const first = iter.next();
        try testing.expect(first != null);
        try testing.expectEqual(Square.A1.mask(), first.?);
        try testing.expectEqual(null, iter.next());
    }

    {
        const mask = Square.A1.mask() | Square.E4.mask() | Square.H8.mask();
        var iter = iterSetBits(mask);
        var count: u32 = 0;
        var total: Bitboard = 0;
        while (iter.next()) |bit| {
            count += 1;
            total |= bit;
        }
        try testing.expectEqual(@as(u32, 3), count);
        try testing.expectEqual(mask, total);
    }
}

test "between" {
    // Same square
    try testing.expectEqual(@as(Bitboard, 0), between(Square.E4, Square.E4));

    // Adjacent squares
    try testing.expectEqual(@as(Bitboard, 0), between(Square.E4, Square.E5));

    // On same rank
    const betweenRank = between(Square.E4, Square.H4);
    try testing.expect(betweenRank & Square.F4.mask() != 0);
    try testing.expect(betweenRank & Square.G4.mask() != 0);
    try testing.expect(betweenRank & Square.E4.mask() == 0);
    try testing.expect(betweenRank & Square.H4.mask() == 0);

    // On same file
    const betweenFile = between(Square.E4, Square.E1);
    try testing.expect(betweenFile & Square.E2.mask() != 0);
    try testing.expect(betweenFile & Square.E3.mask() != 0);
    try testing.expect(betweenFile & Square.E4.mask() == 0);
    try testing.expect(betweenFile & Square.E1.mask() == 0);

    // On same diagonal
    const betweenDiag = between(Square.E4, Square.B1);
    try testing.expect(betweenDiag & Square.D3.mask() != 0);
    try testing.expect(betweenDiag & Square.C2.mask() != 0);
    try testing.expect(betweenDiag & Square.E4.mask() == 0);
    try testing.expect(betweenDiag & Square.B1.mask() == 0);

    // Not on same line
    try testing.expectEqual(@as(Bitboard, 0), between(Square.E4, Square.A1));
}

test "edgeToEdge" {
    // Same square
    try testing.expectEqual(@as(Bitboard, 0), edgeToEdge(Square.E4, Square.E4));

    // On same rank
    const edgeRank = edgeToEdge(Square.E4, Square.H4);
    try testing.expect(edgeRank & Square.E4.mask() != 0);
    try testing.expect(edgeRank & Square.H4.mask() != 0);
    try testing.expect(edgeRank & Square.F4.mask() != 0);
    try testing.expect(edgeRank & Square.G4.mask() != 0);
    try testing.expect(edgeRank & Square.A4.mask() != 0);
    try testing.expect(edgeRank & Square.B4.mask() != 0);

    // On same file
    const edgeFile = edgeToEdge(Square.E4, Square.E1);
    try testing.expect(edgeFile & Square.E4.mask() != 0);
    try testing.expect(edgeFile & Square.E1.mask() != 0);
    try testing.expect(edgeFile & Square.E2.mask() != 0);
    try testing.expect(edgeFile & Square.E3.mask() != 0);
    try testing.expect(edgeFile & Square.E8.mask() != 0);

    // Not on same line
    try testing.expectEqual(@as(Bitboard, 0), edgeToEdge(Square.E4, Square.A1));
}
