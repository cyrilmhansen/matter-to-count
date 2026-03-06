const std = @import("std");

fn clamp01(p: f32) f32 {
    if (p <= 0.0) return 0.0;
    if (p >= 1.0) return 1.0;
    return p;
}

pub fn linear(p: f32) f32 {
    return clamp01(p);
}

pub fn easeInCubic(p: f32) f32 {
    const t = clamp01(p);
    return t * t * t;
}

pub fn easeOutCubic(p: f32) f32 {
    const t = clamp01(p);
    const inv = 1.0 - t;
    return 1.0 - inv * inv * inv;
}

pub fn easeInOutSine(p: f32) f32 {
    const t = clamp01(p);
    return (1.0 - @cos(std.math.pi * t)) * 0.5;
}

test "easing functions clamp and hit endpoints" {
    try std.testing.expectEqual(@as(f32, 0.0), linear(-1.0));
    try std.testing.expectEqual(@as(f32, 1.0), linear(5.0));

    try std.testing.expectEqual(@as(f32, 0.0), easeInCubic(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeInCubic(1.0));

    try std.testing.expectEqual(@as(f32, 0.0), easeOutCubic(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeOutCubic(1.0));

    try std.testing.expectApproxEqAbs(@as(f32, 0.5), easeInOutSine(0.5), 0.0001);
}
