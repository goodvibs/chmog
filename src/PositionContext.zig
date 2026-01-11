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

    pub fn blank() PositionContext {
        return PositionContext{
            .pinned = 0,
            .checkers = 0,
            .castlingRights = CastlingRights.none(),
            .doublePawnPushFile = null,
            .halfmoveClock = 0,
            .capturedPiece = Piece.Null,
        };
    }
};
