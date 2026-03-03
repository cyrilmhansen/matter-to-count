const std = @import("std");
const number = @import("../math/number.zig");
const addition = @import("../math/addition.zig");
const subtraction = @import("../math/subtraction.zig");
const shift = @import("../math/shift.zig");
const fixtures = @import("../tests/fixtures.zig");
const keyframes = @import("../tests/keyframes.zig");
const es = @import("../scene/event_scene.zig");
const layout = @import("../scene/layout_map.zig");

pub const DrawRole = enum(u8) {
    source_digit = 0,
    result_digit = 1,
    carry_packet = 2,
    borrow_packet = 3,
    shift_packet = 4,
    active_marker = 5,
};

pub const DrawPoint = struct {
    role: DrawRole,
    x: f32,
    y: f32,
    z: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const RenderPlan = struct {
    points: []DrawPoint,

    pub fn deinit(self: RenderPlan, allocator: std.mem.Allocator) void {
        allocator.free(self.points);
    }
};

fn roleFromEntity(role: es.EntityRole) DrawRole {
    return switch (role) {
        .source_digit => .source_digit,
        .result_digit => .result_digit,
        .carry_packet => .carry_packet,
        .borrow_packet => .borrow_packet,
        .shift_packet => .shift_packet,
    };
}

fn applySemanticColor(p: *DrawPoint, role: DrawRole, emissive: es.EmissiveClass) void {
    const base = switch (role) {
        .source_digit => [4]f32{ 0.20, 0.75, 1.00, 1.00 },
        .result_digit => [4]f32{ 0.25, 1.00, 0.55, 1.00 },
        .carry_packet => [4]f32{ 1.00, 0.35, 0.20, 1.00 },
        .borrow_packet => [4]f32{ 1.00, 0.80, 0.20, 1.00 },
        .shift_packet => [4]f32{ 0.70, 0.30, 1.00, 1.00 },
        .active_marker => [4]f32{ 1.00, 1.00, 0.35, 1.00 },
    };

    var boost: f32 = 1.0;
    if (emissive == .active) boost = 1.15;
    if (emissive == .highlight) boost = 1.30;

    p.r = @min(1.0, base[0] * boost);
    p.g = @min(1.0, base[1] * boost);
    p.b = @min(1.0, base[2] * boost);
    p.a = base[3];
}

pub fn buildPlan(
    allocator: std.mem.Allocator,
    arithmetic: es.ArithmeticSceneState,
    cfg: layout.LayoutConfig,
) !RenderPlan {
    const mapped = try layout.mapArithmeticToDots(allocator, arithmetic, cfg);
    defer allocator.free(mapped.dots);

    const points = try allocator.alloc(DrawPoint, mapped.dots.len);
    errdefer allocator.free(points);

    var i: usize = 0;
    while (i < arithmetic.entities.len) : (i += 1) {
        const e = arithmetic.entities[i];
        const d = mapped.dots[i];
        points[i] = .{
            .role = roleFromEntity(e.role),
            .x = d.x,
            .y = d.y,
            .z = d.z,
            .r = 0.0,
            .g = 0.0,
            .b = 0.0,
            .a = 1.0,
        };
        applySemanticColor(&points[i], points[i].role, e.emissive);
    }

    while (i < mapped.dots.len) : (i += 1) {
        const d = mapped.dots[i];
        points[i] = .{
            .role = .active_marker,
            .x = d.x,
            .y = d.y,
            .z = d.z,
            .r = 1.0,
            .g = 1.0,
            .b = 0.35,
            .a = 1.0,
        };
    }

    return .{ .points = points };
}

fn quantize(v: f32) i32 {
    return @as(i32, @intFromFloat(std.math.round(v * 1000.0)));
}

pub fn planHash(plan: RenderPlan) u64 {
    var h = std.hash.Wyhash.init(0);
    for (plan.points) |p| {
        h.update(std.mem.asBytes(&@intFromEnum(p.role)));
        const qx = quantize(p.x);
        const qy = quantize(p.y);
        const qz = quantize(p.z);
        const qr = quantize(p.r);
        const qg = quantize(p.g);
        const qb = quantize(p.b);
        const qa = quantize(p.a);
        h.update(std.mem.asBytes(&qx));
        h.update(std.mem.asBytes(&qy));
        h.update(std.mem.asBytes(&qz));
        h.update(std.mem.asBytes(&qr));
        h.update(std.mem.asBytes(&qg));
        h.update(std.mem.asBytes(&qb));
        h.update(std.mem.asBytes(&qa));
    }
    return h.final();
}

fn isFinitePoint(p: DrawPoint) bool {
    return std.math.isFinite(p.x) and
        std.math.isFinite(p.y) and
        std.math.isFinite(p.z) and
        std.math.isFinite(p.r) and
        std.math.isFinite(p.g) and
        std.math.isFinite(p.b) and
        std.math.isFinite(p.a);
}

fn addSceneAt(allocator: std.mem.Allocator, fx: fixtures.Fixture, sample: es.TimeSample) !es.ArithmeticSceneState {
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try addition.addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);
    return es.buildSceneAtTime(allocator, res.tape, sample);
}

