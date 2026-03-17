const assert = @import("std").debug.assert;
const Bitboard = @import("./mod.zig").Bitboard;
const Position = @import("./mod.zig").Position;
const Color = @import("./mod.zig").Color;
const CastlingRights = @import("./mod.zig").CastlingRights;
const Piece = @import("./mod.zig").Piece;
const File = @import("./mod.zig").File;

pub const PositionContext = struct {
    checkers: Bitboard, // Can have [0, 2] set bits
    pinners: Bitboard,
    checkBlockers: Bitboard,
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

    pub fn validate(self: *const PositionContext) void {
        assert(self.checkers != ~@as(Bitboard, 0));
        assert(@popCount(self.checkers) <= 2);
        // assert(self.hash != 0);
        assert(self.capturedPiece != Piece.King);
        assert(self.doublePawnPushFile == null or self.capturedPiece == Piece.Null);
        assert(self.halfmoveClock <= 100);
    }
};
