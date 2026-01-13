const std = @import("std");
const chmog = @import("chmog");
const Board = chmog.Board;
const Position = chmog.Position;
const Piece = chmog.Piece;
const Color = chmog.Color;
const Square = chmog.Square;
const Rank = chmog.Rank;
const File = chmog.File;
const parseFen = chmog.fen.parseFen;
const clap = @import("clap");

const params = clap.parseParamsComptime(
    \\-h, --help                    Display this help and exit.
    \\    --fen <str>               FEN string to render.
    \\    --fen-file <str>          Path to file containing FEN string.
    \\    --ascii                   Use ASCII characters instead of Unicode.
    \\
);

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    const allocator = da.allocator();
    defer _ = da.deinit();

    var diag = clap.Diagnostic{};

    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        try diag.reportToFile(.stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.helpToFile(.stdout(), clap.Help, &params, .{});
        return;
    }

    const useAscii = res.args.ascii != 0;

    // Get FEN string from either direct input or file
    var fenStringAllocated: ?[]const u8 = null;
    defer if (fenStringAllocated) |s| allocator.free(s);

    const fenString: []const u8 = blk: {
        if (res.args.fen) |fen| {
            break :blk fen;
        } else if (res.args.@"fen-file") |path| {
            const file = std.fs.cwd().openFile(path, .{}) catch |err| {
                std.debug.print("Error opening file '{s}': {}\n", .{ path, err });
                return err;
            };
            defer file.close();

            const contents = file.readToEndAlloc(allocator, 1024) catch |err| {
                std.debug.print("Error reading file '{s}': {}\n", .{ path, err });
                return err;
            };
            fenStringAllocated = contents;
            break :blk contents;
        } else {
            std.debug.print("Error: Either --fen or --fen-file must be provided.\n", .{});
            try clap.helpToFile(.stderr(), clap.Help, &params, .{});
            return error.MissingInput;
        }
    };

    var position = parseFen(fenString, allocator, 0) catch |err| {
        std.debug.print("Error parsing FEN: {}\n", .{err});
        return err;
    };
    defer position.previousContexts.deinit(allocator);

    const stdout = std.fs.File.stdout();
    var buf: [8192]u8 = undefined;
    var writer = stdout.writer(&buf);
    const out = &writer.interface;

    try position.board.render(.{ .useAscii = useAscii }, out);

    try out.print("\nSide to move: {s}\n", .{if (position.sideToMove == Color.White) "White" else "Black"});

    const castling = position.currentContext.castlingRights;
    try out.print("Castling: ", .{});
    if (castling.whiteKingside) try out.print("K", .{});
    if (castling.whiteQueenside) try out.print("Q", .{});
    if (castling.blackKingside) try out.print("k", .{});
    if (castling.blackQueenside) try out.print("q", .{});
    if (castling.mask() == 0) try out.print("-", .{});
    try out.print("\n", .{});

    if (position.currentContext.doublePawnPushFile) |epFile| {
        const epRank: Rank = if (position.sideToMove == Color.White) Rank.Six else Rank.Three;
        const epSquare = Square.fromRankAndFile(epRank, epFile);
        try out.print("En passant: {s}\n", .{&epSquare.name()});
    }

    try out.print("Halfmove clock: {}\n", .{position.currentContext.halfmoveClock});
    try out.print("Fullmove: {}\n", .{(position.halfmove / 2) + 1});

    try writer.end();
}
