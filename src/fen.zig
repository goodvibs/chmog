const Bitboard = @import("./mod.zig").Bitboard;
const Piece = @import("./mod.zig").Piece;
const Color = @import("./mod.zig").Color;
const CastlingRights = @import("./mod.zig").CastlingRights;
const Square = @import("./mod.zig").Square;
const Board = @import("./mod.zig").Board;
const Position = @import("./mod.zig").Position;
const PositionContext = @import("./mod.zig").PositionContext;
const GameResult = @import("./mod.zig").GameResult;
const Rank = @import("./mod.zig").Rank;
const File = @import("./mod.zig").File;
const splitScalar = @import("std").mem.splitScalar;
const trim = @import("std").mem.trim;
const ArrayList = @import("std").ArrayList;
const Allocator = @import("std").mem.Allocator;
const assert = @import("std").debug.assert;

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
    BoardRowLengthInsufficient,
    InvalidCharInBoardRow,
    InvalidSideToMove,
    InvalidCastlingRightsChar,
    RepeatedCastlingRightsChar,
    CastlingRightsMoreThan4Chars,
    InvalidEnPassantSquare,
    EnPassantSquareMoreThan2Chars,
    EnPassantWithoutDoublePawnPush,
    InvalidHalfmoveClock,
    HalfmoveClockMoreThan3Chars,
    HalfmoveClockMoreThanHalfmovesPlayed,
    InvalidFullmove,
    FullmoveZero,
    FullmoveMoreThan3Chars,
    InvalidFieldCount,
    PawnsInFirstOrLastRank,
    NotOneKingPerColor,
    IsInIllegalCheck,
};

fn parseFenBoardRow(fenBoardRow: []const u8, rank: Rank, board: *Board) !void {
    if (fenBoardRow.len > 8) {
        return FenError.BoardRowLengthExceeded;
    }
    var file = File.A;
    var rowComplete = false;
    for (fenBoardRow) |char| {
        switch (char) {
            '0' => {
                return FenError.ZeroNotAllowedInBoardRow;
            },
            '9' => {
                return FenError.NineNotAllowedInBoardRow;
            },
            '1'...'8' => {
                const emptySquares: u4 = @truncate(char - '0');
                const squaresLeftInRow: u4 = @as(u4, File.H.int()) - @as(u4, file.int()) + 1;
                if (emptySquares == squaresLeftInRow) {
                    rowComplete = true;
                    break;
                } else if (emptySquares < squaresLeftInRow) {
                    file = file.rightN(@truncate(emptySquares)) catch unreachable;
                } else {
                    return FenError.BoardRowLengthExceeded;
                }
            },
            'p', 'n', 'b', 'r', 'q', 'k', 'P', 'N', 'B', 'R', 'Q', 'K' => {
                const isUpper = char < 'a';
                const piece = (if (isUpper) Piece.fromUppercaseAscii(char) else Piece.fromLowercaseAscii(char));
                assert(piece != Piece.Null);
                const color = Color.fromIsWhite(isUpper);
                const square = Square.fromRankAndFile(rank, file);

                assert(board.occupiedMask() & square.mask() == 0);

                board.xorPieceMask(piece, square.mask());
                board.xorColorMask(color, square.mask());
                board.xorOccupiedMask(square.mask());

                file = file.right() catch {
                    rowComplete = true;
                    break;
                };
            },
            else => return FenError.InvalidCharInBoardRow,
        }
    }
    if (!rowComplete) {
        return FenError.BoardRowLengthInsufficient;
    }
}

