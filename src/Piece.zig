//! Piece types: Pawn, Knight, Bishop, Rook, Queen, King.

/// Returned when Piece.fromInt receives index 7 (reserved).
pub const PieceError = error{ InvalidPieceIndex }; // index 7 is reserved
/// Returned when PromotionPiece.fromPiece receives Pawn or King.
pub const PromotionPieceError = error{ NotAPromotionPiece }; // Pawn/King cannot promote to themselves

/// Chess piece type (Null, Pawn, Knight, Bishop, Rook, Queen, King).
pub const Piece = enum(u3) {
    Null = 0,
    Pawn = 1,
    Knight = 2,
    Bishop = 3,
    Rook = 4,
    Queen = 5,
    King = 6,

    /// Creates piece from 0-6 index. Returns InvalidPieceIndex for 7.
    pub fn fromInt(index: u3) PieceError!Piece {
        if (index == 7) return PieceError.InvalidPieceIndex;
        return @enumFromInt(index);
    }

    /// Returns 0-6 index.
    pub fn int(self: Piece) u3 {
        return @intFromEnum(self);
    }

    /// Parses piece from uppercase FEN char (PNBRQK). Returns Null for invalid.
    pub fn fromUppercaseAscii(c: u8) Piece {
        return switch (c) {
            'P' => Piece.Pawn,
            'N' => Piece.Knight,
            'B' => Piece.Bishop,
            'R' => Piece.Rook,
            'Q' => Piece.Queen,
            'K' => Piece.King,
            else => Piece.Null,
        };
    }

    /// Parses piece from lowercase FEN char (pnbrqk). Returns Null for invalid.
    pub fn fromLowercaseAscii(c: u8) Piece {
        return switch (c) {
            'p' => Piece.Pawn,
            'n' => Piece.Knight,
            'b' => Piece.Bishop,
            'r' => Piece.Rook,
            'q' => Piece.Queen,
            'k' => Piece.King,
            else => Piece.Null,
        };
    }

    /// Returns uppercase FEN char (PNBRQK).
    pub fn uppercaseAscii(self: Piece) u8 {
        return switch (self) {
            Piece.Null => ' ',
            Piece.Pawn => 'P',
            Piece.Knight => 'N',
            Piece.Bishop => 'B',
            Piece.Rook => 'R',
            Piece.Queen => 'Q',
            Piece.King => 'K',
        };
    }

    /// Returns lowercase FEN char (pnbrqk).
    pub fn lowercaseAscii(self: Piece) u8 {
        return switch (self) {
            Piece.Null => ' ',
            Piece.Pawn => 'p',
            Piece.Knight => 'n',
            Piece.Bishop => 'b',
            Piece.Rook => 'r',
            Piece.Queen => 'q',
            Piece.King => 'k',
        };
    }

    /// Parses piece from empty Unicode symbol (white). Returns Null for invalid.
    pub fn fromEmptyUnicode(c: u21) Piece {
        return switch (c) {
            '♙' => Piece.Pawn,
            '♘' => Piece.Knight,
            '♗' => Piece.Bishop,
            '♖' => Piece.Rook,
            '♕' => Piece.Queen,
            '♔' => Piece.King,
            else => Piece.Null,
        };
    }

    /// Returns empty Unicode symbol for white pieces.
    pub fn emptyUnicode(self: Piece) u21 {
        return switch (self) {
            Piece.Null => ' ',
            Piece.Pawn => '♙',
            Piece.Knight => '♘',
            Piece.Bishop => '♗',
            Piece.Rook => '♖',
            Piece.Queen => '♕',
            Piece.King => '♔',
        };
    }

    /// Returns filled Unicode symbol for black pieces.
    pub fn filledUnicode(self: Piece) u21 {
        return switch (self) {
            Piece.Null => ' ',
            Piece.Pawn => '♟',
            Piece.Knight => '♞',
            Piece.Bishop => '♝',
            Piece.Rook => '♜',
            Piece.Queen => '♛',
            Piece.King => '♚',
        };
    }

    /// Parses piece from filled Unicode symbol (black). Returns Null for invalid.
    pub fn fromFilledUnicode(c: u21) Piece {
        return switch (c) {
            '♟' => Piece.Pawn,
            '♞' => Piece.Knight,
            '♝' => Piece.Bishop,
            '♜' => Piece.Rook,
            '♛' => Piece.Queen,
            '♚' => Piece.King,
            else => Piece.Null,
        };
    }
};

