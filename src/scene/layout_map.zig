const std = @import("std");
const number = @import("../math/number.zig");
const addition = @import("../math/addition.zig");
const subtraction = @import("../math/subtraction.zig");
const shift = @import("../math/shift.zig");
const fixtures = @import("../tests/fixtures.zig");
const keyframes = @import("../tests/keyframes.zig");
const es = @import("event_scene.zig");
const snap = @import("event_snapshot.zig");
const scene_state = @import("scene_state.zig");

pub const LayoutConfig = struct {
    column_spacing: f32 = 0.8,
    row_spacing: f32 = 0.9,
    marker_y: f32 = -0.5,
};

pub const Anchor = struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const TransferLaneKind = enum {
    carry_lane,
    borrow_lane,
    row_guide,
};

fn roleDepth(role: es.EntityRole) f32 {
    return switch (role) {
        .operand_primary_digit => 0.00,
        .operand_secondary_digit => 0.01,
        .result_digit => 0.02,
        .carry_packet => 0.04,
        .borrow_packet => 0.06,
        .shift_packet => 0.08,
        .partial_row_marker => 0.03,
    };
}

fn rowAnchorY(kind: es.PaperRowKind, row_index: u16, cfg: LayoutConfig) f32 {
    const row_f = @as(f32, @floatFromInt(row_index));
    return switch (kind) {
        // Canonical paper rows:
        // 0 = carry line, 1 = primary operand line, 3 = result line.
        .carry, .operand_primary, .operand_secondary, .result, .borrow_reserve, .annotation => (row_f - 1.0) * cfg.row_spacing,
        // Partial-product rows are indexed as 4+N and stack beneath the result region.
        .partial_product => cfg.row_spacing * (2.0 + (row_f - 4.0) * 0.75),
    };
}

pub fn cellAnchor(column: u16, row_kind: es.PaperRowKind, row_index: u16, cfg: LayoutConfig) Anchor {
    return .{
        .x = @as(f32, @floatFromInt(column)) * cfg.column_spacing,
        .y = rowAnchorY(row_kind, row_index, cfg),
        .z = 0.0,
    };
}

pub fn transferAnchor(lane: TransferLaneKind, column: u16, row_kind: es.PaperRowKind, row_index: u16, cfg: LayoutConfig) Anchor {
    const base = cellAnchor(column, row_kind, row_index, cfg);
    return switch (lane) {
        .carry_lane => .{ .x = base.x, .y = base.y - cfg.row_spacing * 0.35, .z = 0.03 },
        .borrow_lane => .{ .x = base.x, .y = base.y - cfg.row_spacing * 0.20, .z = 0.03 },
        .row_guide => .{ .x = base.x, .y = base.y, .z = 0.0 },
    };
}

pub fn mapArithmeticToDots(
    allocator: std.mem.Allocator,
    arithmetic: es.ArithmeticSceneState,
    cfg: LayoutConfig,
) !scene_state.SceneState {
    const total = arithmetic.entities.len + arithmetic.active_columns.len;
    const dots = try allocator.alloc(scene_state.Dot, total);
    errdefer allocator.free(dots);

    var i: usize = 0;
    for (arithmetic.entities) |e| {
        const col_anchor = cellAnchor(e.column, e.row_kind, e.row_index, cfg);
        const lane_anchor = switch (e.role) {
            .carry_packet => transferAnchor(.carry_lane, e.column, e.row_kind, e.row_index, cfg),
            .borrow_packet => transferAnchor(.borrow_lane, e.column, e.row_kind, e.row_index, cfg),
            else => transferAnchor(.row_guide, e.column, e.row_kind, e.row_index, cfg),
        };
        const x = col_anchor.x + (e.pos_x - @as(f32, @floatFromInt(e.column))) * cfg.column_spacing;
        const y = lane_anchor.y + (e.pos_y - 0.5) * (cfg.row_spacing * 0.35);
        const z = roleDepth(e.role) + e.pos_z * 0.4;
        dots[i] = .{ .x = x, .y = y, .z = z };
        i += 1;
    }

    for (arithmetic.active_columns) |col| {
        dots[i] = .{
            .x = @as(f32, @floatFromInt(col)) * cfg.column_spacing,
            .y = cfg.marker_y,
            .z = 0.10,
        };
        i += 1;
    }

    return .{ .dots = dots };
}

