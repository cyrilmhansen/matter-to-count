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
    operand_primary_digit = 0,
    operand_secondary_digit = 1,
    result_digit = 2,
    carry_packet = 3,
    borrow_packet = 4,
    shift_packet = 5,
    partial_row_marker = 6,
    active_marker = 7,
    base_bundle_token = 8,
};

pub const DrawPoint = struct {
    role: DrawRole,
    x: f32,
    y: f32,
    z: f32,
    scale: f32,
    yaw_deg: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const RenderPlan = struct {
    points: []DrawPoint,
    camera: es.CameraState,

    pub fn deinit(self: RenderPlan, allocator: std.mem.Allocator) void {
        allocator.free(self.points);
    }
};

pub const BuildOptions = struct {
    sum_composition_overlay: bool = false,
};

fn roleFromEntity(role: es.EntityRole) DrawRole {
    return switch (role) {
        .operand_primary_digit => .operand_primary_digit,
        .operand_secondary_digit => .operand_secondary_digit,
        .result_digit => .result_digit,
        .carry_packet => .carry_packet,
        .borrow_packet => .borrow_packet,
        .shift_packet => .shift_packet,
        .partial_row_marker => .partial_row_marker,
    };
}

fn applySemanticColor(p: *DrawPoint, role: DrawRole, emissive: es.EmissiveClass) void {
    const base = switch (role) {
        .operand_primary_digit => [4]f32{ 0.20, 0.75, 1.00, 1.00 },
        .operand_secondary_digit => [4]f32{ 0.35, 0.55, 1.00, 1.00 },
        .result_digit => [4]f32{ 0.25, 1.00, 0.55, 1.00 },
        .carry_packet => [4]f32{ 1.00, 0.35, 0.20, 1.00 },
        .borrow_packet => [4]f32{ 1.00, 0.80, 0.20, 1.00 },
        .shift_packet => [4]f32{ 0.70, 0.30, 1.00, 1.00 },
        .partial_row_marker => [4]f32{ 1.00, 0.60, 0.90, 1.00 },
        .active_marker => [4]f32{ 1.00, 1.00, 0.35, 1.00 },
        .base_bundle_token => [4]f32{ 0.95, 0.92, 0.80, 1.00 },
    };

    var boost: f32 = 1.0;
    if (emissive == .active) boost = 1.15;
    if (emissive == .highlight) boost = 1.30;

    p.r = @min(1.0, base[0] * boost);
    p.g = @min(1.0, base[1] * boost);
    p.b = @min(1.0, base[2] * boost);
    p.a = base[3];
}

const visual_bundle_size: u16 = 10;

fn isDigitRole(role: DrawRole) bool {
    return switch (role) {
        .operand_primary_digit, .operand_secondary_digit, .result_digit => true,
        else => false,
    };
}

fn appendQuantityTokens(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(DrawPoint),
    base_point: DrawPoint,
    value: u16,
) !void {
    const bundles: u16 = value / visual_bundle_size;
    const units: u16 = value % visual_bundle_size;

    var b: u16 = 0;
    while (b < bundles) : (b += 1) {
        var token = DrawPoint{
            .role = .base_bundle_token,
            .x = base_point.x - 0.09 + @as(f32, @floatFromInt(b % 3)) * 0.03,
            .y = base_point.y + 0.10 + @as(f32, @floatFromInt(b / 3)) * 0.05,
            .z = base_point.z + 0.012,
            .scale = base_point.scale * 0.45,
            .yaw_deg = 0.0,
            .r = 0.0,
            .g = 0.0,
            .b = 0.0,
            .a = 1.0,
        };
        applySemanticColor(&token, token.role, .idle);
        try out.append(allocator, token);
    }

    var u: u16 = 0;
    while (u < units) : (u += 1) {
        const col = u % 5;
        const row = u / 5;
        const token = DrawPoint{
            .role = base_point.role,
            .x = base_point.x - 0.06 + @as(f32, @floatFromInt(col)) * 0.03,
            .y = base_point.y + 0.03 - @as(f32, @floatFromInt(row)) * 0.05,
            .z = base_point.z + 0.010,
            .scale = base_point.scale * 0.38,
            .yaw_deg = 0.0,
            .r = base_point.r,
            .g = base_point.g,
            .b = base_point.b,
            .a = 0.95,
        };
        try out.append(allocator, token);
    }
}

const ColumnOverlay = struct {
    has_primary: bool = false,
    primary: DrawPoint = undefined,
    has_secondary: bool = false,
    secondary: DrawPoint = undefined,
    has_result: bool = false,
    result: DrawPoint = undefined,
    is_active: bool = false,
};

fn appendSumCompositionOverlay(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(DrawPoint),
    arithmetic: es.ArithmeticSceneState,
    mapped: @import("../scene/scene_state.zig").SceneState,
) !void {
    var max_col: u16 = 0;
    for (arithmetic.entities) |e| {
        max_col = @max(max_col, e.column);
    }
    for (arithmetic.active_columns) |c| {
        max_col = @max(max_col, c);
    }
    const col_count: usize = @as(usize, max_col) + 1;
    const cols = try allocator.alloc(ColumnOverlay, col_count);
    defer allocator.free(cols);
    @memset(cols, .{});

    for (arithmetic.active_columns) |c| {
        cols[c].is_active = true;
    }

    var i: usize = 0;
    while (i < arithmetic.entities.len) : (i += 1) {
        const e = arithmetic.entities[i];
        if (!e.visible or e.in_transit) continue;
        const role = roleFromEntity(e.role);
        const anchor = DrawPoint{
            .role = role,
            .x = mapped.dots[i].x,
            .y = mapped.dots[i].y,
            .z = mapped.dots[i].z,
            .scale = e.scale,
            .yaw_deg = e.yaw_deg,
            .r = 0.0,
            .g = 0.0,
            .b = 0.0,
            .a = 1.0,
        };
        switch (role) {
            .operand_primary_digit => {
                cols[e.column].has_primary = true;
                cols[e.column].primary = anchor;
            },
            .operand_secondary_digit => {
                cols[e.column].has_secondary = true;
                cols[e.column].secondary = anchor;
            },
            .result_digit => {
                cols[e.column].has_result = true;
                cols[e.column].result = anchor;
            },
            else => {},
        }
    }

    var col: usize = 0;
    while (col < col_count) : (col += 1) {
        const c = cols[col];
        if (!c.is_active or !c.has_primary or !c.has_secondary) continue;

        var p_a = c.primary;
        applySemanticColor(&p_a, .operand_primary_digit, .highlight);
        p_a.scale *= 0.22;
        p_a.z += 0.05;
        p_a.a = 1.0;
        try out.append(allocator, p_a);

        var s_a = c.secondary;
        applySemanticColor(&s_a, .operand_secondary_digit, .highlight);
        s_a.scale *= 0.22;
        s_a.z += 0.05;
        s_a.a = 1.0;
        try out.append(allocator, s_a);

        const result_y = if (c.has_result) c.result.y else (c.secondary.y + (c.secondary.y - c.primary.y));
        var r_a = DrawPoint{
            .role = .result_digit,
            .x = c.primary.x,
            .y = result_y,
            .z = c.primary.z + 0.05,
            .scale = c.primary.scale * 0.22,
            .yaw_deg = 0.0,
            .r = 0.0,
            .g = 0.0,
            .b = 0.0,
            .a = 1.0,
        };
        applySemanticColor(&r_a, .result_digit, .highlight);
        try out.append(allocator, r_a);

        const plus_y = (c.primary.y + c.secondary.y) * 0.5;
        const arrow_y = (c.secondary.y + result_y) * 0.5;
        var plus = DrawPoint{
            .role = .base_bundle_token,
            .x = c.primary.x,
            .y = plus_y,
            .z = c.primary.z + 0.055,
            .scale = 0.20,
            .yaw_deg = 0.0,
            .r = 1.0,
            .g = 1.0,
            .b = 1.0,
            .a = 0.95,
        };
        applySemanticColor(&plus, .base_bundle_token, .highlight);
        try out.append(allocator, plus);

        var arrow = DrawPoint{
            .role = .base_bundle_token,
            .x = c.primary.x,
            .y = arrow_y,
            .z = c.primary.z + 0.055,
            .scale = 0.17,
            .yaw_deg = 90.0,
            .r = 1.0,
            .g = 1.0,
            .b = 1.0,
            .a = 0.95,
        };
        applySemanticColor(&arrow, .base_bundle_token, .highlight);
        try out.append(allocator, arrow);
    }
}

pub fn buildPlan(
    allocator: std.mem.Allocator,
    arithmetic: es.ArithmeticSceneState,
    cfg: layout.LayoutConfig,
    opts: BuildOptions,
) !RenderPlan {
    const mapped = try layout.mapArithmeticToDots(allocator, arithmetic, cfg);
    defer allocator.free(mapped.dots);

    var points_list = try std.ArrayList(DrawPoint).initCapacity(allocator, mapped.dots.len * 4);
    defer points_list.deinit(allocator);
    var token_points = try std.ArrayList(DrawPoint).initCapacity(allocator, mapped.dots.len * 3);
    defer token_points.deinit(allocator);

    var i: usize = 0;
    while (i < arithmetic.entities.len) : (i += 1) {
        const e = arithmetic.entities[i];
        const d = mapped.dots[i];
        var p = DrawPoint{
            .role = roleFromEntity(e.role),
            .x = d.x,
            .y = d.y,
            .z = d.z,
            .scale = e.scale,
            .yaw_deg = e.yaw_deg,
            .r = 0.0,
            .g = 0.0,
            .b = 0.0,
            .a = 1.0,
        };
        applySemanticColor(&p, p.role, e.emissive);
        try points_list.append(allocator, p);

        if (opts.sum_composition_overlay and !e.in_transit and isDigitRole(p.role) and e.value > 0) {
            // Keep quantity tokens in a secondary stream so core motion entities
            // are always prioritized if the renderer hits its instance cap.
            try appendQuantityTokens(allocator, &token_points, p, e.value);
        }
    }

    while (i < mapped.dots.len) : (i += 1) {
        const d = mapped.dots[i];
        try points_list.append(allocator, .{
            .role = .active_marker,
            .x = d.x,
            .y = d.y,
            .z = d.z,
            .scale = 1.0,
            .yaw_deg = 0.0,
            .r = 1.0,
            .g = 1.0,
            .b = 0.35,
            .a = 1.0,
        });
    }

    if (opts.sum_composition_overlay) {
        var has_transit = false;
        for (arithmetic.entities) |e| {
            if (e.visible and e.in_transit) {
                has_transit = true;
                break;
            }
        }
        if (has_transit) {
            try appendSumCompositionOverlay(allocator, &points_list, arithmetic, mapped);
        }
    }

    if (token_points.items.len > 0) {
        try points_list.appendSlice(allocator, token_points.items);
    }

    return .{ .points = try points_list.toOwnedSlice(allocator), .camera = arithmetic.camera };
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
        const qs = quantize(p.scale);
        const qyaw = quantize(p.yaw_deg);
        h.update(std.mem.asBytes(&qx));
        h.update(std.mem.asBytes(&qy));
        h.update(std.mem.asBytes(&qz));
        h.update(std.mem.asBytes(&qr));
        h.update(std.mem.asBytes(&qg));
        h.update(std.mem.asBytes(&qb));
        h.update(std.mem.asBytes(&qa));
        h.update(std.mem.asBytes(&qs));
        h.update(std.mem.asBytes(&qyaw));
    }
    const cy = quantize(plan.camera.yaw_deg);
    const cp = quantize(plan.camera.pitch_deg);
    const ck = quantize(plan.camera.perspective);
    h.update(std.mem.asBytes(&cy));
    h.update(std.mem.asBytes(&cp));
    h.update(std.mem.asBytes(&ck));
    return h.final();
}

