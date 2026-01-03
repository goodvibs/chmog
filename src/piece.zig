pub const Piece = enum(u3) {
    Null = 0,
    Pawn = 1,
    Knight = 2,
    Bishop = 3,
    Rook = 4,
    Queen = 5,
    King = 6,

    pub fn fromInt(index: u3) !Piece {
        if (index == 7) return error.InvalidPiece;
        return @enumFromInt(index);
    }

    pub fn int(self: Piece) u3 {
        return @intFromEnum(self);
    }

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

pub const PromotionPiece = enum(u2) {
    Knight = 0,
    Bishop = 1,
    Rook = 2,
    Queen = 3,

    pub fn fromInt(index: u2) PromotionPiece {
        return @enumFromInt(index);
    }

    pub fn int(self: PromotionPiece) u2 {
        return @intFromEnum(self);
    }

    pub fn fromPiece(piece_: Piece) !PromotionPiece {
        if (piece_ != Piece.Knight and piece_ != Piece.Bishop and piece_ != Piece.Rook and piece_ != Piece.Queen) return error.InvalidPiece;
        return @enumFromInt(piece_.int() - Piece.Knight.int());
    }

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
    try testing.expectError(error.InvalidPiece, Piece.fromInt(7));
    
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
    try testing.expectError(error.InvalidPiece, PromotionPiece.fromPiece(Piece.Pawn));
    try testing.expectError(error.InvalidPiece, PromotionPiece.fromPiece(Piece.King));
    
    try testing.expectEqual(Piece.Knight, PromotionPiece.Knight.piece());
    try testing.expectEqual(Piece.Bishop, PromotionPiece.Bishop.piece());
    try testing.expectEqual(Piece.Rook, PromotionPiece.Rook.piece());
    try testing.expectEqual(Piece.Queen, PromotionPiece.Queen.piece());
}
