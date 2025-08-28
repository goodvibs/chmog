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

    if (args.len < 3) {
        std.debug.print("Usage: {s} <bishop|rook> <output_file>\n", .{args[0]});
        return std.process.exit(1);
    }

    const piece_type = args[1];
    const output_path = args[2];

    var file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    const writer = file.writer();

    try writer.print("const std = @import(\"std\");\n\nconst MagicInfo = @import(\"../../mod.zig\").attacks.magic.MagicInfo;\n\n", .{});

    if (std.mem.eql(u8, piece_type, "bishop")) {
        try writer.print("pub const BISHOP_MAGIC_INFO_LOOKUP = ", .{});
        try generate(writer, BishopMagicAttacksLookup, bishopRelevantMask, manual.singleBishopAttacks);
        try writer.print(";", .{});
    } else if (std.mem.eql(u8, piece_type, "rook")) {
        try writer.print("pub const ROOK_MAGIC_INFO_LOOKUP = ", .{});
        try generate(writer, RookMagicAttacksLookup, rookRelevantMask, manual.singleRookAttacks);
        try writer.print(";", .{});
    } else {
        std.debug.print("Unknown piece type: {s}", .{piece_type});
        return std.process.exit(1);
    }
}

fn generate(
    writer: anytype,
    comptime MagicAttacksLookup: type,
    comptime relevantMaskLookup: fn (Square) Bitboard,
    comptime computeAttacks: fn (Square, Bitboard) Bitboard,
) !void {
    const magicInfoLookup = MagicAttacksLookup.init(relevantMaskLookup, computeAttacks).magicInfoLookup;

    try writer.print("[64]MagicInfo{{", .{});
    for (magicInfoLookup) |magicInfo| {
        try writer.print("    .{{ .relevantMask = {}, .magicNumber = {}, .shift = {}, .offset = {} }},", .{
            magicInfo.relevantMask,
            magicInfo.magicNumber,
            magicInfo.shift,
            magicInfo.offset,
        });
    }
    try writer.print("}}", .{});
}
