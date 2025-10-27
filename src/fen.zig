const Piece = @import("./mod.zig").Piece;
const Color = @import("./mod.zig").Color;
const CastlingRights = @import("./mod.zig").CastlingRights;
const Square = @import("./mod.zig").Square;
const Board = @import("./mod.zig").Board;
const Position = @import("./mod.zig").Position;
const PositionContext = @import("./mod.zig").PositionContext;
const Rank = @import("./mod.zig").Rank;
const File = @import("./mod.zig").File;
const splitAny = @import("std").mem.splitAny;
const trim = @import("std").mem.trim;
const ArrayList = @import("std").ArrayList;
const Allocator = @import("std").mem.Allocator;

pub const FenError = error{
    InvalidBoard,
    InvalidSideToMove,
    InvalidCastling,
    InvalidEnPassantSquare,
    InvalidHalfmoveClock,
    InvalidFullmove,
    InvalidFieldCount,
};

fn parseFenBoard(fenBoard: []const u8) !Board {
    var board: Board = Board.blank();
    var rank = Rank.Eight;
    var file = File.A;
    var isRankFilled = false;
    var wasNumber = false;
    for (fenBoard) |char| {
        switch (char) {
            '0'...'9' => {
                const count = char - '0';
                if (isRankFilled or count == 0 or count > 8 or 8 - file.int() < count) {
                    return FenError.InvalidBoard;
                }
            },
            '/' => {
                if (isRankFilled and rank != Rank.Eight) {
                    rank = rank.down() catch unreachable;
                } else {
                    return FenError.InvalidBoard;
                }
            },
            else => {
                if (file == File.H) {
                    return FenError.InvalidBoard;
                }
                const isUpper = char >= 'A';

                const piece = if (isUpper) Piece.fromUppercaseAscii(char) else Piece.fromLowercaseAscii(char);
                if (piece == Piece.Null) {
                    return FenError.InvalidBoard;
                }

                const color = Color.fromIsWhite(isUpper);
                const square = Square.fromRankFile(rank, file) catch unreachable;

                board.togglePieceAt(piece, square);
                board.xorColorMask(color, square.mask());
                board.xorOccupiedMask(square.mask());

                file = file.right() catch blk: {
                    isRankFilled = true;
                    break :blk File.A;
                };
            },
        }
    }
    return board;
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
                else => return FenError.InvalidCastlingRights,
            }
            if (old == res.mask()) {
                return FenError.InvalidCastlingRights;
            }
        }
        return res;
    } else {
        return FenError.InvalidCastlingRights;
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
        return FenError.InvalidEnPassantSquare;
    }
}

fn parseFenHalfmoveClock(fenHalfmoveClock: []const u8) !u7 {
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
}

fn parseFenFullmove(fenFullmove: []const u8) !u9 {
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
}

pub fn parseFen(fen: []const u8, alloc: Allocator, contextsCapacity: usize) !Position {
    const trimmedFen = trim(u8, fen, " ");

    const rawFenParts = splitAny(u8, trimmedFen, " ");

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
    const zobristHash = undefined;
    const doublePawnPushFile = (enPassantSquare orelse null).file();

    const positionContext = PositionContext{
        .pinned = pinned,
        .checkers = checkers,
        .zobristHash = zobristHash,
        .castlingRights = castling,
        .doublePawnPushFile = doublePawnPushFile,
        .halfmoveClock = halfmoveClock,
        .capturedPiece = Piece.Null,
    };

    const gameResult = undefined;

    const pos = Position{
        .board = board,
        .contexts = ArrayList(PositionContext).initCapacity(allocator, contextsCapacity),
        .halfmove = fullmoveToHalfmove(fullmove, turn),
        .gameResult = gameResult,
        .sideToMove = turn,
    };

    try pos.validate();

    return pos;
}