/// Pawn promotion piece (Knight, Bishop, Rook, Queen).
pub const PromotionPiece = enum(u2) {
    Knight = 0,
    Bishop = 1,
    Rook = 2,
    Queen = 3,

    /// Creates from 0-3 index.
    pub fn fromInt(index: u2) PromotionPiece {
        return @enumFromInt(index);
    }

    pub fn int(self: PromotionPiece) u2 {
        return @intFromEnum(self);
    }

    /// Converts Piece to PromotionPiece. Returns NotAPromotionPiece for Pawn/King.
    pub fn fromPiece(piece_: Piece) PromotionPieceError!PromotionPiece {
        if (piece_ != Piece.Knight and piece_ != Piece.Bishop and piece_ != Piece.Rook and piece_ != Piece.Queen) return PromotionPieceError.NotAPromotionPiece;
        return @enumFromInt(piece_.int() - Piece.Knight.int());
    }

    /// Returns the corresponding Piece.
    pub fn piece(self: PromotionPiece) Piece {
        return Piece.fromInt(@as(u3, self.int()) + Piece.Knight.int()) catch unreachable;
    }
};

const testing = @import("std").testing;

test "piece fromInt and int" {
    try testing.expectEqual(Piece.Null, try Piece.fromInt(0));
    try testing.expectEqual(Piece.Pawn, try Piece.fromInt(1));
    try testing.expectEqual(Piece.Knight, try Piece.fromInt(2));
    try testing.expectEqual(Piece.Bishop, try Piece.fromInt(3));
    try testing.expectEqual(Piece.Rook, try Piece.fromInt(4));
    try testing.expectEqual(Piece.Queen, try Piece.fromInt(5));
    try testing.expectEqual(Piece.King, try Piece.fromInt(6));
    try testing.expectError(PieceError.InvalidPieceIndex, Piece.fromInt(7));
    
    try testing.expectEqual(@as(u3, 0), Piece.Null.int());
    try testing.expectEqual(@as(u3, 1), Piece.Pawn.int());
    try testing.expectEqual(@as(u3, 6), Piece.King.int());
}

test "piece ascii conversions" {
    try testing.expectEqual(Piece.Pawn, Piece.fromUppercaseAscii('P'));
    try testing.expectEqual(Piece.Knight, Piece.fromUppercaseAscii('N'));
    try testing.expectEqual(Piece.Bishop, Piece.fromUppercaseAscii('B'));
    try testing.expectEqual(Piece.Rook, Piece.fromUppercaseAscii('R'));
    try testing.expectEqual(Piece.Queen, Piece.fromUppercaseAscii('Q'));
    try testing.expectEqual(Piece.King, Piece.fromUppercaseAscii('K'));
    try testing.expectEqual(Piece.Null, Piece.fromUppercaseAscii('X'));
    
    try testing.expectEqual(Piece.Pawn, Piece.fromLowercaseAscii('p'));
    try testing.expectEqual(Piece.Knight, Piece.fromLowercaseAscii('n'));
    try testing.expectEqual(Piece.Bishop, Piece.fromLowercaseAscii('b'));
    try testing.expectEqual(Piece.Rook, Piece.fromLowercaseAscii('r'));
    try testing.expectEqual(Piece.Queen, Piece.fromLowercaseAscii('q'));
    try testing.expectEqual(Piece.King, Piece.fromLowercaseAscii('k'));
    try testing.expectEqual(Piece.Null, Piece.fromLowercaseAscii('x'));
    
    try testing.expectEqual('P', Piece.Pawn.uppercaseAscii());
    try testing.expectEqual('N', Piece.Knight.uppercaseAscii());
    try testing.expectEqual('K', Piece.King.uppercaseAscii());
    
    try testing.expectEqual('p', Piece.Pawn.lowercaseAscii());
    try testing.expectEqual('n', Piece.Knight.lowercaseAscii());
    try testing.expectEqual('k', Piece.King.lowercaseAscii());
}