fn subSceneAt(allocator: std.mem.Allocator, fx: fixtures.Fixture, sample: es.TimeSample) !es.ArithmeticSceneState {
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try subtraction.subWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);
    return es.buildSceneAtTime(allocator, res.tape, sample);
}

fn shiftSceneAt(allocator: std.mem.Allocator, fx: fixtures.Fixture, sample: es.TimeSample) !es.ArithmeticSceneState {
    var input = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer input.deinit(allocator);
    var res = try shift.multiplyByBaseWithEvents(allocator, input);
    defer res.deinit(allocator);
    return es.buildSceneAtTime(allocator, res.tape, sample);
}

fn countRole(plan: RenderPlan, role: DrawRole) usize {
    var n: usize = 0;
    for (plan.points) |p| {
        if (p.role == role) n += 1;
    }
    return n;
}

test "render plan invariants for add mid-carry keyframe" {
    const allocator = std.testing.allocator;
    var scene = try addSceneAt(allocator, fixtures.add_decimal_single_carry, .{ .tick = 0, .phase = 0.5 });
    defer scene.deinit(allocator);

    const cfg = layout.LayoutConfig{};
    var plan = try buildPlan(allocator, scene, cfg);
    defer plan.deinit(allocator);

    try std.testing.expectEqual(scene.entities.len + scene.active_columns.len, plan.points.len);
    try std.testing.expectEqual(@as(usize, 1), countRole(plan, .carry_packet));
    try std.testing.expectEqual(scene.active_columns.len, countRole(plan, .active_marker));

    for (plan.points) |p| {
        try std.testing.expect(isFinitePoint(p));
        try std.testing.expect(p.r >= 0.0 and p.r <= 1.0);
        try std.testing.expect(p.g >= 0.0 and p.g <= 1.0);
        try std.testing.expect(p.b >= 0.0 and p.b <= 1.0);
        try std.testing.expect(p.a > 0.0 and p.a <= 1.0);
    }
}

test "render plan deterministic baselines for keyframes" {
    const allocator = std.testing.allocator;
    const cfg = layout.LayoutConfig{};
    for (keyframes.canonical, 0..) |kf, i| {
        var scene = try keyframes.buildSceneForKeyframe(allocator, kf);
        defer scene.deinit(allocator);
        var plan = try buildPlan(allocator, scene, cfg);
        defer plan.deinit(allocator);
        try std.testing.expectEqual(keyframes.baselines[i].plan, planHash(plan));
    }
}

test "render plan hash changes across phase" {
    const allocator = std.testing.allocator;
    const cfg = layout.LayoutConfig{};
    const fx = fixtures.add_decimal_single_carry;

    var early = try addSceneAt(allocator, fx, .{ .tick = 0, .phase = 0.2 });
    defer early.deinit(allocator);
    var late = try addSceneAt(allocator, fx, .{ .tick = 0, .phase = 0.8 });
    defer late.deinit(allocator);

    var p_early = try buildPlan(allocator, early, cfg);
    defer p_early.deinit(allocator);
    var p_late = try buildPlan(allocator, late, cfg);
    defer p_late.deinit(allocator);

    try std.testing.expect(planHash(p_early) != planHash(p_late));
}
