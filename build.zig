const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const app_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = "matter-to-count",
        .root_module = app_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const host_app_test_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    const unit_tests = b.addTest(.{ .root_module = host_app_test_mod });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const win64 = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu });
    const win64_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = win64,
        .optimize = optimize,
    });
    const exe_win64 = b.addExecutable(.{
        .name = "matter-to-count-win64",
        .root_module = win64_mod,
    });
    exe_win64.linkLibC();
    exe_win64.linkSystemLibrary("user32");
    exe_win64.linkSystemLibrary("kernel32");
    exe_win64.linkSystemLibrary("d3d11");
    exe_win64.linkSystemLibrary("dxgi");
    exe_win64.linkSystemLibrary("d3dcompiler_47");
    const check_cmd = b.addSystemCommand(&[_][]const u8{"bash", "scripts/check_win_exe.sh"});
    check_cmd.addArtifactArg(exe_win64);
    check_cmd.step.dependOn(&exe_win64.step);
    const check_win64_exe_step = b.step("check-win64-exe", "Build and sanity-check Win64 executable structure/imports");
    check_win64_exe_step.dependOn(&check_cmd.step);

    const install_win64 = b.addInstallArtifact(exe_win64, .{});
    install_win64.step.dependOn(&check_cmd.step);

    const win64_step = b.step("win64", "Build Win64 executable (with mandatory sanity check)");
    win64_step.dependOn(&install_win64.step);

    const smoke_cmd = b.addSystemCommand(&[_][]const u8{"bash", "-lc"});
    smoke_cmd.addArg("SMOKE_EXE=\"$0\" ./scripts/run_windows_smoke.sh");
    smoke_cmd.addArtifactArg(exe_win64);
    smoke_cmd.step.dependOn(&install_win64.step);
    const smoke_step = b.step("smoke-win64", "Build, check, and run Win64 smoke test via Proton/Wine");
    smoke_step.dependOn(&smoke_cmd.step);

    const checker_test_cmd = b.addSystemCommand(&[_][]const u8{"bash", "-lc"});
    checker_test_cmd.addArg("SMOKE_EXE=\"$0\" ./scripts/test_checkerboard_visible.sh");
    checker_test_cmd.addArtifactArg(exe_win64);
    checker_test_cmd.step.dependOn(&install_win64.step);
    const checker_test_step = b.step("test-checkerboard", "Integration test: capture screenshot and verify checkerboard visibility");
    checker_test_step.dependOn(&checker_test_cmd.step);

    const scene_overlay_test_cmd = b.addSystemCommand(&[_][]const u8{"bash", "-lc"});
    scene_overlay_test_cmd.addArg("SMOKE_EXE=\"$0\" ./scripts/test_scene_overlay_visible.sh");
    scene_overlay_test_cmd.addArtifactArg(exe_win64);
    scene_overlay_test_cmd.step.dependOn(&install_win64.step);
    const scene_overlay_test_step = b.step("test-scene-overlay", "Integration test: scene overlay is visible and changes across timesteps");
    scene_overlay_test_step.dependOn(&scene_overlay_test_cmd.step);
}