test "piece unicode conversions" {
    try testing.expectEqual(Piece.Pawn, Piece.fromEmptyUnicode('♙'));
    try testing.expectEqual(Piece.Knight, Piece.fromEmptyUnicode('♘'));
    try testing.expectEqual(Piece.Bishop, Piece.fromEmptyUnicode('♗'));
    try testing.expectEqual(Piece.Rook, Piece.fromEmptyUnicode('♖'));
    try testing.expectEqual(Piece.Queen, Piece.fromEmptyUnicode('♕'));
    try testing.expectEqual(Piece.King, Piece.fromEmptyUnicode('♔'));
    try testing.expectEqual(Piece.Null, Piece.fromEmptyUnicode('X'));
    
    try testing.expectEqual(Piece.Pawn, Piece.fromFilledUnicode('♟'));
    try testing.expectEqual(Piece.Knight, Piece.fromFilledUnicode('♞'));
    try testing.expectEqual(Piece.Bishop, Piece.fromFilledUnicode('♝'));
    try testing.expectEqual(Piece.Rook, Piece.fromFilledUnicode('♜'));
    try testing.expectEqual(Piece.Queen, Piece.fromFilledUnicode('♛'));
    try testing.expectEqual(Piece.King, Piece.fromFilledUnicode('♚'));
    try testing.expectEqual(Piece.Null, Piece.fromFilledUnicode('X'));
    
    try testing.expectEqual('♙', Piece.Pawn.emptyUnicode());
    try testing.expectEqual('♔', Piece.King.emptyUnicode());
    
    try testing.expectEqual('♟', Piece.Pawn.filledUnicode());
    try testing.expectEqual('♚', Piece.King.filledUnicode());
}

test "promotionPiece fromInt and int" {
    try testing.expectEqual(PromotionPiece.Knight, PromotionPiece.fromInt(0));
    try testing.expectEqual(PromotionPiece.Bishop, PromotionPiece.fromInt(1));
    try testing.expectEqual(PromotionPiece.Rook, PromotionPiece.fromInt(2));
    try testing.expectEqual(PromotionPiece.Queen, PromotionPiece.fromInt(3));
    
    try testing.expectEqual(@as(u2, 0), PromotionPiece.Knight.int());
    try testing.expectEqual(@as(u2, 3), PromotionPiece.Queen.int());
}

test "promotionPiece fromPiece and piece" {
    try testing.expectEqual(PromotionPiece.Knight, try PromotionPiece.fromPiece(Piece.Knight));
    try testing.expectEqual(PromotionPiece.Bishop, try PromotionPiece.fromPiece(Piece.Bishop));
    try testing.expectEqual(PromotionPiece.Rook, try PromotionPiece.fromPiece(Piece.Rook));
    try testing.expectEqual(PromotionPiece.Queen, try PromotionPiece.fromPiece(Piece.Queen));
    try testing.expectError(PromotionPieceError.NotAPromotionPiece, PromotionPiece.fromPiece(Piece.Pawn));
    try testing.expectError(PromotionPieceError.NotAPromotionPiece, PromotionPiece.fromPiece(Piece.King));
    
    try testing.expectEqual(Piece.Knight, PromotionPiece.Knight.piece());
    try testing.expectEqual(Piece.Bishop, PromotionPiece.Bishop.piece());
    try testing.expectEqual(Piece.Rook, PromotionPiece.Rook.piece());
    try testing.expectEqual(Piece.Queen, PromotionPiece.Queen.piece());
}
