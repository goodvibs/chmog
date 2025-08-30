const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Base library module - no data dependencies, used by generators
    const baseLibMod = b.createModule(.{
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
    genZobristMod.addImport("chmog", baseLibMod);

    const genZobristExec = b.addExecutable(.{
        .name = "gen-zobrist",
        .root_module = genZobristMod,
    });

    const genZobristRun = b.addRunArtifact(genZobristExec);
    // const zobristFile = genZobristRun.addOutputFileArg("data/zobristKeys.bin");
    const zobristFile = b.path("data/zobristKeys.bin");

    // Magic generation
    const genMagicMod = b.createModule(.{
        .root_source_file = b.path("bin/generateMagicLookups.zig"),
        .target = target,
        .optimize = optimize,
    });
    genMagicMod.addImport("chmog", baseLibMod);

    const genMagicExec = b.addExecutable(.{
        .name = "gen-magic",
        .root_module = genMagicMod,
    });

    const genBishopRun = b.addRunArtifact(genMagicExec);
    genBishopRun.addArg("--bishop-only");
    // const bishopFile = genBishopRun.addPrefixedOutputFileArg("data/bishopMagicAttacksLookup.bin");
    const bishopFile = b.path("data/bishopMagicAttacksLookup.bin");

    const genRookRun = b.addRunArtifact(genMagicExec);
    genRookRun.addArg("--rook-only");
    // const rookFile = genRookRun.addPrefixedOutputFileArg("data/rookMagicAttacksLookup.bin");
    const rookFile = b.path("data/rookMagicAttacksLookup.bin");

    // Full library module - uses generated files
    const fullLibMod = b.createModule(.{
        .root_source_file = b.path("src/mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add output files as imports
    fullLibMod.addAnonymousImport("zobristKeys", .{ .root_source_file = zobristFile });
    fullLibMod.addAnonymousImport("bishopMagicAttacksLookup", .{ .root_source_file = bishopFile });
    fullLibMod.addAnonymousImport("rookMagicAttacksLookup", .{ .root_source_file = rookFile });

    // Library and tests use the full module
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "chmog",
        .root_module = fullLibMod,
    });
    b.installArtifact(lib);

    const libUnitTests = b.addTest(.{
        .root_module = fullLibMod,
    });

    const runLibUnitTests = b.addRunArtifact(libUnitTests);
    const testStep = b.step("test", "Run unit tests");
    testStep.dependOn(&runLibUnitTests.step);

    // Manual generation steps
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