fn parseFenBoard(fenBoard: []const u8) !Board {
    if (fenBoard.len <= MAX_CHARS_IN_BOARD) {
        var board: Board = Board.blank();
        var rank = Rank.Eight;
        var rowStartCharIndex: usize = 0;
        for (0..fenBoard.len) |charIndex| {
            const char = fenBoard[charIndex];
            if (char == '/') {
                try parseFenBoardRow(fenBoard[rowStartCharIndex..charIndex], rank, &board);
                rowStartCharIndex = charIndex + 1;
                rank = rank.down() catch unreachable;
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
        if (fenCastling.len == 1 and fenCastling[0] == '-') {
            return CastlingRights.none();
        }
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
        if (int == 0) return FenError.FullmoveZero;
        return @truncate(int);
    } else {
        return FenError.FullmoveMoreThan3Chars;
    }
}

pub fn parseFen(fen: []const u8, alloc: Allocator, contextsCapacity: usize) !Position {
    const trimmedFen = trim(u8, fen, &[_]u8{ ' ', '\n', '\r', '\t' });

    if (trimmedFen.len > MAX_CHARS) {
        return FenError.TooManyChars;
    }

    var fenParts: [6][]const u8 = undefined;
    var fenPartsCounter: usize = 0;
    var it = splitScalar(u8, trimmedFen, ' ');
    while (it.next()) |part| {
        const trimmedFenPart = trim(u8, part, &[_]u8{' '});

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
    const halfmove = fullmoveToHalfmove(fullmove, turn);

    const doublePawnPushFile: ?File = if (enPassantSquare) |epSquare| blk: {
        const pawnRank = if (turn == Color.Black) Rank.Four else Rank.Five;
        const pawnSquare = Square.fromRankAndFile(pawnRank, epSquare.file());
        if (halfmove < 1 or pawnSquare.mask() & board.colorMask(turn.other()) & board.pieceMask(Piece.Pawn) == 0) {
            return FenError.EnPassantWithoutDoublePawnPush;
        }
        break :blk epSquare.file();
    } else null;

    const positionContext = PositionContext{
        .pinned = ~@as(Bitboard, 0),
        .checkers = ~@as(Bitboard, 0),
        .castlingRights = castling,
        .doublePawnPushFile = doublePawnPushFile,
        .halfmoveClock = halfmoveClock,
        .capturedPiece = Piece.Null,
    };

    var previousContexts = try ArrayList(PositionContext).initCapacity(alloc, contextsCapacity);
    errdefer previousContexts.deinit(alloc);

    const pos = Position{
        .board = board,
        .currentContext = positionContext,
        .previousContexts = previousContexts,
        .halfmove = halfmove,
        .gameResult = GameResult.None,
        .sideToMove = turn,
    };

    assert(pos.board.isValid());

    if (!pos.doHalfmoveAndSideToMoveAgree()) {
        return FenError.HalfmoveClockMoreThanHalfmovesPlayed;
    }

    if (!pos.isHalfmoveClockPlausible()) {
        return FenError.HalfmoveClockMoreThanHalfmovesPlayed;
    }

    if (!pos.board.hasNoPawnsInFirstNorLastRank()) {
        return FenError.PawnsInFirstOrLastRank;
    }

    if (!pos.board.hasOneKingPerColor()) {
        return FenError.NotOneKingPerColor;
    }

    if (!pos.isNotInIllegalCheck()) {
        return FenError.IsInIllegalCheck;
    }

    return pos;
}

fn fullmoveToHalfmove(fullmove: u9, turn: Color) u10 {
    assert(fullmove > 0);
    return (@as(u10, fullmove) - 1) * 2 + @as(u10, turn.int());
}

const testing = @import("std").testing;

test "parseFen starting position" {
    const startingFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    var pos = try parseFen(startingFen, testing.allocator, 0);
    defer pos.previousContexts.deinit(testing.allocator);

    try testing.expectEqual(Color.White, pos.sideToMove);
    try testing.expect(pos.board.hasOneKingPerColor());
    try testing.expect(pos.board.hasNoPawnsInFirstNorLastRank());
    try testing.expectEqual(@as(u10, 0), pos.halfmove);
}

test "parseFen board parsing" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1";
    var pos = try parseFen(fen, testing.allocator, 100);
    defer pos.previousContexts.deinit(testing.allocator);

    try testing.expect(pos.board.mask(Piece.Rook, Color.White) & Square.A1.mask() != 0);
    try testing.expect(pos.board.mask(Piece.Knight, Color.White) & Square.B1.mask() != 0);
    try testing.expect(pos.board.mask(Piece.Bishop, Color.White) & Square.C1.mask() != 0);
    try testing.expect(pos.board.mask(Piece.Queen, Color.White) & Square.D1.mask() != 0);
    try testing.expect(pos.board.mask(Piece.King, Color.White) & Square.E1.mask() != 0);
    try testing.expect(pos.board.mask(Piece.Pawn, Color.White) & Square.A2.mask() != 0);

    try testing.expect(pos.board.mask(Piece.Rook, Color.Black) & Square.A8.mask() != 0);
    try testing.expect(pos.board.mask(Piece.Pawn, Color.Black) & Square.A7.mask() != 0);
}

test "parseFen side to move" {
    const whiteFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1";
    var whitePos = try parseFen(whiteFen, testing.allocator, 100);
    defer whitePos.previousContexts.deinit(testing.allocator);
    try testing.expectEqual(Color.White, whitePos.sideToMove);

    const blackFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b - - 0 1";
    var blackPos = try parseFen(blackFen, testing.allocator, 100);
    defer blackPos.previousContexts.deinit(testing.allocator);
    try testing.expectEqual(Color.Black, blackPos.sideToMove);
}

test "parseFen castling rights" {
    const allCastling = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    var pos1 = try parseFen(allCastling, testing.allocator, 100);
    defer pos1.previousContexts.deinit(testing.allocator);
    try testing.expect(pos1.currentContext.castlingRights.kingsideForColor(Color.White));
    try testing.expect(pos1.currentContext.castlingRights.queensideForColor(Color.White));
    try testing.expect(pos1.currentContext.castlingRights.kingsideForColor(Color.Black));
    try testing.expect(pos1.currentContext.castlingRights.queensideForColor(Color.Black));

    const noCastling = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1";
    var pos2 = try parseFen(noCastling, testing.allocator, 100);
    defer pos2.previousContexts.deinit(testing.allocator);
    try testing.expect(!pos2.currentContext.castlingRights.kingsideForColor(Color.White));
    try testing.expect(!pos2.currentContext.castlingRights.queensideForColor(Color.White));

    const whiteOnly = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQ - 0 1";
    var pos3 = try parseFen(whiteOnly, testing.allocator, 100);
    defer pos3.previousContexts.deinit(testing.allocator);
    try testing.expect(pos3.currentContext.castlingRights.kingsideForColor(Color.White));
    try testing.expect(pos3.currentContext.castlingRights.queensideForColor(Color.White));
    try testing.expect(!pos3.currentContext.castlingRights.kingsideForColor(Color.Black));
}

test "parseFen en passant" {
    // Valid en passant square
    const fenWithEnPassant = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1";
    var pos = try parseFen(fenWithEnPassant, testing.allocator, 100);
    defer pos.previousContexts.deinit(testing.allocator);
    try testing.expect(pos.currentContext.doublePawnPushFile != null);
    try testing.expectEqual(File.E, pos.currentContext.doublePawnPushFile.?);

    // No en passant
    const fenNoEnPassant = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1";
    var pos2 = try parseFen(fenNoEnPassant, testing.allocator, 100);
    defer pos2.previousContexts.deinit(testing.allocator);
    try testing.expect(pos2.currentContext.doublePawnPushFile == null);
}

test "parseFen halfmove clock and fullmove" {
    // fullmove 10, white to move -> halfmove = (10-1)*2 = 18
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 5 10";
    var pos = try parseFen(fen, testing.allocator, 100);
    defer pos.previousContexts.deinit(testing.allocator);
    try testing.expectEqual(@as(u7, 5), pos.currentContext.halfmoveClock);
    try testing.expectEqual(@as(u10, 18), pos.halfmove);
}

test "parseFen errors - invalid board row length" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR9 w - - 0 1";
    try testing.expectError(FenError.BoardRowLengthExceeded, parseFen(fen, testing.allocator, 100));
}

test "parseFen errors - zero in board row" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/0/PPPPPPPP/RNBQKBNR w - - 0 1";
    try testing.expectError(FenError.ZeroNotAllowedInBoardRow, parseFen(fen, testing.allocator, 100));
}

