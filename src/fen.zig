const Piece = @import("./mod.zig").Piece;
const Color = @import("./mod.zig").Color;
const CastlingRights = @import("./mod.zig").CastlingRights;
const Square = @import("./mod.zig").Square;
const Board = @import("./mod.zig").Board;
const Position = @import("./mod.zig").Position;
const PositionContext = @import("./mod.zig").PositionContext;
const Rank = @import("./mod.zig").Rank;
const File = @import("./mod.zig").File;
const splitScalar = @import("std").mem.splitScalar;
const trim = @import("std").mem.trim;
const ArrayList = @import("std").ArrayList;
const Allocator = @import("std").mem.Allocator;

const FIELD_COUNT = 6;
const MAX_CHARS_IN_BOARD = 8 * 8 + 7;
const MAX_CHARS_IN_CASTLING_RIGHTS = 4;
const NUM_TURN_CHARS = 1;
const MAX_CHARS_IN_EN_PASSANT_SQUARE = 2;
const MAX_CHARS_IN_HALFMOVE_CLOCK = 3;
const MAX_CHARS_IN_FULLMOVE = 3;
const NUMBER_OF_FIELD_DELIMETERS = FIELD_COUNT - 1;
const MAX_CHARS = MAX_CHARS_IN_BOARD + NUM_TURN_CHARS + MAX_CHARS_IN_CASTLING_RIGHTS + MAX_CHARS_IN_EN_PASSANT_SQUARE + MAX_CHARS_IN_HALFMOVE_CLOCK + MAX_CHARS_IN_FULLMOVE + NUMBER_OF_FIELD_DELIMETERS;
const MAX_CHARS_PER_FIELD = [6]usize{ MAX_CHARS_IN_BOARD, NUM_TURN_CHARS, MAX_CHARS_IN_CASTLING_RIGHTS, MAX_CHARS_IN_EN_PASSANT_SQUARE, MAX_CHARS_IN_HALFMOVE_CLOCK, MAX_CHARS_IN_FULLMOVE };

pub const FenError = error{
    TooManyChars,
    TooManyCharsInBoard,
    ZeroNotAllowedInBoardRow,
    NineNotAllowedInBoardRow,
    BoardRowLengthExceeded,
    InvalidPieceInBoardRow,
    InvalidSideToMove,
    InvalidCastlingRightsChar,
    RepeatedCastlingRightsChar,
    CastlingRightsMoreThan4Chars,
    InvalidEnPassantSquare,
    EnPassantSquareMoreThan2Chars,
    InvalidHalfmoveClock,
    HalfmoveClockMoreThan3Chars,
    InvalidFullmove,
    FullmoveMoreThan3Chars,
    InvalidFieldCount,
};

fn parseFenBoardRow(fenBoardRow: []const u8, rank: Rank, board: *Board) !void {
    if (fenBoardRow.len > 8) {
        return FenError.BoardRowLengthExceeded;
    }
    const file = File.A;
    var wasNumberLast = false;
    for (fenBoardRow) |char| {
        switch (char) {
            '0' => {
                return FenError.ZeroNotAllowedInBoardRow;
            },
            '9' => {
                return FenError.NineNotAllowedInBoardRow;
            },
            '1'...'8' => {
                const gapValue = char - '0';
                if (gapValue > File.H.int() - file.int()) {
                    return FenError.BoardRowLengthExceeded;
                }
                file = File.fromInt(file.int() + gapValue);
                wasNumberLast = true;
            },
            else => {
                if (file == File.H) {
                    return FenError.BoardRowLengthExceeded;
                }
                const isUpper = char >= 'A';

                const piece = if (isUpper) Piece.fromUppercaseAscii(char) else Piece.fromLowercaseAscii(char);
                if (piece == Piece.Null) {
                    return FenError.InvalidPieceInBoardRow;
                }

                const color = Color.fromIsWhite(isUpper);
                const square = Square.fromRankFile(rank, file) catch unreachable;

                board.togglePieceAt(piece, square);
                board.xorColorMask(color, square.mask());
                board.xorOccupiedMask(square.mask());

                file = file.right() catch File.A;
            },
        }
    }
}

fn parseFenBoard(fenBoard: []const u8) !Board {
    if (fenBoard.len <= MAX_CHARS_IN_BOARD) {
        var board: Board = Board.blank();
        const rank = Rank.Eight;
        var rowStartCharIndex = 0;
        for (0..fenBoard.length) |charIndex| {
            const char = fenBoard[charIndex];
            if (char == '/') {
                try parseFenBoardRow(fenBoard[rowStartCharIndex..charIndex], rank, &board);
                rowStartCharIndex = charIndex + 1;
            }
        }
        try parseFenBoardRow(fenBoard[rowStartCharIndex..], rank, &board);
        return board;
    } else {
        return FenError.TooManyCharsInBoard;
    }
}

