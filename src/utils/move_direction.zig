const Square = @import("../mod.zig").Square;
const SquaresMappingLookup = @import("../mod.zig").utils.SquaresMappingLookup;

pub const QueenlikeMoveDirection = enum(u3) {
    Up = 0,
    Down = 7,
    UpRight = 1,
    DownLeft = 6,
    Right = 2,
    Left = 5,
    DownRight = 3,
    UpLeft = 4,

    pub fn fromInt(index: u3) QueenlikeMoveDirection {
        return @enumFromInt(index);
    }

    pub fn int(self: QueenlikeMoveDirection) u3 {
        return @intFromEnum(self);
    }

    pub fn opposite(self: QueenlikeMoveDirection) QueenlikeMoveDirection {
        return QueenlikeMoveDirection.fromInt(@as(u3, 7) - self.int());
    }

    fn compute(from: Square, to: Square) ?QueenlikeMoveDirection {
        const fromNum = from.int();
        const toNum = to.int();
        const valueChange = @as(i7, toNum) - @as(i7, fromNum);

        var positiveDirection: QueenlikeMoveDirection = undefined;

        if (from.rank() == to.rank()) {
            positiveDirection = QueenlikeMoveDirection.Right;
        } else if (@mod(valueChange, 8) == 0) {
            positiveDirection = QueenlikeMoveDirection.Down;
        } else if (@mod(valueChange, 9) == 0) {
            positiveDirection = QueenlikeMoveDirection.DownRight;
        } else if (@mod(valueChange, 7) == 0) {
            positiveDirection = QueenlikeMoveDirection.DownLeft;
        } else {
            return null;
        }

        if (valueChange > 0) {
            return positiveDirection;
        } else {
            return positiveDirection.opposite();
        }
    }
};

pub const KnightMoveDirection = enum(u3) {
    TwoUpOneRight = 0,
    TwoDownOneLeft = 7,
    TwoRightOneUp = 1,
    TwoLeftOneDown = 6,
    TwoRightOneDown = 2,
    TwoLeftOneUp = 5,
    TwoDownOneRight = 3,
    TwoUpOneLeft = 4,

    pub fn fromInt(index: u3) KnightMoveDirection {
        return @enumFromInt(index);
    }

    pub fn int(self: KnightMoveDirection) u3 {
        return @intFromEnum(self);
    }

    pub fn opposite(self: KnightMoveDirection) KnightMoveDirection {
        return KnightMoveDirection.fromInt(@as(u3, 7) - self.int());
    }

    fn compute(from: Square, to: Square) ?KnightMoveDirection {
        const fromNum = from.int();
        const toNum = to.int();
        const valueChange = @as(i7, toNum) - @as(i7, fromNum);
        const absValueChange = @abs(valueChange);

        var positiveDirection: KnightMoveDirection = undefined;

        if (absValueChange == 15) {
            positiveDirection = KnightMoveDirection.TwoDownOneLeft;
        } else if (absValueChange == 6 and from.rank() != to.rank()) {
            positiveDirection = KnightMoveDirection.TwoLeftOneDown;
        } else if (absValueChange == 17) {
            positiveDirection = KnightMoveDirection.TwoDownOneRight;
        } else if (absValueChange == 10) {
            positiveDirection = KnightMoveDirection.TwoRightOneDown;
        } else {
            return null;
        }

        if (valueChange > 0) {
            return positiveDirection;
        } else {
            return positiveDirection.opposite();
        }
    }
};

pub const PieceMoveDirection = packed union {
    queenlike: QueenlikeMoveDirection,
    knight: KnightMoveDirection,

    fn compute(from: Square, to: Square) ?PieceMoveDirection {
        if (KnightMoveDirection.compute(from, to)) |knight| {
            return PieceMoveDirection{ .knight = knight };
        } else if (QueenlikeMoveDirection.compute(from, to)) |queenlike| {
            return PieceMoveDirection{ .queenlike = queenlike };
        } else {
            return null;
        }
    }

    fn compute_(squares: [2]Square) ?PieceMoveDirection {
        return PieceMoveDirection.compute(squares[0], squares[1]);
    }

    pub fn lookup(from: Square, to: Square) ?PieceMoveDirection {
        return PIECE_MOVE_DIRECTION_LOOKUP.get([2]Square{ from, to });
    }
};

const PIECE_MOVE_DIRECTION_LOOKUP = SquaresMappingLookup(2, ?PieceMoveDirection).init(PieceMoveDirection.compute_);
