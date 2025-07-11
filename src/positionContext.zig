const Bitboard = @import("./mod.zig").Bitboard;
const CastlingRights = @import("./mod.zig").CastlingRights;
const Piece = @import("./mod.zig").Piece;
const StaleableHash = @import("./mod.zig").zobrist.StaleableHash;
const File = @import("./mod.zig").File;

const PositionContext = struct {
    pinned: Bitboard,
    checkers: Bitboard,
    zobrist_hash: StaleableHash,
    castling_rights: CastlingRights,
    double_pawn_push: ?File,
    halfmove_clock: u7,
    captured_piece: Piece,

    pub fn blank() PositionContext {
        return PositionContext{
            .pinned = 0,
            .checkers = 0,
            .zobrist_hash = StaleableHash{ .stale = 0 },
            .castling_rights = CastlingRights.none(),
            .double_pawn_push = null,
            .halfmove_clock = 0,
            .captured_piece = Piece.Null,
        };
    }
};
