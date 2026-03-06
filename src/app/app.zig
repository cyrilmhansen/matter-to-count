const builtin = @import("builtin");
const std = @import("std");
const time = @import("time.zig");
const log = @import("../util/logging.zig");
const d3d11 = @import("../render/d3d11.zig");
const scene_controller = @import("scene_controller.zig");

pub fn run(
    frames: u32,
    loop: bool,
    display_3d: bool,
    width: u32,
    height: u32,
    fullscreen: bool,
    playback_speed: f32,
    screenshot_out: ?[]const u8,
    scene_kind: scene_controller.SceneKind,
    camera_mode: scene_controller.CameraMode,
    render_view: d3d11.RenderView,
    sum_composition_overlay: bool,
    story_demo: bool,
    story_durations: scene_controller.Controller.StoryDurations,
) !void {
    if (builtin.os.tag != .windows) return;
    const win32 = @import("../platform/win32/window.zig");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const window = win32.create(allocator, "Matter to Count - Milestone 3 Preview", width, height, fullscreen) catch |err| {
        log.err("win32.create failed: {}", .{err});
        return err;
    };
    defer win32.destroy(window);

    var renderer = d3d11.Renderer.init(window.hwnd, window.width, window.height) catch |err| {
        log.err("d3d11 init failed: {}", .{err});
        return err;
    };
    defer renderer.deinit();
    const display_3d_status = renderer.setDisplay3DMode(display_3d);
    const stdout = std.fs.File.stdout().deprecatedWriter();
    if (display_3d_status.requested and !display_3d_status.supported) {
        try stdout.print("WARNING: DirectX 3D display mode requested but unsupported on this runtime/GPU.\n", .{});
    }
    try stdout.print(
        "STATUS: display_3d requested={any} enabled={any} supported={any}\n",
        .{ display_3d_status.requested, display_3d_status.enabled, display_3d_status.supported },
    );
    const cycle_s = scene_controller.Controller.cycleSeconds();
    if (!story_demo) {
        const target = scene_controller.Controller.storyboardTarget(scene_kind);
        try stdout.print(
            "STATUS: scene_timing kind={s} cycle_frames={d} cycle_seconds={d:.2} storyboard_target=[{d:.1}, {d:.1}]\n",
            .{ scene_kind.label(), scene_controller.Controller.cycleFrames(), cycle_s, target.min_s, target.max_s },
        );
        if (cycle_s < target.min_s) {
            try stdout.print(
                "WARNING: cycle duration is shorter than storyboard minimum for this scene kind.\n",
                .{},
            );
        }
    }

    const story = scene_controller.Controller.buildStoryProgram(story_durations);
    if (story_demo) {
        try stdout.print(
            "STATUS: story_demo enabled order=ADD->SHIFT->SUB->MUL lengths_s=[{d:.1},{d:.1},{d:.1},{d:.1}] total_s={d:.1}\n",
            .{ story[0].seconds, story[1].seconds, story[2].seconds, story[3].seconds, story[0].seconds + story[1].seconds + story[2].seconds + story[3].seconds },
        );
    }

    var story_index: usize = 0;
    var story_frame_in_scene: u32 = 0;
    var controller = scene_controller.Controller.init(if (story_demo) story[0].kind else scene_kind, camera_mode, sum_composition_overlay, playback_speed);

    var clock = time.FixedClock.init(1.0 / 60.0);
    var fb_width = window.width;
    var fb_height = window.height;
    const trace_anim = std.process.hasEnvVarConstant("MTC_TRACE_ANIM");
    const story_total_frames: u32 = if (story_demo) blk: {
        var total: u32 = 0;
        for (story) |s| total += s.frames;
        break :blk total;
    } else 0;
    const non_loop_frame_budget: u32 = if (story_demo and !loop) story_total_frames else frames;

    var frame: u32 = 0;
    while (loop or frame < non_loop_frame_budget) : (frame +%= 1) {
        if (!win32.pumpMessages()) break;
        if (win32.takePendingResize()) |ev| {
            if (ev.width != fb_width or ev.height != fb_height) {
                fb_width = ev.width;
                fb_height = ev.height;
                renderer.resize(fb_width, fb_height) catch |err| {
                    log.err("d3d11 resize failed ({d}x{d}): {}", .{ fb_width, fb_height, err });
                };
            }
        }
        if (story_demo and story_frame_in_scene >= story[story_index].frames) {
            story_index += 1;
            if (story_index >= story.len) {
                if (!loop) break;
                story_index = 0;
            }
            story_frame_in_scene = 0;
            controller = scene_controller.Controller.init(story[story_index].kind, camera_mode, sum_composition_overlay, playback_speed);
        }
        var frame_data = controller.nextFrame(allocator) catch |err| {
            log.err("scene controller frame build failed: {}", .{err});
            return err;
        };
        defer frame_data.deinit(allocator);
        // Use a non-divisor cadence relative to the 30-frame choreography phase
        // so traces don't alias to phase=0 on every sample.
        if (trace_anim and (frame % 17 == 0)) {
            log.info(
                "anim_trace frame={d} tick={d} phase={d}% transit={d} points={d}",
                .{ frame, frame_data.tick, frame_data.phase_pct, frame_data.transit_count, frame_data.plan.points.len },
            );
        }
        renderer.render(fb_width, fb_height, frame_data.plan, frame_data.legend(), render_view);
        clock.tick();
        if (story_demo) story_frame_in_scene += 1;
    }

    if (screenshot_out) |path| {
        renderer.captureScreenshot(path, fb_width, fb_height) catch |err| {
            log.err("screenshot capture failed ({s}): {}", .{ path, err });
            return err;
        };
    }
}
