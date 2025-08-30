const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Zobrist generation
    const genZobristMod = b.createModule(.{
        .root_source_file = b.path("bin/generateZobristKeys.zig"),
        .target = target,
        .optimize = optimize,
    });

    const gen_zobrist_exec = b.addExecutable(.{
        .name = "gen-zobrist",
        .root_module = genZobristMod,
    });

    const genZobristRun = b.addRunArtifact(gen_zobrist_exec);
    const zobrist_file = genZobristRun.addOutputFileArg("data/zobristKeys.bin");

    // Magic generation - separate steps
    const genMagicMod = b.createModule(.{
        .root_source_file = b.path("bin/generateMagicLookups.zig"),
        .target = target,
        .optimize = optimize,
    });
    genMagicMod.addImport("chmog", lib_mod);

    const gen_magic_exec = b.addExecutable(.{
        .name = "gen-magic",
        .root_module = genMagicMod,
    });

    // Separate bishop and rook generation
    const genBishopRun = b.addRunArtifact(gen_magic_exec);
    genBishopRun.addArg("--bishop-only");
    const bishop_file = genBishopRun.addOutputFileArg("data/bishopMagicAttacksLookup.bin");

    const genRookRun = b.addRunArtifact(gen_magic_exec);
    genRookRun.addArg("--rook-only");
    const rook_file = genRookRun.addOutputFileArg("data/rookMagicAttacksLookup.bin");

    // Add data files as dependencies to the library module
    lib_mod.addAnonymousImport("zobristKeys", .{ .root_source_file = zobrist_file });
    lib_mod.addAnonymousImport("bishopMagicAttacksLookup", .{ .root_source_file = bishop_file });
    lib_mod.addAnonymousImport("rookMagicAttacksLookup", .{ .root_source_file = rook_file });

    // Library depends on data generation
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "chmog",
        .root_module = lib_mod,
    });
    b.installArtifact(lib);

    // Tests depend on data generation
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Manual generation steps (optional)
    const genZobristStep = b.step("gen-zobrist", "Generate zobrist keys");
    genZobristStep.dependOn(&genZobristRun.step);

    const genBishopStep = b.step("gen-bishop", "Generate bishop magic tables");
    genBishopStep.dependOn(&genBishopRun.step);

    const genRookStep = b.step("gen-rook", "Generate rook magic tables");
    genRookStep.dependOn(&genRookRun.step);

    const genMagicStep = b.step("gen-magic", "Generate all magic tables");
    genMagicStep.dependOn(&genBishopRun.step);
    genMagicStep.dependOn(&genRookRun.step);
}
