const std = @import("std");
const easing = @import("easing.zig");

pub const Transform = struct {
    pos_x: f32,
    pos_y: f32,
    pos_z: f32,
    yaw_deg: f32,
    scale: f32,
};

fn clamp01(p: f32) f32 {
    if (p <= 0.0) return 0.0;
    if (p >= 1.0) return 1.0;
    return p;
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

fn columnX(col: u16) f32 {
    return @as(f32, @floatFromInt(col));
}

pub fn calcCarryTransform(p: f32, src: u16, dst: u16) Transform {
    const t = clamp01(p);
    const src_x = columnX(src);
    const dst_x = columnX(dst);
    const x = lerp(src_x, dst_x, easing.easeOutCubic(t));

    // Parabolic arc keeps carry motion energetic but deterministic.
    const arc = 4.0 * t * (1.0 - t);

    return .{
        .pos_x = x,
        .pos_y = 0.56 + arc * 0.10,
        .pos_z = 0.14 + arc * 0.22,
        .yaw_deg = (dst_x - src_x) * 24.0,
        .scale = 1.12,
    };
}

pub fn calcBorrowTransform(p: f32, src: u16, dst: u16, piece_index: u16) Transform {
    const t = clamp01(p);
    const src_x = columnX(src);
    const dst_x = columnX(dst);

    // Stagger each borrow piece so decomposition feels heavy and cascading.
    const delay = @as(f32, @floatFromInt(piece_index % 4)) * 0.08;
    const local_t = if (t <= delay) 0.0 else clamp01((t - delay) / (1.0 - delay));

    const lift_ratio: f32 = 0.35;
    const y = if (local_t <= lift_ratio)
        (0.44 + easing.easeOutCubic(local_t / lift_ratio) * 0.16)
    else
        (0.60 - easing.easeInCubic((local_t - lift_ratio) / (1.0 - lift_ratio)) * 0.16);

    const drop_arc = 1.0 - easing.easeInCubic(local_t);

    return .{
        .pos_x = lerp(src_x, dst_x, easing.easeOutCubic(local_t)),
        .pos_y = y,
        .pos_z = 0.10 + drop_arc * 0.10,
        .yaw_deg = (dst_x - src_x) * 20.0,
        .scale = 1.08,
    };
}

pub fn calcShiftTransform(p: f32, src: u16, dst: u16) Transform {
    const t = clamp01(p);
    const src_x = columnX(src);
    const dst_x = columnX(dst);
    const eased = easing.easeInOutSine(t);

    return .{
        .pos_x = lerp(src_x, dst_x, eased),
        .pos_y = 0.50,
        .pos_z = 0.08,
        .yaw_deg = 90.0 * eased,
        .scale = 1.04,
    };
}

test "carry motion endpoints and arc peak" {
    const start = calcCarryTransform(0.0, 1, 3);
    const mid = calcCarryTransform(0.5, 1, 3);
    const finish = calcCarryTransform(1.0, 1, 3);

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), start.pos_x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), finish.pos_x, 0.0001);
    try std.testing.expect(mid.pos_y > start.pos_y);
    try std.testing.expect(mid.pos_y > finish.pos_y);
}

test "borrow motion lifts before drop and reaches destination" {
    const start = calcBorrowTransform(0.0, 3, 1, 0);
    const mid = calcBorrowTransform(0.5, 3, 1, 0);
    const finish = calcBorrowTransform(1.0, 3, 1, 0);

    try std.testing.expect(mid.pos_y > start.pos_y);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), finish.pos_x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.44), finish.pos_y, 0.001);
}

test "shift motion is horizontal with 90 degree yaw settle" {
    const start = calcShiftTransform(0.0, 2, 3);
    const mid = calcShiftTransform(0.5, 2, 3);
    const finish = calcShiftTransform(1.0, 2, 3);

    try std.testing.expectApproxEqAbs(start.pos_y, mid.pos_y, 0.0001);
    try std.testing.expectApproxEqAbs(mid.pos_y, finish.pos_y, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), finish.pos_x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 90.0), finish.yaw_deg, 0.0001);
}
