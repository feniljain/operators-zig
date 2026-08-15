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

    // ==================================
    // deque.zig

    const deque =  b.createModule(.{
        .root_source_file = b.path("src/deque.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ==================================
    // arrow_utils.zig

    const arrow_utils =  b.createModule(.{
        .root_source_file = b.path("src/arrow_utils.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ==================================
    // dataset.zig

    const dataset =  b.createModule(.{
        .root_source_file = b.path("src/dataset.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ==================================
    // zarrow dep

    const zarrow_dep = b.dependency("zarrow", .{
        .target = target,
        .optimize = optimize,
    });

    const zarrow_mod = zarrow_dep.module("zarrow");

    exe.root_module.addImport("zarrow", zarrow_mod);
    exe.root_module.addImport("arrow_utils", arrow_utils);
    exe.root_module.addImport("dataset", dataset);

    dataset.addImport("zarrow", zarrow_mod);
    dataset.addImport("arrow_utils", arrow_utils);

    arrow_utils.addImport("deque", deque);
    arrow_utils.addImport("zarrow", zarrow_mod);
    arrow_utils.addImport("dataset", dataset);

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
    exe_tests.root_module.addImport("dataset", dataset);

    const dataset_tests = b.addTest(.{
        .root_module = dataset,
    });
    dataset_tests.root_module.addImport("utils", utils);
    dataset_tests.root_module.addImport("zarrow", zarrow_dep.module("zarrow"));

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const run_dataset_tests = b.addRunArtifact(dataset_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_dataset_tests.step);
}