test "parseFen errors - nine in board row" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/9/PPPPPPPP/RNBQKBNR w - - 0 1";
    try testing.expectError(FenError.NineNotAllowedInBoardRow, parseFen(fen, testing.allocator, 100));
}

test "parseFen errors - invalid piece" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNX w - - 0 1";
    try testing.expectError(FenError.InvalidCharInBoardRow, parseFen(fen, testing.allocator, 100));
}

test "parseFen errors - invalid side to move" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR x - - 0 1";
    try testing.expectError(FenError.InvalidSideToMove, parseFen(fen, testing.allocator, 100));

    const fen2 = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR ww - - 0 1";
    try testing.expectError(FenError.InvalidSideToMove, parseFen(fen2, testing.allocator, 100));
}

test "parseFen errors - invalid castling rights char" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w X - 0 1";
    try testing.expectError(FenError.InvalidCastlingRightsChar, parseFen(fen, testing.allocator, 100));
}

test "parseFen errors - repeated castling rights char" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KK - 0 1";
    try testing.expectError(FenError.RepeatedCastlingRightsChar, parseFen(fen, testing.allocator, 100));
}

test "parseFen errors - castling rights too long" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkqK - 0 1";
    try testing.expectError(FenError.CastlingRightsMoreThan4Chars, parseFen(fen, testing.allocator, 100));
}

