const Bitboard = @import("./mod.zig").Bitboard;
const CastlingRights = @import("./mod.zig").CastlingRights;
const Piece = @import("./mod.zig").Piece;
const File = @import("./mod.zig").File;

pub const PositionContext = struct {
    pinned: Bitboard,
    checkers: Bitboard,
    castlingRights: CastlingRights,
    doublePawnPushFile: ?File,
    halfmoveClock: u7,
    capturedPiece: Piece,

    pub fn new() PositionContext {
        return PositionContext{
            .pinned = ~@as(Bitboard, 0),
            .checkers = ~@as(Bitboard, 0),
            .castlingRights = CastlingRights.all(),
            .doublePawnPushFile = null,
            .halfmoveClock = 0,
            .capturedPiece = Piece.Null,
        };
    }
};
