const builtin = @import("builtin");
const std = @import("std");
const time = @import("time.zig");
const log = @import("../util/logging.zig");

pub fn run(frames: u32, width: u32, height: u32, screenshot_out: ?[]const u8) !void {
    if (builtin.os.tag != .windows) return;
    const win32 = @import("../platform/win32/window.zig");
    const d3d11 = @import("../render/d3d11.zig");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const window = win32.create(allocator, "Matter to Count - Milestone 1", width, height) catch |err| {
        log.err("win32.create failed: {}", .{err});
        return err;
    };
    defer win32.destroy(window);

    var renderer = d3d11.Renderer.init(window.hwnd, window.width, window.height) catch |err| {
        log.err("d3d11 init failed: {}", .{err});
        return err;
    };
    defer renderer.deinit();

    var clock = time.FixedClock.init(1.0 / 60.0);
    var fb_width = window.width;
    var fb_height = window.height;

    var frame: u32 = 0;
    while (frame < frames) : (frame += 1) {
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
        renderer.render(fb_width, fb_height);
        clock.tick();
    }

    if (screenshot_out) |path| {
        renderer.captureScreenshot(path, fb_width, fb_height) catch |err| {
            log.err("screenshot capture failed ({s}): {}", .{ path, err });
            return err;
        };
    }
}
