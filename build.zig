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

    const generate_mod = b.createModule(.{
        .root_source_file = b.path("bin/generateMagicLookups.zig"),
        .target = target,
        .optimize = optimize,
    });
    generate_mod.addImport("chmog", lib_mod);

    const generate_exe = b.addExecutable(.{
        .name = "generate-magic-lookups",
        .root_module = generate_mod,
    });

    const generate_step = b.step("generate", "Generate magic lookup tables");

    const bishop_cmd = b.addRunArtifact(generate_exe);
    bishop_cmd.addArgs(&[_][]const u8{ "bishop", "src/attacks/generated/bishopMagicInfoLookup.zig" });

    const rook_cmd = b.addRunArtifact(generate_exe);
    rook_cmd.addArgs(&[_][]const u8{ "rook", "src/attacks/generated/rookMagicInfoLookup.zig" });

    generate_step.dependOn(&bishop_cmd.step);
    generate_step.dependOn(&rook_cmd.step);
}