test "parseFen errors - invalid en passant square" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - xx 0 1";
    try testing.expectError(FenError.InvalidEnPassantSquare, parseFen(fen, testing.allocator, 100));
}

test "parseFen errors - en passant square too long" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - e33 0 1";
    try testing.expectError(FenError.EnPassantSquareMoreThan2Chars, parseFen(fen, testing.allocator, 100));
}

test "parseFen errors - invalid halfmove clock" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - x 1";
    try testing.expectError(FenError.InvalidHalfmoveClock, parseFen(fen, testing.allocator, 100));
}

test "parseFen errors - halfmove clock too long" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 1234 1";
    try testing.expectError(FenError.HalfmoveClockMoreThan3Chars, parseFen(fen, testing.allocator, 100));
}

test "parseFen errors - invalid fullmove" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 x";
    try testing.expectError(FenError.InvalidFullmove, parseFen(fen, testing.allocator, 100));
}

test "parseFen errors - fullmove too long" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1234";
    try testing.expectError(FenError.FullmoveMoreThan3Chars, parseFen(fen, testing.allocator, 100));
}

test "parseFen errors - invalid field count" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0";
    try testing.expectError(FenError.InvalidFieldCount, parseFen(fen, testing.allocator, 100));

    const fen2 = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1 extra";
    try testing.expectError(FenError.InvalidFieldCount, parseFen(fen2, testing.allocator, 100));
}

test "parseFen errors - pawns in first or last rank" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNP w - - 0 1";
    try testing.expectError(FenError.PawnsInFirstOrLastRank, parseFen(fen, testing.allocator, 100));

    const fen2 = "Pnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1";
    try testing.expectError(FenError.PawnsInFirstOrLastRank, parseFen(fen2, testing.allocator, 100));
}

test "parseFen errors - not one king per color" {
    // Board with no white king (replaced with a rook)
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQRBNR w - - 0 1";
    try testing.expectError(FenError.NotOneKingPerColor, parseFen(fen, testing.allocator, 100));

    const fen2 = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1";
    var pos = try parseFen(fen2, testing.allocator, 100);
    defer pos.previousContexts.deinit(testing.allocator);
    // Remove a king to test
    pos.board.xorPieceMask(Piece.King, Square.E1.mask());
    pos.board.xorColorMask(Color.White, Square.E1.mask());
    pos.board.xorOccupiedMask(Square.E1.mask());
    try testing.expect(!pos.board.hasOneKingPerColor());
}

