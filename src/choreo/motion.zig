const std = @import("std");
const easing = @import("easing.zig");
const tuning = @import("tuning.zig");

pub const Transform = struct {
    pos_x: f32,
    pos_y: f32,
    pos_z: f32,
    yaw_deg: f32,
    scale: f32,
};

pub const ChoreoProfile = struct {
    carry_base_y: f32 = 0.56,
    carry_arc_y: f32 = 0.10,
    carry_base_z: f32 = 0.14,
    carry_arc_z: f32 = 0.22,
    carry_yaw_gain: f32 = 24.0,
    carry_scale: f32 = 1.12,
    carry_rate: f32 = 1.0,

    borrow_base_y: f32 = 0.44,
    borrow_lift: f32 = 0.16,
    borrow_base_z: f32 = 0.10,
    borrow_drop_z: f32 = 0.10,
    borrow_yaw_gain: f32 = 20.0,
    borrow_scale: f32 = 1.08,
    borrow_lift_ratio: f32 = 0.35,
    borrow_piece_delay: f32 = 0.08,
    borrow_rate: f32 = 1.0,

    shift_base_y: f32 = 0.50,
    shift_base_z: f32 = 0.08,
    shift_max_yaw: f32 = 90.0,
    shift_scale: f32 = 1.04,
    shift_rate: f32 = 1.0,
};

fn profileFromTuning(t: tuning.ProfileTuning) ChoreoProfile {
    return .{
        .carry_base_y = t.carry_base_y,
        .carry_arc_y = t.carry_arc_y,
        .carry_base_z = t.carry_base_z,
        .carry_arc_z = t.carry_arc_z,
        .carry_yaw_gain = t.carry_yaw_gain,
        .carry_scale = t.carry_scale,
        .carry_rate = t.carry_rate,
        .borrow_base_y = t.borrow_base_y,
        .borrow_lift = t.borrow_lift,
        .borrow_base_z = t.borrow_base_z,
        .borrow_drop_z = t.borrow_drop_z,
        .borrow_yaw_gain = t.borrow_yaw_gain,
        .borrow_scale = t.borrow_scale,
        .borrow_lift_ratio = t.borrow_lift_ratio,
        .borrow_piece_delay = t.borrow_piece_delay,
        .borrow_rate = t.borrow_rate,
        .shift_base_y = t.shift_base_y,
        .shift_base_z = t.shift_base_z,
        .shift_max_yaw = t.shift_max_yaw,
        .shift_scale = t.shift_scale,
        .shift_rate = t.shift_rate,
    };
}

pub fn storyboardProfile() ChoreoProfile {
    return profileFromTuning(tuning.storyboard);
}

pub fn cinematicProfile() ChoreoProfile {
    return profileFromTuning(tuning.cinematic);
}

pub fn debugProfile() ChoreoProfile {
    return profileFromTuning(tuning.debug);
}

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
    return calcCarryTransformWithProfile(p, src, dst, storyboardProfile());
}

pub fn calcCarryTransformWithProfile(p: f32, src: u16, dst: u16, profile: ChoreoProfile) Transform {
    const t = clamp01(p);
    const src_x = columnX(src);
    const dst_x = columnX(dst);
    const x = lerp(src_x, dst_x, easing.easeOutCubic(t));

    // Parabolic arc keeps carry motion energetic but deterministic.
    const arc = 4.0 * t * (1.0 - t);

    return .{
        .pos_x = x,
        .pos_y = profile.carry_base_y + arc * profile.carry_arc_y,
        .pos_z = profile.carry_base_z + arc * profile.carry_arc_z,
        .yaw_deg = (dst_x - src_x) * profile.carry_yaw_gain,
        .scale = profile.carry_scale,
    };
}

pub fn calcBorrowTransform(p: f32, src: u16, dst: u16, piece_index: u16) Transform {
    return calcBorrowTransformWithProfile(p, src, dst, piece_index, storyboardProfile());
}

pub fn calcBorrowTransformWithProfile(p: f32, src: u16, dst: u16, piece_index: u16, profile: ChoreoProfile) Transform {
    const t = clamp01(p);
    const src_x = columnX(src);
    const dst_x = columnX(dst);

    // Stagger each borrow piece so decomposition feels heavy and cascading.
    const delay = @as(f32, @floatFromInt(piece_index % 4)) * profile.borrow_piece_delay;
    const local_t = if (t <= delay) 0.0 else clamp01((t - delay) / (1.0 - delay));

    const lift_ratio: f32 = profile.borrow_lift_ratio;
    const y = if (local_t <= lift_ratio)
        (profile.borrow_base_y + easing.easeOutCubic(local_t / lift_ratio) * profile.borrow_lift)
    else
        ((profile.borrow_base_y + profile.borrow_lift) - easing.easeInCubic((local_t - lift_ratio) / (1.0 - lift_ratio)) * profile.borrow_lift);

    const drop_arc = 1.0 - easing.easeInCubic(local_t);

    return .{
        .pos_x = lerp(src_x, dst_x, easing.easeOutCubic(local_t)),
        .pos_y = y,
        .pos_z = profile.borrow_base_z + drop_arc * profile.borrow_drop_z,
        .yaw_deg = (dst_x - src_x) * profile.borrow_yaw_gain,
        .scale = profile.borrow_scale,
    };
}

pub fn calcShiftTransform(p: f32, src: u16, dst: u16) Transform {
    return calcShiftTransformWithProfile(p, src, dst, storyboardProfile());
}

pub fn calcShiftTransformWithProfile(p: f32, src: u16, dst: u16, profile: ChoreoProfile) Transform {
    const t = clamp01(p);
    const src_x = columnX(src);
    const dst_x = columnX(dst);
    const eased = easing.easeInOutSine(t);

    return .{
        .pos_x = lerp(src_x, dst_x, eased),
        .pos_y = profile.shift_base_y,
        .pos_z = profile.shift_base_z,
        .yaw_deg = profile.shift_max_yaw * eased,
        .scale = profile.shift_scale,
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

test "choreo profiles keep deterministic operation identity across modes" {
    const p = 0.5;
    const carry_story = calcCarryTransformWithProfile(p, 1, 3, storyboardProfile());
    const carry_cine = calcCarryTransformWithProfile(p, 1, 3, cinematicProfile());
    const carry_debug = calcCarryTransformWithProfile(p, 1, 3, debugProfile());
    try std.testing.expect(carry_cine.pos_z > carry_story.pos_z);
    try std.testing.expect(carry_story.pos_z > carry_debug.pos_z);

    const shift_story = calcShiftTransformWithProfile(1.0, 1, 2, storyboardProfile());
    const shift_debug = calcShiftTransformWithProfile(1.0, 1, 2, debugProfile());
    try std.testing.expect(shift_story.yaw_deg > shift_debug.yaw_deg);
}
