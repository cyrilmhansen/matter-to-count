const std = @import("std");
const keyframes = @import("tests/keyframes.zig");
const event_snapshot = @import("scene/event_snapshot.zig");
const layout_map = @import("scene/layout_map.zig");
const render_plan = @import("render/render_plan.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);
    const out_path = if (argv.len >= 2) argv[1] else "src/tests/keyframes_baselines.zig";

    var out = try std.ArrayList(u8).initCapacity(allocator, 4096);
    defer out.deinit(allocator);
    const w = out.writer(allocator);

    try w.writeAll("const keyframes = @import(\"keyframes.zig\");\n\n");
    try w.writeAll("// Generated canonical baseline hashes for milestone-2 keyframes.\n");
    try w.writeAll("// Use `zig build rebaseline-keyframes` to refresh intentionally.\n");
    try w.writeAll("pub const baselines = [_]keyframes.BaselineHashes{\n");

    const cfg = layout_map.LayoutConfig{};
    for (keyframes.canonical) |kf| {
        var scene = try keyframes.buildSceneForKeyframe(allocator, kf);
        defer scene.deinit(allocator);

        const semantic = try event_snapshot.snapshotHash(allocator, scene);
        const layout = try layout_map.layoutHash(allocator, scene, cfg);
        var plan = try render_plan.buildPlan(allocator, scene, cfg, .{});
        defer plan.deinit(allocator);
        const plan_hash = render_plan.planHash(plan);

        try w.print("    // {s}\n", .{kf.id});
        try w.print("    .{{ .semantic = 0x{x:0>16}, .layout = 0x{x:0>16}, .plan = 0x{x:0>16} }},\n", .{
            semantic,
            layout,
            plan_hash,
        });
    }
    try w.writeAll("};\n");

    var file = try std.fs.cwd().createFile(out_path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(out.items);
    std.debug.print("REBASELINE_OK file={s} count={d}\n", .{ out_path, keyframes.canonical.len });
}
