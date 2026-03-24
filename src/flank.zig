//! Kingside or queenside flank for castling.

const Bitboard = @import("./root.zig").Bitboard;
const Color = @import("./root.zig").Color;
const File = @import("./root.zig").File;
const Rank = @import("./root.zig").Rank;
const Square = @import("./root.zig").Square;

/// Represents the kingside (files E-H) or queenside (files A-D) of the board.
/// Used for castling and other flank-based logic.
pub const Flank = enum(u1) {
    Kingside = 0,
    Queenside = 1,

    /// Creates flank from 0-1 index (Kingside=0, Queenside=1).
    pub fn fromInt(index: u1) Flank {
        return @enumFromInt(index);
    }

    /// Returns 0-1 index.
    pub fn int(self: Flank) u1 {
        return @intFromEnum(self);
    }

    /// Returns the opposite flank (Kingside <-> Queenside).
    pub fn other(self: Flank) Flank {
        return Flank.fromInt(~self.int());
    }

    /// Returns the bitboard mask for all files on this flank.
    /// Kingside: E, F, G, H. Queenside: A, B, C, D.
    pub fn mask(self: Flank) Bitboard {
        return switch (self) {
            .Kingside => File.E.mask() | File.F.mask() | File.G.mask() | File.H.mask(),
            .Queenside => File.A.mask() | File.B.mask() | File.C.mask() | File.D.mask(),
        };
    }

    /// Returns the bitboard of squares between king and rook for castling on this flank.
    /// These squares must be empty for castling to be legal.
    pub fn castlingGapMask(self: Flank, forColor: Color) Bitboard {
        const rank = forColor.backRank();
        return switch (self) {
            .Kingside => rank.mask() & (File.F.mask() | File.G.mask()),
            .Queenside => rank.mask() & (File.B.mask() | File.C.mask() | File.D.mask()),
        };
    }

    /// Returns the bitboard of squares the king passes through when castling on this flank.
    /// These squares must not be attacked for castling to be legal.
    pub fn castlingCheckMask(self: Flank, forColor: Color) Bitboard {
        const rank = forColor.backRank();
        return switch (self) {
            .Kingside => rank.mask() & (File.F.mask() | File.G.mask()),
            .Queenside => rank.mask() & (File.C.mask() | File.D.mask()),
        };
    }

    /// Returns the bitboard of files the rook moves through when castling on this flank.
    /// Used to compute the rook move mask for make/unmake.
    pub fn castlingRookFilesMask(self: Flank) Bitboard {
        return switch (self) {
            .Kingside => File.H.mask() | File.F.mask(),
            .Queenside => File.A.mask() | File.D.mask(),
        };
    }
};

const testing = @import("std").testing;

test "flank fromInt and int" {
    try testing.expectEqual(@as(u1, 0), Flank.Kingside.int());
    try testing.expectEqual(@as(u1, 1), Flank.Queenside.int());
    try testing.expectEqual(Flank.Kingside, Flank.fromInt(0));
    try testing.expectEqual(Flank.Queenside, Flank.fromInt(1));
}

test "flank other" {
    try testing.expectEqual(Flank.Queenside, Flank.Kingside.other());
    try testing.expectEqual(Flank.Kingside, Flank.Queenside.other());
}

test "flank mask" {
    try testing.expectEqual(
        File.E.mask() | File.F.mask() | File.G.mask() | File.H.mask(),
        Flank.Kingside.mask(),
    );
    try testing.expectEqual(
        File.A.mask() | File.B.mask() | File.C.mask() | File.D.mask(),
        Flank.Queenside.mask(),
    );
}

test "flank castlingGapMask" {
    const whiteKingside = Flank.Kingside.castlingGapMask(Color.White);
    try testing.expect(whiteKingside & Square.F1.mask() != 0);
    try testing.expect(whiteKingside & Square.G1.mask() != 0);
    try testing.expect(whiteKingside & Square.E1.mask() == 0);

    const blackQueenside = Flank.Queenside.castlingGapMask(Color.Black);
    try testing.expect(blackQueenside & Square.B8.mask() != 0);
    try testing.expect(blackQueenside & Square.C8.mask() != 0);
    try testing.expect(blackQueenside & Square.D8.mask() != 0);
}

test "flank castlingCheckMask" {
    const whiteKingside = Flank.Kingside.castlingCheckMask(Color.White);
    try testing.expect(whiteKingside & Square.F1.mask() != 0);
    try testing.expect(whiteKingside & Square.G1.mask() != 0);

    const whiteQueenside = Flank.Queenside.castlingCheckMask(Color.White);
    try testing.expect(whiteQueenside & Square.C1.mask() != 0);
    try testing.expect(whiteQueenside & Square.D1.mask() != 0);
    try testing.expect(whiteQueenside & Square.B1.mask() == 0);
}

test "flank castlingRookFilesMask" {
    try testing.expect(Flank.Kingside.castlingRookFilesMask() & File.H.mask() != 0);
    try testing.expect(Flank.Kingside.castlingRookFilesMask() & File.F.mask() != 0);
    try testing.expect(Flank.Queenside.castlingRookFilesMask() & File.A.mask() != 0);
    try testing.expect(Flank.Queenside.castlingRookFilesMask() & File.D.mask() != 0);
}
