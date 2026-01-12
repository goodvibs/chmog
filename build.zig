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

    const clap = b.dependency("clap", .{}).module("clap");

    const bin_utils = b.createModule(.{
        .root_source_file = b.path("bin_utils.zig"),
        .target = target,
        .optimize = OptimizeMode.ReleaseFast,
    });

    // Zobrist generation
    const genZobristMod = b.createModule(.{
        .root_source_file = b.path("scripts/generate_zobrist_keys.zig"),
        .target = target,
        .optimize = OptimizeMode.Debug,
    });
    genZobristMod.addImport("chmog", baseLibMod);
    genZobristMod.addImport("clap", clap);
    genZobristMod.addImport("bin_utils", bin_utils);

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
        .root_source_file = b.path("scripts/generate_magic_attacks_lookups.zig"),
        .target = target,
        .optimize = OptimizeMode.Debug,
    });
    genMagicMod.addImport("chmog", baseLibMod);
    genMagicMod.addImport("clap", clap);
    genMagicMod.addImport("bin_utils", bin_utils);

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
        .root_source_file = b.path("scripts/what_move_direction.zig"),
        .target = target,
        .optimize = optimize,
    });
    moveDirectionMod.addImport("chmog", fullLibMod);
    moveDirectionMod.addImport("clap", clap);
    const moveDirectionExec = b.addExecutable(.{
        .name = "what-move-direction",
        .root_module = moveDirectionMod,
    });
    const moveDirectionRun = b.addRunArtifact(moveDirectionExec);
    if (b.args) |args| {
        moveDirectionRun.addArgs(args);
    }
    const moveDirectionStep = b.step("what-move-direction", "Look up move direction");
    moveDirectionStep.dependOn(&moveDirectionRun.step);
}