fn parseFenTurn(fenTurn: []const u8) !Color {
    if (fenTurn.len == 1) {
        if (fenTurn[0] == 'w') {
            return Color.White;
        } else if (fenTurn[0] == 'b') {
            return Color.Black;
        }
    }
    return FenError.InvalidSideToMove;
}

fn parseFenCastling(fenCastling: []const u8) !CastlingRights {
    if (fenCastling.len <= 4) {
        var res = CastlingRights.none();
        for (fenCastling) |char| {
            const old = res.mask();
            switch (char) {
                'K' => res.whiteKingside = true,
                'Q' => res.whiteQueenside = true,
                'k' => res.blackKingside = true,
                'q' => res.blackQueenside = true,
                else => return FenError.InvalidCastlingRightsChar,
            }
            if (old == res.mask()) {
                return FenError.RepeatedCastlingRightsChar;
            }
        }
        return res;
    } else {
        return FenError.CastlingRightsMoreThan4Chars;
    }
}

fn parseFenEnPassantSquare(fenEnPassantSquare: []const u8) !?Square {
    if (fenEnPassantSquare.len == 2) {
        return Square.fromName([2]u8{ fenEnPassantSquare[0], fenEnPassantSquare[1] }) catch FenError.InvalidEnPassantSquare;
    } else if ((fenEnPassantSquare.len == 1) and (fenEnPassantSquare[0] == '-' or
        fenEnPassantSquare[0] == '–' or
        fenEnPassantSquare[0] == '—'))
    {
        return null;
    } else {
        return FenError.EnPassantSquareMoreThan2Chars;
    }
}

fn parseFenHalfmoveClock(fenHalfmoveClock: []const u8) !u7 {
    if (fenHalfmoveClock.len <= 3) {
        var int: u10 = 0;
        for (fenHalfmoveClock) |char| {
            if (char < '0' or char > '9') {
                return FenError.InvalidHalfmoveClock;
            } else {
                int *= 10;
                int += char - '0';
            }
            if (int > 100) {
                return FenError.InvalidHalfmoveClock;
            }
        }
        return @truncate(int);
    } else {
        return FenError.HalfmoveClockMoreThan3Chars;
    }
}

fn parseFenFullmove(fenFullmove: []const u8) !u9 {
    if (fenFullmove.len <= 3) {
        var int: u12 = 0;
        for (fenFullmove) |char| {
            if (char < '0' or char > '9') {
                return FenError.InvalidFullmove;
            } else {
                int *= 10;
                int += char - '0';
            }
            if (int > 400) {
                return FenError.InvalidFullmove;
            }
        }
        return @truncate(int);
    } else {
        return FenError.FullmoveMoreThan3Chars;
    }
}

pub fn parseFen(fen: []const u8, alloc: Allocator, contextsCapacity: usize) !Position {
    const trimmedFen = trim(u8, fen, [_]u8{ " ", "\n", "\r", "\t" });

    if (trimmedFen.len > MAX_CHARS) {
        return FenError.TooManyChars;
    }

    const rawFenParts = splitScalar(u8, trimmedFen, ' ', NUMBER_OF_FIELD_DELIMETERS);

    var fenParts: [6][]const u8 = undefined;
    var fenPartsCounter: usize = 0;
    for (rawFenParts) |part| {
        const trimmedFenPart = trim(u8, part, " ");

        if (trimmedFenPart.len > 0) {
            if (fenPartsCounter >= fenParts.len) {
                return FenError.InvalidFieldCount;
            }

            fenParts[fenPartsCounter] = trimmedFenPart;
            fenPartsCounter += 1;
        }
    }

    if (fenPartsCounter != 6) {
        return FenError.InvalidFieldCount;
    }

    const board = try parseFenBoard(fenParts[0]);
    const turn = try parseFenTurn(fenParts[1]);
    const castling = try parseFenCastling(fenParts[2]);
    const enPassantSquare = try parseFenEnPassantSquare(fenParts[3]);
    const halfmoveClock = try parseFenHalfmoveClock(fenParts[4]);
    const fullmove = try parseFenFullmove(fenParts[5]);

    const pinned = undefined;
    const checkers = undefined;
    const doublePawnPushFile = (enPassantSquare orelse null).file();

    const positionContext = PositionContext{
        .pinned = pinned,
        .checkers = checkers,
        .castlingRights = castling,
        .doublePawnPushFile = doublePawnPushFile,
        .halfmoveClock = halfmoveClock,
        .capturedPiece = Piece.Null,
    };

    const gameResult = undefined;

    const pos = Position{
        .board = board,
        .contexts = ArrayList(PositionContext).initCapacity(alloc, contextsCapacity),
        .halfmove = fullmoveToHalfmove(fullmove, turn),
        .gameResult = gameResult,
        .sideToMove = turn,
    };

    try pos.contexts.append(positionContext);

    try pos.validate();

    return pos;
}

fn fullmoveToHalfmove(fullmove: u9, turn: Color) u6 {
    if (turn == Color.White) {
        return fullmove;
    } else {
        return fullmove + 1;
    }
}
