const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "chmog",
        .root_module = lib_mod,
    });
    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const genZobristMod = b.createModule(.{
        .root_source_file = b.path("bin/generateZobristKeys.zig"),
        .target = target,
        .optimize = optimize,
    });

    const gen_zobrist_exec = b.addExecutable(.{
        .name = "gen-zobrist",
        .root_module = genZobristMod,
    });
    b.installArtifact(gen_zobrist_exec);

    const genZobristStep = b.step("gen-zobrist", "Generate zobrist keys");

    const genZobristRun = b.addRunArtifact(gen_zobrist_exec);

    genZobristStep.dependOn(&genZobristRun.step);

    const genMagicMod = b.createModule(.{
        .root_source_file = b.path("bin/generateMagicLookups.zig"),
        .target = target,
        .optimize = optimize,
    });
    genMagicMod.addImport("chmog", lib_mod);

    const genMagicExec = b.addExecutable(.{
        .name = "gen-magic",
        .root_module = genMagicMod,
    });
    b.installArtifact(genMagicExec);

    const genMagicStep = b.step("gen-magic", "Generate magic lookup tables");

    const genBishopMagicLookupRun = b.addRunArtifact(genMagicExec);
    genBishopMagicLookupRun.addArg("--bishop-only");

    const genRookMagicLookupRun = b.addRunArtifact(genMagicExec);
    genRookMagicLookupRun.addArg("--rook-only");

    genMagicStep.dependOn(&genBishopMagicLookupRun.step);
    genMagicStep.dependOn(&genRookMagicLookupRun.step);
}
