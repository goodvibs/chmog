const Piece = enum(u3) {
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
