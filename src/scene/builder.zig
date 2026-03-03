const std = @import("std");
const scene_state = @import("scene_state.zig");

pub fn buildSimpleDeterministicScene(allocator: std.mem.Allocator, seed: u64) !scene_state.SceneState {
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    const count: usize = 16;
    const dots = try allocator.alloc(scene_state.Dot, count);
    errdefer allocator.free(dots);

    for (dots, 0..) |*d, i| {
        const base = @as(f32, @floatFromInt(i));
        d.x = base * 0.25;
        d.y = rand.float(f32) * 0.1;
        d.z = rand.float(f32) * 0.1;
    }

    return .{ .dots = dots };
}

test "scene snapshot hash is deterministic by seed" {
    const allocator = std.testing.allocator;

    const a = try buildSimpleDeterministicScene(allocator, 42);
    defer allocator.free(a.dots);

    const b = try buildSimpleDeterministicScene(allocator, 42);
    defer allocator.free(b.dots);

    const c = try buildSimpleDeterministicScene(allocator, 43);
    defer allocator.free(c.dots);

    const ha = scene_state.snapshotHash(a);
    const hb = scene_state.snapshotHash(b);
    const hc = scene_state.snapshotHash(c);

    try std.testing.expectEqual(ha, hb);
    try std.testing.expect(ha != hc);
}
