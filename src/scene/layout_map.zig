const std = @import("std");
const number = @import("../math/number.zig");
const addition = @import("../math/addition.zig");
const subtraction = @import("../math/subtraction.zig");
const shift = @import("../math/shift.zig");
const fixtures = @import("../tests/fixtures.zig");
const es = @import("event_scene.zig");
const snap = @import("event_snapshot.zig");
const scene_state = @import("scene_state.zig");

pub const LayoutConfig = struct {
    column_spacing: f32 = 0.8,
    row_spacing: f32 = 0.9,
    marker_y: f32 = -0.5,
};

fn roleDepth(role: es.EntityRole) f32 {
    return switch (role) {
        .source_digit => 0.00,
        .result_digit => 0.02,
        .carry_packet => 0.04,
        .borrow_packet => 0.06,
        .shift_packet => 0.08,
    };
}

fn roleYOffset(role: es.EntityRole, cfg: LayoutConfig) f32 {
    return switch (role) {
        .source_digit => 0.0,
        .result_digit => cfg.row_spacing,
        .carry_packet, .borrow_packet, .shift_packet => cfg.row_spacing * 0.5,
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
        const x = e.x * cfg.column_spacing;
        const y = roleYOffset(e.role, cfg) + (e.y - 0.5) * 0.2;
        const z = roleDepth(e.role);
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

    var add_mid = try addSceneAt(allocator, fixtures.add_decimal_single_carry, .{ .tick = 0, .phase = 0.5 });
    defer add_mid.deinit(allocator);
    var sub_mid = try subSceneAt(allocator, fixtures.sub_decimal_borrow_chain, .{ .tick = 1, .phase = 0.4 });
    defer sub_mid.deinit(allocator);
    var shift_mid = try shiftSceneAt(allocator, fixtures.shift_decimal_left_once, .{ .tick = 0, .phase = 0.5 });
    defer shift_mid.deinit(allocator);
    var add_final = try addSceneAt(allocator, fixtures.add_decimal_cascade_carry, .{ .tick = 4, .phase = 1.0 });
    defer add_final.deinit(allocator);

    const sem_add_mid = try snap.snapshotHash(allocator, add_mid);
    const sem_sub_mid = try snap.snapshotHash(allocator, sub_mid);
    const sem_shift_mid = try snap.snapshotHash(allocator, shift_mid);
    const sem_add_final = try snap.snapshotHash(allocator, add_final);

    const lay_add_mid = try layoutHash(allocator, add_mid, cfg);
    const lay_sub_mid = try layoutHash(allocator, sub_mid, cfg);
    const lay_shift_mid = try layoutHash(allocator, shift_mid, cfg);
    const lay_add_final = try layoutHash(allocator, add_final, cfg);

    try std.testing.expectEqual(@as(u64, 0x42afce89f02d1378), sem_add_mid);
    try std.testing.expectEqual(@as(u64, 0xf2e2b6c9af9d7647), sem_sub_mid);
    try std.testing.expectEqual(@as(u64, 0xf9f5a0747b43e28c), sem_shift_mid);
    try std.testing.expectEqual(@as(u64, 0x506392639f6b1b4d), sem_add_final);

    try std.testing.expectEqual(@as(u64, 0x924c36cf734d7a32), lay_add_mid);
    try std.testing.expectEqual(@as(u64, 0x4a7d7c5f040b6999), lay_sub_mid);
    try std.testing.expectEqual(@as(u64, 0x51afddbda284b206), lay_shift_mid);
    try std.testing.expectEqual(@as(u64, 0x6b0d16a9aa3f38f5), lay_add_final);
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
