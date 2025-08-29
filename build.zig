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

    const gen_magic_mod = b.createModule(.{
        .root_source_file = b.path("bin/generateMagicLookups.zig"),
        .target = target,
        .optimize = optimize,
    });
    gen_magic_mod.addImport("chmog", lib_mod);

    const gen_magic_exec = b.addExecutable(.{
        .name = "gen-magic",
        .root_module = gen_magic_mod,
    });

    const generate_step = b.step("gen-magic", "Generate magic lookup tables");

    const bishop_cmd = b.addRunArtifact(gen_magic_exec);
    bishop_cmd.addArg("bishop");

    const rook_cmd = b.addRunArtifact(gen_magic_exec);
    rook_cmd.addArg("rook");

    generate_step.dependOn(&bishop_cmd.step);
    generate_step.dependOn(&rook_cmd.step);
}
