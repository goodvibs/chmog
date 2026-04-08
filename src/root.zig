//! chmog - A chess move generator library.
//! Bitboard-based state, direct legal move generation, FEN/UCI support.

pub const Board = @import("board.zig").Board;
pub const CastlingRights = @import("castling_rights.zig").CastlingRights;
pub const Color = @import("color.zig").Color;
pub const Flank = @import("flank.zig").Flank;
pub const File = @import("file.zig").File;
pub const Piece = @import("piece.zig").Piece;
pub const PromotionPiece = @import("piece.zig").PromotionPiece;
pub const Position = @import("position.zig").Position;
pub const PositionError = @import("position.zig").PositionError;
pub const PositionContext = @import("position_context.zig").PositionContext;
pub const GameResult = @import("game_result.zig").GameResult;
pub const Rank = @import("rank.zig").Rank;
pub const Square = @import("square.zig").Square;
pub const Move = @import("move.zig").Move;
pub const MoveFlag = @import("move.zig").MoveFlag;
pub const FenError = @import("fen.zig").FenError;

pub const attacks = @import("attacks/mod.zig");
pub const fen = @import("fen.zig");
pub const utils = @import("utils/mod.zig");
pub const zobrist = @import("zobrist/mod.zig");

/// 64-bit bitboard representing chess squares (a1=LSB, h8=MSB).
pub const Bitboard = u64;

const std = @import("std");

test {
    std.testing.refAllDeclsRecursive(@This());
}
