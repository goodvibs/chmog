const std = @import("std");
const chmog = @import("chmog");
const Square = chmog.Square;
const Bitboard = chmog.Bitboard;
const PieceMoveDirection = chmog.utils.PieceMoveDirection;
const clap = @import("clap");

const params = clap.parseParamsComptime(
    \\-h, --help                    Display this help and exit.
    \\    --from <str>              Starting square.
    \\    --to <str>                Target square.
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

    const from = res.args.from orelse return error.MissingFrom;
    const to = res.args.to orelse return error.MissingTo;

    if (from.len != 2 or to.len != 2) {
        return error.InvalidSquare;
    }

    const fromSquare = Square.fromName([2]u8{ from[0], from[1] }) catch return error.InvalidSquare;
    const toSquare = Square.fromName([2]u8{ to[0], to[1] }) catch return error.InvalidSquare;

    const direction = PieceMoveDirection.lookup(fromSquare, toSquare);

    if (direction) |d| {
        const isQueenlike = fromSquare.isOnSameLineAs(toSquare);
        if (isQueenlike) {
            const queenlike = d.queenlike;
            std.debug.print("{s}\n", .{@tagName(queenlike)});
        } else {
            const knight = d.knight;
            std.debug.print("{s}\n", .{@tagName(knight)});
        }
    } else {
        std.debug.print("None\n", .{});
    }
}
