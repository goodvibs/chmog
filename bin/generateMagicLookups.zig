const std = @import("std");
const chmog = @import("chmog");
const Square = chmog.Square;
const Bitboard = chmog.Bitboard;
const MagicInfo = chmog.attacks.magic.MagicInfo;
const BishopMagicAttacksLookup = chmog.attacks.magic.BishopMagicAttacksLookup;
const RookMagicAttacksLookup = chmog.attacks.magic.RookMagicAttacksLookup;
const manual = chmog.attacks.manual;
const computeBishopRelevantMask = chmog.attacks.magic.computeBishopRelevantMask;
const computeRookRelevantMask = chmog.attacks.magic.computeRookRelevantMask;
const clap = @import("clap");
const writeBinaryData = @import("utils.zig").writeBinaryData;

fn bishopRelevantMask(s: Square) Bitboard {
    return computeBishopRelevantMask([1]Square{s});
}

fn rookRelevantMask(s: Square) Bitboard {
    return computeRookRelevantMask([1]Square{s});
}

const params = clap.parseParamsComptime(
    \\-h, --help                    Display this help and exit.
    \\    --bishop-output <str>     Output file for bishop magic table.
    \\    --rook-output <str>       Output file for rook magic table.
    \\
);

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    const allocator = da.allocator();
    defer _ = da.deinit();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var diag = clap.Diagnostic{};

    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        try diag.reportToFile(.stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.@"bishop-output") |path| {
        const lookup = BishopMagicAttacksLookup.init(bishopRelevantMask, manual.singleBishopAttacks);
        try writeBinaryData(path, lookup);
    }
    if (res.args.@"rook-output") |path| {
        const lookup = RookMagicAttacksLookup.init(rookRelevantMask, manual.singleRookAttacks);
        try writeBinaryData(path, lookup);
    }
}
