const Build = @import("std").Build;
const OptimizeMode = @import("std").builtin.OptimizeMode;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Base library module - no data dependencies, used by generators
    const baseLibMod = b.createModule(.{
        .root_source_file = b.path("src/mod.zig"),
        .target = target,
        .optimize = OptimizeMode.Debug,
    });

    const clap = b.dependency("clap", .{});

    // Zobrist generation
    const genZobristMod = b.createModule(.{
        .root_source_file = b.path("bin/generateZobristKeys.zig"),
        .target = target,
        .optimize = OptimizeMode.Debug,
    });
    genZobristMod.addImport("chmog", baseLibMod);
    genZobristMod.addImport("clap", clap.module("clap"));

    const genZobristExec = b.addExecutable(.{
        .name = "gen-zobrist",
        .root_module = genZobristMod,
    });

    const genZobristRun = b.addRunArtifact(genZobristExec);
    genZobristRun.addArg("--algorithm");
    genZobristRun.addArg("xoshiro256");
    genZobristRun.addArg("--seed");
    genZobristRun.addArg("31415");
    genZobristRun.addArg("--output");
    const zobristFile = genZobristRun.addOutputFileArg("zobristKeys.bin");

    // Magic generation
    const genMagicMod = b.createModule(.{
        .root_source_file = b.path("bin/generateMagicLookups.zig"),
        .target = target,
        .optimize = OptimizeMode.Debug,
    });
    genMagicMod.addImport("chmog", baseLibMod);
    genMagicMod.addImport("clap", clap.module("clap"));

    const genMagicExec = b.addExecutable(.{
        .name = "gen-magic",
        .root_module = genMagicMod,
    });

    const genBishopRun = b.addRunArtifact(genMagicExec);
    genBishopRun.addArg("--bishop-output");
    const bishopFile = genBishopRun.addOutputFileArg("bishopMagicAttacksLookup.bin");

    const genRookRun = b.addRunArtifact(genMagicExec);
    genRookRun.addArg("--rook-output");
    const rookFile = genRookRun.addOutputFileArg("rookMagicAttacksLookup.bin");

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

    // Expose generation scripts
    const runZobristStep = b.step("gen-zobrist", "Generate zobrist keys");
    const runZobrist = b.addRunArtifact(genZobristExec);
    if (b.args) |args| {
        runZobrist.addArgs(args);
    }
    runZobristStep.dependOn(&runZobrist.step);

    const runMagicStep = b.step("gen-magic", "Generate magic numbers and attack tables");
    const runMagic = b.addRunArtifact(genMagicExec);
    if (b.args) |args| {
        runMagic.addArgs(args);
    }
    runMagicStep.dependOn(&runMagic.step);

    // Expose other scripts
    const moveDirectionMod = b.createModule(.{
        .root_source_file = b.path("bin/moveDirection.zig"),
        .target = target,
        .optimize = optimize,
    });
    moveDirectionMod.addImport("chmog", fullLibMod);
    moveDirectionMod.addImport("clap", clap.module("clap"));
    const moveDirectionExec = b.addExecutable(.{
        .name = "get-move-direction",
        .root_module = moveDirectionMod,
    });
    const moveDirectionRun = b.addRunArtifact(moveDirectionExec);
    if (b.args) |args| {
        moveDirectionRun.addArgs(args);
    }
    const moveDirectionStep = b.step("get-move-direction", "Get move direction");
    moveDirectionStep.dependOn(&moveDirectionRun.step);
}
