const builtin = @import("builtin");
const std = @import("std");
const app = @import("app/app.zig");
const time = @import("app/time.zig");
const scene_builder = @import("scene/builder.zig");
const scene_state = @import("scene/scene_state.zig");
const log = @import("util/logging.zig");

const Config = struct {
    smoke: bool = false,
    frames: u32 = 120,
    seed: u64 = 1,
    width: u32 = 1280,
    height: u32 = 720,
    screenshot_out: ?[]u8 = null,
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

    var clock = time.FixedClock.init(1.0 / 60.0);
    const scene = try scene_builder.buildSimpleDeterministicScene(allocator, cfg.seed);
    defer allocator.free(scene.dots);

    if (builtin.os.tag == .windows) {
        try app.run(cfg.frames, cfg.width, cfg.height, cfg.screenshot_out);
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
    _ = @import("scene/builder.zig");
    _ = @import("scene/event_scene.zig");
    _ = @import("math/number.zig");
    _ = @import("math/addition.zig");
    _ = @import("math/subtraction.zig");
    _ = @import("math/shift.zig");
    _ = @import("events/tape.zig");
}
