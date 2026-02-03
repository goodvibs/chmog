const assert = @import("std").debug.assert;
const Bitboard = @import("./mod.zig").Bitboard;
const Position = @import("./mod.zig").Position;
const Color = @import("./mod.zig").Color;
const CastlingRights = @import("./mod.zig").CastlingRights;
const Piece = @import("./mod.zig").Piece;
const File = @import("./mod.zig").File;

pub const PositionContext = struct {
    checkers: Bitboard, // Can have [0, 2] set bits
    pinners: Bitboard, // Includes pieces from both sides
    checkBlockers: [2]Bitboard,
    hash: Bitboard,
    castlingRights: CastlingRights,
    movedPiece: Piece,
    capturedPiece: Piece,
    doublePawnPushFile: ?File,
    halfmoveClock: u7, // Number of halfmoves since last pawn move or capture

    // How many positions ago was this position repeated, where:
    // a positive number indicates it was repeated once
    // a negative number indicates the position was repeated twice already
    // zero indicates it has never been repeated
    repetition: i10,

    pub fn checkBlockersForColor(self: *const PositionContext, forColor: Color) Bitboard {
        return self.checkBlockers[@as(usize, forColor.int())];
    }

    pub fn setCheckBlockersForColor(
        self: *const PositionContext,
        newBlockers: Bitboard,
        forColor: Color,
    ) void {
        self.checkBlockers[@as(usize, forColor.int())] = newBlockers;
    }

    pub fn validate(self: *const PositionContext) void {
        assert(self.checkers != ~@as(Bitboard, 0));
        assert(@popCount(self.pinners) < @popCount(self.checkers));
        assert(self.checkBlockersForColor(Color.White) & self.checkBlockersForColor(Color.Black) == 0);
        // assert(self.hash != 0);
        assert(self.movedPiece != Piece.King or CastlingRights.mask == @as(u4, 0));
        assert(self.capturedPiece != Piece.King);
        assert(self.doublePawnPushFile == null or self.capturedPiece == null);
        assert(self.halfmoveClock <= 100);
    }
};
