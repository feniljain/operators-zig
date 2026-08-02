const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "joins",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // ==================================
    // utils.zig

    const utils =  b.createModule(.{
        .root_source_file = b.path("src/utils.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("utils", utils);

    // ==================================
    // benchmark.zig

    const benchmark =  b.createModule(.{
        .root_source_file = b.path("src/benchmark.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("benchmark", benchmark);
    benchmark.addImport("utils", utils);

    // ==================================
    // zarrow dep

    const zarrow_dep = b.dependency("zarrow", .{
        .target = target,
        .optimize = optimize,
    });

    const zarrow_mod = zarrow_dep.module("zarrow");
    exe.root_module.addImport("zarrow", zarrow_mod);
    benchmark.addImport("zarrow", zarrow_mod);
    utils.addImport("zarrow", zarrow_mod);

    // ==================================

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    exe_tests.root_module.addImport("zarrow", zarrow_dep.module("zarrow"));
    exe_tests.root_module.addImport("benchmark", benchmark);

    const benchmark_tests = b.addTest(.{
        .root_module = benchmark,
    });
    benchmark_tests.root_module.addImport("utils", utils);
    benchmark_tests.root_module.addImport("zarrow", zarrow_dep.module("zarrow"));

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const run_benchmark_tests = b.addRunArtifact(benchmark_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_benchmark_tests.step);
}
