pub const Board = @import("Board.zig").Board;
pub const CastlingRights = @import("CastlingRights.zig").CastlingRights;
pub const Color = @import("Color.zig").Color;
pub const File = @import("File.zig").File;
pub const Piece = @import("Piece.zig").Piece;
pub const PromotionPiece = @import("Piece.zig").PromotionPiece;
pub const Position = @import("Position.zig").Position;
pub const PositionContext = @import("PositionContext.zig").PositionContext;
pub const GameResult = @import("GameResult.zig").GameResult;
pub const Rank = @import("Rank.zig").Rank;
pub const Square = @import("Square.zig").Square;
pub const Move = @import("Move.zig").Move;
pub const MoveFlag = @import("MoveFlag.zig").MoveFlag;

pub const attacks = @import("attacks/mod.zig");
pub const fen = @import("fen.zig");
pub const masks = @import("masks.zig");
pub const utils = @import("utils/mod.zig");
pub const zobrist = @import("zobrist/mod.zig");

pub const Bitboard = u64;

const std = @import("std");

test {
    std.testing.refAllDeclsRecursive(@This());
}
