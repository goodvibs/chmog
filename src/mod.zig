pub const Board = @import("board.zig").Board;
pub const CastlingRights = @import("castlingRights.zig").CastlingRights;
pub const Color = @import("color.zig").Color;
pub const File = @import("file.zig").File;
pub const Piece = @import("piece.zig").Piece;
pub const PromotionPiece = @import("piece.zig").PromotionPiece;
pub const Position = @import("position.zig").Position;
pub const PositionContext = @import("positionContext.zig").PositionContext;
pub const GameResult = @import("gameResult.zig").GameResult;
pub const Rank = @import("rank.zig").Rank;
pub const Square = @import("square.zig").Square;
pub const Move = @import("move/mod.zig").Move;
pub const MoveFlag = @import("move/flag.zig").MoveFlag;

pub const attacks = @import("attacks/mod.zig");
pub const masks = @import("masks.zig");
pub const utils = @import("utils/mod.zig");
pub const zobrist = @import("zobrist/mod.zig");

pub const Bitboard = u64;

const std = @import("std");

test {
    std.testing.refAllDeclsRecursive(@This());
}
