//! chmog - A chess move generator library.
//! Bitboard-based state, direct legal move generation, FEN/UCI support.

pub const Board = @import("Board.zig").Board;
pub const CastlingRights = @import("CastlingRights.zig").CastlingRights;
pub const Color = @import("Color.zig").Color;
pub const Flank = @import("Flank.zig").Flank;
pub const File = @import("File.zig").File;
pub const Piece = @import("Piece.zig").Piece;
pub const PromotionPiece = @import("Piece.zig").PromotionPiece;
pub const Position = @import("Position.zig").Position;
pub const PositionContext = @import("PositionContext.zig").PositionContext;
pub const GameResult = @import("GameResult.zig").GameResult;
pub const Rank = @import("Rank.zig").Rank;
pub const Square = @import("Square.zig").Square;
pub const Move = @import("Move.zig").Move;
pub const MoveError = @import("Move.zig").MoveError;
pub const MoveFlag = @import("MoveFlag.zig").MoveFlag;
pub const PositionError = @import("Position.zig").PositionError;
pub const FenError = @import("fen.zig").FenError;
pub const FileError = @import("File.zig").FileError;
pub const RankError = @import("Rank.zig").RankError;
pub const SquareError = @import("Square.zig").SquareError;
pub const PieceError = @import("Piece.zig").PieceError;
pub const PromotionPieceError = @import("Piece.zig").PromotionPieceError;
pub const PrngError = @import("utils/Prng.zig").PrngError;

pub const attacks = @import("attacks/mod.zig");
pub const fen = @import("fen.zig");
pub const masks = @import("masks.zig");
pub const utils = @import("utils/mod.zig");
pub const zobrist = @import("zobrist/mod.zig");

/// 64-bit bitboard representing chess squares (a1=LSB, h8=MSB).
pub const Bitboard = u64;

const std = @import("std");

test {
    std.testing.refAllDeclsRecursive(@This());
}
