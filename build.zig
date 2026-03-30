const builtin = @import("builtin");
const Build = @import("std").Build;
const OptimizeMode = @import("std").builtin.OptimizeMode;

pub const RuntimeSafetyLevel = enum {
    None,
    Light,
    Heavy,

    pub fn fromOptimize(mode: OptimizeMode) RuntimeSafetyLevel {
        return switch (mode) {
            .Debug => .Heavy,
            .ReleaseSafe => .Light,
            .ReleaseFast, .ReleaseSmall => .None,
        };
    }
};

const PerftDepthLevel = enum { Shallow, Deep };

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const perft_depth = b.option(
        PerftDepthLevel,
        "perft-depth",
        "Perft depth tier for tests and bench (Shallow or Deep)",
    ) orelse .Shallow;

    const profileTrace = b.option(
        []const u8,
        "profile-trace",
        "Output path for xctrace Time Profiler .trace (profile step, macOS); default is perft-profile.trace under the install prefix (same as zig-out when using default -p)",
    ) orelse b.pathJoin(&.{ b.install_path, "perft-profile.trace" });
    const profileTimeLimit = b.option(
        []const u8,
        "profile-time-limit",
        "Value for xctrace record --time-limit (profile step, macOS); must exceed perft runtime or xctrace may exit non-zero",
    ) orelse "90s";

    // Base library module - no data dependencies, used by generators
    const baseLibMod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = OptimizeMode.Debug,
    });

    const baseLibOpts = b.addOptions();
    baseLibOpts.addOption(RuntimeSafetyLevel, "level", RuntimeSafetyLevel.fromOptimize(.Debug));
    baseLibMod.addOptions("build_options", baseLibOpts);

    const clapDep = b.lazyDependency("clap", .{}) orelse return;
    const clap = clapDep.module("clap");

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
    fullLibOpts.addOption(RuntimeSafetyLevel, "level", RuntimeSafetyLevel.fromOptimize(optimize));
    fullLibMod.addOptions("build_options", fullLibOpts);

    // Add output files as imports
    fullLibMod.addAnonymousImport("zobristKeys", .{ .root_source_file = zobristFile });
    fullLibMod.addAnonymousImport("bishopMagicAttacksLookup", .{ .root_source_file = bishopFile });
    fullLibMod.addAnonymousImport("rookMagicAttacksLookup", .{ .root_source_file = rookFile });

    const perftCommonMod = b.createModule(.{
        .root_source_file = b.path("perft_common.zig"),
        .target = target,
        .optimize = optimize,
    });
    perftCommonMod.addImport("chmog", fullLibMod);
    const perftOpts = b.addOptions();
    perftOpts.addOption(PerftDepthLevel, "depthLevel", perft_depth);
    perftCommonMod.addOptions("perft_options", perftOpts);

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
    perftTestMod.addImport("perft_common", perftCommonMod);
    const perftTests = b.addTest(.{
        .root_module = perftTestMod,
    });
    const runPerftTests = b.addRunArtifact(perftTests);
    const perftTestStep = b.step("perft-test", "Run perft tests");
    perftTestStep.dependOn(&runPerftTests.step);

    const profileStep = b.step(
        "profile",
        "Record perft tests with xctrace Time Profiler (macOS only). Default trace path is under the install prefix. Prefer -Doptimize=ReleaseFast for release-like profiling.",
    );
    if (builtin.os.tag == .macos) {
        const xctrace = b.addSystemCommand(&.{ "xcrun", "xctrace", "record", "--template", "Time Profiler" });
        xctrace.addArg("--output");
        xctrace.addArg(profileTrace);
        xctrace.addArg("--time-limit");
        xctrace.addArg(profileTimeLimit);
        xctrace.addArg("--launch");
        xctrace.addArg("--");
        xctrace.addArtifactArg(perftTests);
        xctrace.stdio = .inherit;
        xctrace.has_side_effects = true;
        profileStep.dependOn(&xctrace.step);
    } else {
        const failProfile = b.addFail("the profile step is only supported on macOS (requires xcrun xctrace)");
        profileStep.dependOn(&failProfile.step);
    }

    const testStep = b.step("test", "Run all tests");
    testStep.dependOn(unitTestStep);
    testStep.dependOn(perftTestStep);

    const perftBenchMod = b.createModule(.{
        .root_source_file = b.path("benches/perft_bench.zig"),
        .target = target,
        .optimize = OptimizeMode.ReleaseFast,
    });
    perftBenchMod.addImport("chmog", fullLibMod);
    perftBenchMod.addImport("perft_common", perftCommonMod);
    const perftBenchExe = b.addExecutable(.{
        .name = "perft-bench",
        .root_module = perftBenchMod,
    });
    const runPerftBench = b.addRunArtifact(perftBenchExe);
    if (b.args) |args| {
        runPerftBench.addArgs(args);
    }
    const benchStep = b.step("bench", "Run perft benchmarks");
    benchStep.dependOn(&runPerftBench.step);

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