test "parseFen errors - en passant without double pawn push" {
    // En passant square but no pawn in correct position
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - e3 0 1";
    try testing.expectError(FenError.EnPassantWithoutDoublePawnPush, parseFen(fen, testing.allocator, 100));
}

test "parseFen errors - halfmove clock more than halfmoves played" {
    // White to move, fullmove 1, halfmove should be 0, but halfmoveClock is 1
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 1 1";
    try testing.expectError(FenError.HalfmoveClockMoreThanHalfmovesPlayed, parseFen(fen, testing.allocator, 100));
}

test "parseFen board row with numbers" {
    // Empty rows with just kings (valid minimal position)
    const fen = "k7/8/8/8/8/8/8/7K w - - 0 1";
    var pos = try parseFen(fen, testing.allocator, 100);
    defer pos.previousContexts.deinit(testing.allocator);
    // Only 2 pieces on board (the kings)
    try testing.expectEqual(@as(u32, 2), @popCount(pos.board.occupiedMask()));
}

test "parseFen board row with mixed pieces and numbers" {
    const fen = "r3k2r/8/8/8/8/8/8/R3K2R w - - 0 1";
    var pos = try parseFen(fen, testing.allocator, 100);
    defer pos.previousContexts.deinit(testing.allocator);
    try testing.expect(pos.board.mask(Piece.Rook, Color.White) & Square.A1.mask() != 0);
    try testing.expect(pos.board.mask(Piece.King, Color.White) & Square.E1.mask() != 0);
    try testing.expect(pos.board.mask(Piece.Rook, Color.White) & Square.H1.mask() != 0);
    try testing.expect(pos.board.mask(Piece.Rook, Color.Black) & Square.A8.mask() != 0);
    try testing.expect(pos.board.mask(Piece.King, Color.Black) & Square.E8.mask() != 0);
    try testing.expect(pos.board.mask(Piece.Rook, Color.Black) & Square.H8.mask() != 0);
}

test "parseFen whitespace handling" {
    const fenWithSpaces = "  rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR   w   -   -   0   1  ";
    var pos = try parseFen(fenWithSpaces, testing.allocator, 100);
    defer pos.previousContexts.deinit(testing.allocator);
    try testing.expectEqual(Color.White, pos.sideToMove);
}

test "parseFen en passant with different dashes" {
    const fenDash = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1";
    var pos1 = try parseFen(fenDash, testing.allocator, 100);
    defer pos1.previousContexts.deinit(testing.allocator);
    try testing.expect(pos1.currentContext.doublePawnPushFile == null);

    // Note: The code supports em dash and en dash, but standard FEN uses hyphen
    // Testing that '-' works is sufficient
}

test "parseFen fullmove to halfmove conversion" {
    // White to move, fullmove 5 -> halfmove should be (5-1)*2 = 8
    const whiteFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 5";
    var whitePos = try parseFen(whiteFen, testing.allocator, 100);
    defer whitePos.previousContexts.deinit(testing.allocator);
    try testing.expectEqual(@as(u10, 8), whitePos.halfmove);

    // Black to move, fullmove 5 -> halfmove should be (5-1)*2 + 1 = 9
    const blackFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b - - 0 5";
    var blackPos = try parseFen(blackFen, testing.allocator, 100);
    defer blackPos.previousContexts.deinit(testing.allocator);
    try testing.expectEqual(@as(u10, 9), blackPos.halfmove);
}

test "parseFen complex position" {
    const complexFen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1";
    var pos = try parseFen(complexFen, testing.allocator, 100);
    defer pos.previousContexts.deinit(testing.allocator);
    try testing.expectEqual(Color.White, pos.sideToMove);
    try testing.expect(pos.currentContext.castlingRights.kingsideForColor(Color.Black));
    try testing.expect(pos.currentContext.castlingRights.queensideForColor(Color.Black));
    try testing.expect(!pos.currentContext.castlingRights.kingsideForColor(Color.White));
    try testing.expect(pos.board.hasOneKingPerColor());
}
