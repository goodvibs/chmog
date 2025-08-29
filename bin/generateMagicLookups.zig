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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <bishop|rook>\n", .{args[0]});
        return std.process.exit(1);
    }

    const piece_type = args[1];

    if (std.mem.eql(u8, piece_type, "bishop")) {
        const lookup = BishopMagicAttacksLookup.init(bishopRelevantMask, manual.singleBishopAttacks);
        try writeBinaryData("bishopMagicInfoLookup.bin", lookup.magicInfoLookup);
    } else if (std.mem.eql(u8, piece_type, "rook")) {
        const lookup = RookMagicAttacksLookup.init(rookRelevantMask, manual.singleRookAttacks);
        try writeBinaryData("rookMagicInfoLookup.bin", lookup.magicInfoLookup);
    } else {
        std.debug.print("Unknown piece type: {s}\n", .{piece_type});
        return std.process.exit(1);
    }
}

fn writeBinaryData(output_path: []const u8, magic_info_lookup: [64]MagicInfo) !void {
    try std.fs.cwd().makePath("data");

    const full_path = try std.fmt.allocPrint(std.heap.page_allocator, "data/{s}", .{output_path});
    defer std.heap.page_allocator.free(full_path);

    var file = try std.fs.cwd().createFile(full_path, .{});
    defer file.close();

    const bytes = std.mem.sliceAsBytes(magic_info_lookup[0..]);
    try file.writeAll(bytes);

    std.debug.print("Generated {} bytes of magic data to {s}\n", .{ bytes.len, full_path });
}
