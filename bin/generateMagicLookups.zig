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

fn bishopRelevantMask(s: Square) Bitboard {
    return computeBishopRelevantMask([1]Square{s});
}

fn rookRelevantMask(s: Square) Bitboard {
    return computeRookRelevantMask([1]Square{s});
}

const GenerateOptions = struct {
    bishop: bool,
    rook: bool,
};

fn parseArgs(args: [][:0]u8) !GenerateOptions {
    if (args.len == 1) {
        return GenerateOptions{ .bishop = true, .rook = true };
    } else if (args.len == 2) {
        const flag = args[1];
        if (std.mem.eql(u8, flag, "--bishop-only")) {
            return GenerateOptions{ .bishop = true, .rook = false };
        } else if (std.mem.eql(u8, flag, "--rook-only")) {
            return GenerateOptions{ .bishop = false, .rook = true };
        } else {
            return error.InvalidArgument;
        }
    } else {
        return error.TooManyArguments;
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const options = parseArgs(args) catch |err| {
        std.debug.print("Error: {s}\n", .{@errorName(err)});
        std.debug.print("Usage: {s} <Optional[--bishop-only|--rook-only]>\n", .{args[0]});
        return std.process.exit(1);
    };

    if (options.bishop) {
        const lookup = BishopMagicAttacksLookup.init(bishopRelevantMask, manual.singleBishopAttacks);
        try writeBinaryData("bishopMagicInfoLookup.bin", lookup.magicInfoLookup);
    }
    if (options.rook) {
        const lookup = RookMagicAttacksLookup.init(rookRelevantMask, manual.singleRookAttacks);
        try writeBinaryData("rookMagicInfoLookup.bin", lookup.magicInfoLookup);
    }
}

fn writeBinaryData(asFilename: []const u8, magicInfoLookup: [64]MagicInfo) !void {
    try std.fs.cwd().makePath("data");

    const completeRelativePath = try std.fmt.allocPrint(std.heap.page_allocator, "data/{s}", .{asFilename});
    defer std.heap.page_allocator.free(completeRelativePath);

    var file = try std.fs.cwd().createFile(completeRelativePath, .{});
    defer file.close();

    const bytes = std.mem.sliceAsBytes(magicInfoLookup[0..]);
    try file.writeAll(bytes);

    std.debug.print("Generated {} bytes of magic data to {s}\n", .{ bytes.len, completeRelativePath });
}
