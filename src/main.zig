const builtin = @import("builtin");
const std = @import("std");
const app = @import("app/app.zig");
const time = @import("app/time.zig");
const scene_builder = @import("scene/builder.zig");
const scene_state = @import("scene/scene_state.zig");
const log = @import("util/logging.zig");
const scene_controller = @import("app/scene_controller.zig");

const Config = struct {
    smoke: bool = false,
    loop: bool = false,
    display_3d: bool = false,
    frames: u32 = 120,
    seed: u64 = 1,
    width: u32 = 1280,
    height: u32 = 720,
    screenshot_out: ?[]u8 = null,
    scene_kind: scene_controller.SceneKind = .add,
    camera_mode: scene_controller.CameraMode = .storyboard,
    render_view: @import("render/d3d11.zig").RenderView = .beauty,
};

fn parseArgs(allocator: std.mem.Allocator) !Config {
    var cfg = Config{};
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const arg = argv[i];
        if (std.mem.eql(u8, arg, "--smoke")) {
            cfg.smoke = true;
        } else if (std.mem.eql(u8, arg, "--loop")) {
            cfg.loop = true;
        } else if (std.mem.eql(u8, arg, "--display-3d")) {
            cfg.display_3d = true;
        } else if (std.mem.eql(u8, arg, "--frames")) {
            i += 1;
            if (i >= argv.len) return error.InvalidArguments;
            cfg.frames = try std.fmt.parseInt(u32, argv[i], 10);
        } else if (std.mem.eql(u8, arg, "--seed")) {
            i += 1;
            if (i >= argv.len) return error.InvalidArguments;
            cfg.seed = try std.fmt.parseInt(u64, argv[i], 10);
        } else if (std.mem.eql(u8, arg, "--width")) {
            i += 1;
            if (i >= argv.len) return error.InvalidArguments;
            cfg.width = try std.fmt.parseInt(u32, argv[i], 10);
        } else if (std.mem.eql(u8, arg, "--height")) {
            i += 1;
            if (i >= argv.len) return error.InvalidArguments;
            cfg.height = try std.fmt.parseInt(u32, argv[i], 10);
        } else if (std.mem.eql(u8, arg, "--screenshot-out")) {
            i += 1;
            if (i >= argv.len) return error.InvalidArguments;
            cfg.screenshot_out = try allocator.dupe(u8, argv[i]);
        } else if (std.mem.eql(u8, arg, "--scene")) {
            i += 1;
            if (i >= argv.len) return error.InvalidArguments;
            if (scene_controller.SceneKind.parse(argv[i])) |kind| {
                cfg.scene_kind = kind;
            } else {
                return error.InvalidArguments;
            }
        } else if (std.mem.eql(u8, arg, "--camera")) {
            i += 1;
            if (i >= argv.len) return error.InvalidArguments;
            if (scene_controller.parseCameraMode(argv[i])) |mode| {
                cfg.camera_mode = mode;
            } else {
                return error.InvalidArguments;
            }
        } else if (std.mem.eql(u8, arg, "--view")) {
            i += 1;
            if (i >= argv.len) return error.InvalidArguments;
            if (std.mem.eql(u8, argv[i], "beauty")) {
                cfg.render_view = .beauty;
            } else if (std.mem.eql(u8, argv[i], "depth")) {
                cfg.render_view = .depth;
            } else if (std.mem.eql(u8, argv[i], "role-id")) {
                cfg.render_view = .role_id;
            } else {
                return error.InvalidArguments;
            }
        }
    }
    return cfg;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cfg = try parseArgs(allocator);
    defer if (cfg.screenshot_out) |p| allocator.free(p);
    const should_loop = cfg.loop and !cfg.smoke;

    var clock = time.FixedClock.init(1.0 / 60.0);
    const scene = try scene_builder.buildSimpleDeterministicScene(allocator, cfg.seed);
    defer allocator.free(scene.dots);

    if (builtin.os.tag == .windows) {
        try app.run(cfg.frames, should_loop, cfg.display_3d, cfg.width, cfg.height, cfg.screenshot_out, cfg.scene_kind, cfg.camera_mode, cfg.render_view);
    }

    var frame: u32 = 0;
    while (frame < cfg.frames) : (frame += 1) {
        clock.tick();
    }

    const hash = scene_state.snapshotHash(scene);
    log.info("run_complete frames={d} seed={d} sim_time={d:.3} snapshot_hash={x}", .{ cfg.frames, cfg.seed, clock.sim_time, hash });

    if (cfg.smoke) {
        log.info("SMOKE_OK frames={d} seed={d}", .{ cfg.frames, cfg.seed });
    }
}

test {
    _ = @import("app/time.zig");
    _ = @import("app/scene_controller.zig");
    _ = @import("scene/builder.zig");
    _ = @import("scene/event_scene.zig");
    _ = @import("scene/event_snapshot.zig");
    _ = @import("scene/layout_map.zig");
    _ = @import("render/render_plan.zig");
    _ = @import("math/number.zig");
    _ = @import("math/addition.zig");
    _ = @import("math/subtraction.zig");
    _ = @import("math/shift.zig");
    _ = @import("math/multiplication.zig");
    _ = @import("events/tape.zig");
    _ = @import("choreo/easing.zig");
    _ = @import("choreo/motion.zig");
    _ = @import("platform/win32/win_types.zig");
    _ = @import("platform/win32/d3d11_core_manual.zig");
    _ = @import("platform/win32/d3d11_interfaces_manual.zig");
    _ = @import("platform/win32/d3d11_manual.zig");
    _ = @import("platform/win32/d3dcompiler_manual.zig");
    _ = @import("platform/win32/dxgi_manual.zig");
    _ = @import("platform/win32/dxgi_interfaces_manual.zig");
    _ = @import("platform/win32/com_iids.zig");
}