fn isFinitePoint(p: DrawPoint) bool {
    return std.math.isFinite(p.x) and
        std.math.isFinite(p.y) and
        std.math.isFinite(p.z) and
        std.math.isFinite(p.scale) and
        std.math.isFinite(p.yaw_deg) and
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
    var plan = try buildPlan(allocator, scene, cfg, .{});
    defer plan.deinit(allocator);

    try std.testing.expect(plan.points.len >= scene.entities.len + scene.active_columns.len);
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

test "render plan exposes both operand roles for decimal addition" {
    const allocator = std.testing.allocator;
    var scene = try addSceneAt(allocator, fixtures.add_decimal_single_carry, .{ .tick = 0, .phase = 0.0 });
    defer scene.deinit(allocator);

    const cfg = layout.LayoutConfig{};
    var plan = try buildPlan(allocator, scene, cfg, .{});
    defer plan.deinit(allocator);

    try std.testing.expect(countRole(plan, .operand_primary_digit) > 0);
    try std.testing.expect(countRole(plan, .operand_secondary_digit) > 0);
}

test "render plan decomposes decimal quantities into visible unit tokens" {
    const allocator = std.testing.allocator;
    var scene = try addSceneAt(allocator, fixtures.add_decimal_single_carry, .{ .tick = 0, .phase = 0.0 });
    defer scene.deinit(allocator);

    const cfg = layout.LayoutConfig{};
    var plan = try buildPlan(allocator, scene, cfg, .{ .sum_composition_overlay = true });
    defer plan.deinit(allocator);

    // 17 + 8 at tick 0 exposes only the active units column:
    // primary digit: 7 => 7 unit tokens + 1 anchor.
    // secondary digit: 8 => 8 unit tokens + 1 anchor.
    try std.testing.expectEqual(@as(usize, 8), countRole(plan, .operand_primary_digit));
    try std.testing.expectEqual(@as(usize, 9), countRole(plan, .operand_secondary_digit));
    try std.testing.expectEqual(@as(usize, 0), countRole(plan, .base_bundle_token));
}

test "render plan deterministic baselines for keyframes" {
    const allocator = std.testing.allocator;
    const cfg = layout.LayoutConfig{};
    for (keyframes.canonical, 0..) |kf, i| {
        var scene = try keyframes.buildSceneForKeyframe(allocator, kf);
        defer scene.deinit(allocator);
        var plan = try buildPlan(allocator, scene, cfg, .{});
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

    var p_early = try buildPlan(allocator, early, cfg, .{});
    defer p_early.deinit(allocator);
    var p_late = try buildPlan(allocator, late, cfg, .{});
    defer p_late.deinit(allocator);

    try std.testing.expect(planHash(p_early) != planHash(p_late));
}

test "render plan hash changes across camera modes for same tape sample" {
    const allocator = std.testing.allocator;
    const fx = fixtures.mul_base60_carry;
    const cfg = layout.LayoutConfig{};

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try @import("../math/multiplication.zig").multiplyWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var story = try es.buildSceneAtTimeWithCameraMode(allocator, res.tape, .{ .tick = 0, .phase = 0.5 }, .storyboard);
    defer story.deinit(allocator);
    var cine = try es.buildSceneAtTimeWithCameraMode(allocator, res.tape, .{ .tick = 0, .phase = 0.5 }, .cinematic);
    defer cine.deinit(allocator);

    var p_story = try buildPlan(allocator, story, cfg, .{});
    defer p_story.deinit(allocator);
    var p_cine = try buildPlan(allocator, cine, cfg, .{});
    defer p_cine.deinit(allocator);

    try std.testing.expect(planHash(p_story) != planHash(p_cine));
}
