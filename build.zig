const Build = @import("std").Build;
const OptimizeMode = @import("std").builtin.OptimizeMode;

const runtime_safety_level = @import("src/runtime_safety_level.zig");

const PerftDepthLevel = enum { Shallow, Deep };

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const perft_depth = b.option(PerftDepthLevel, "perft-depth", "Perft test depth (Shallow or Deep)") orelse .Shallow;

    // Base library module - no data dependencies, used by generators
    const baseLibMod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = OptimizeMode.Debug,
    });

    const baseLibOpts = b.addOptions();
    baseLibOpts.addOption(runtime_safety_level.RuntimeSafetyLevel, "level", runtime_safety_level.fromOptimize(.Debug));
    baseLibMod.addOptions("build_options", baseLibOpts);

    const clap_dep = b.lazyDependency("clap", .{}) orelse return;
    const clap = clap_dep.module("clap");

    const binUtils = b.createModule(.{
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
    genZobristMod.addImport("bin_utils", binUtils);

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
    genMagicMod.addImport("bin_utils", binUtils);

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
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const fullLibOpts = b.addOptions();
    fullLibOpts.addOption(runtime_safety_level.RuntimeSafetyLevel, "level", runtime_safety_level.fromOptimize(optimize));
    fullLibMod.addOptions("build_options", fullLibOpts);

    // Add output files as imports
    fullLibMod.addAnonymousImport("zobristKeys", .{ .root_source_file = zobristFile });
    fullLibMod.addAnonymousImport("bishopMagicAttacksLookup", .{ .root_source_file = bishopFile });
    fullLibMod.addAnonymousImport("rookMagicAttacksLookup", .{ .root_source_file = rookFile });

    const perftPositionsMod = b.createModule(.{
        .root_source_file = b.path("perft_positions.zig"),
        .target = target,
        .optimize = optimize,
    });
    perftPositionsMod.addImport("chmog", fullLibMod);

    // Library and tests use the full module
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "chmog",
        .root_module = fullLibMod,
    });
    b.installArtifact(lib);

    const installDocs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docsStep = b.step("docs", "Generate and install HTML docs into zig-out/docs");
    docsStep.dependOn(&installDocs.step);

    const libUnitTests = b.addTest(.{
        .root_module = fullLibMod,
    });

    const runLibUnitTests = b.addRunArtifact(libUnitTests);
    const unitTestStep = b.step("unit-test", "Run unit tests");
    unitTestStep.dependOn(&runLibUnitTests.step);

    const perftTestMod = b.createModule(.{
        .root_source_file = b.path("tests/perft_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    perftTestMod.addImport("chmog", fullLibMod);
    perftTestMod.addImport("perft_positions", perftPositionsMod);
    const perftOpts = b.addOptions();
    perftOpts.addOption(PerftDepthLevel, "depthLevel", perft_depth);
    perftTestMod.addOptions("perft_options", perftOpts);
    const perftTests = b.addTest(.{
        .root_module = perftTestMod,
    });
    const runPerftTests = b.addRunArtifact(perftTests);
    const perftTestStep = b.step("perft-test", "Run perft tests");
    perftTestStep.dependOn(&runPerftTests.step);

    const testStep = b.step("test", "Run all tests");
    testStep.dependOn(unitTestStep);
    testStep.dependOn(perftTestStep);

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

    const renderMod = b.createModule(.{
        .root_source_file = b.path("scripts/render.zig"),
        .target = target,
        .optimize = optimize,
    });
    renderMod.addImport("chmog", fullLibMod);
    renderMod.addImport("clap", clap);
    const renderExec = b.addExecutable(.{
        .name = "render",
        .root_module = renderMod,
    });
    const renderRun = b.addRunArtifact(renderExec);
    if (b.args) |args| {
        renderRun.addArgs(args);
    }
    const renderStep = b.step("render", "Render a chess position from FEN");
    renderStep.dependOn(&renderRun.step);
}