fn firstRoleDot(arithmetic: es.ArithmeticSceneState, mapped: scene_state.SceneState, role: es.EntityRole) ?scene_state.Dot {
    var i: usize = 0;
    while (i < arithmetic.entities.len) : (i += 1) {
        const e = arithmetic.entities[i];
        if (e.visible and e.role == role) return mapped.dots[i];
    }
    return null;
}

pub fn layoutHash(allocator: std.mem.Allocator, arithmetic: es.ArithmeticSceneState, cfg: LayoutConfig) !u64 {
    const mapped = try mapArithmeticToDots(allocator, arithmetic, cfg);
    defer allocator.free(mapped.dots);
    return scene_state.snapshotHash(mapped);
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

test "layout mapping preserves deterministic keyframe baselines" {
    const allocator = std.testing.allocator;
    const cfg = LayoutConfig{};
    for (keyframes.canonical, 0..) |kf, i| {
        var scene = try keyframes.buildSceneForKeyframe(allocator, kf);
        defer scene.deinit(allocator);

        const sem = try snap.snapshotHash(allocator, scene);
        const lay = try layoutHash(allocator, scene, cfg);
        try std.testing.expectEqual(keyframes.baselines[i].semantic, sem);
        try std.testing.expectEqual(keyframes.baselines[i].layout, lay);
    }
}

test "layout hash changes across animation phase within same tape" {
    const allocator = std.testing.allocator;
    const cfg = LayoutConfig{};
    const fx = fixtures.add_decimal_single_carry;

    var early = try addSceneAt(allocator, fx, .{ .tick = 0, .phase = 0.20 });
    defer early.deinit(allocator);
    var late = try addSceneAt(allocator, fx, .{ .tick = 0, .phase = 0.80 });
    defer late.deinit(allocator);

    const sem_early = try snap.snapshotHash(allocator, early);
    const sem_late = try snap.snapshotHash(allocator, late);
    const lay_early = try layoutHash(allocator, early, cfg);
    const lay_late = try layoutHash(allocator, late, cfg);

    try std.testing.expect(sem_early != sem_late);
    try std.testing.expect(lay_early != lay_late);
}

test "layout y-axis follows explicit paper row semantics" {
    const allocator = std.testing.allocator;
    const cfg = LayoutConfig{};

    var transfer = try addSceneAt(allocator, fixtures.add_decimal_single_carry, .{ .tick = 0, .phase = 0.5 });
    defer transfer.deinit(allocator);
    const mapped_transfer = try mapArithmeticToDots(allocator, transfer, cfg);
    defer allocator.free(mapped_transfer.dots);

    const carry_dot = firstRoleDot(transfer, mapped_transfer, .carry_packet) orelse return error.TestUnexpectedResult;
    const source_dot = firstRoleDot(transfer, mapped_transfer, .operand_primary_digit) orelse return error.TestUnexpectedResult;
    try std.testing.expect(carry_dot.y < source_dot.y);

    var final_scene = try addSceneAt(allocator, fixtures.add_decimal_single_carry, .{ .tick = 2, .phase = 1.0 });
    defer final_scene.deinit(allocator);
    const mapped_final = try mapArithmeticToDots(allocator, final_scene, cfg);
    defer allocator.free(mapped_final.dots);

    const final_source_dot = firstRoleDot(final_scene, mapped_final, .operand_primary_digit) orelse return error.TestUnexpectedResult;
    const final_result_dot = firstRoleDot(final_scene, mapped_final, .result_digit) orelse return error.TestUnexpectedResult;
    try std.testing.expect(final_result_dot.y > final_source_dot.y);
}

test "layout anchor API provides deterministic cell and transfer lanes" {
    const cfg = LayoutConfig{};
    const cell = cellAnchor(2, .operand_primary, 1, cfg);
    const carry_lane = transferAnchor(.carry_lane, 2, .carry, 0, cfg);
    const borrow_lane = transferAnchor(.borrow_lane, 2, .borrow_reserve, 0, cfg);

    try std.testing.expectApproxEqAbs(@as(f32, 1.6), cell.x, 0.0001);
    try std.testing.expect(carry_lane.y < cell.y);
    try std.testing.expect(borrow_lane.y > carry_lane.y);
}
