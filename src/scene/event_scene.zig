const std = @import("std");
const event = @import("../events/event.zig");
const tape = @import("../events/tape.zig");
const motion = @import("../choreo/motion.zig");
const number = @import("../math/number.zig");
const addition = @import("../math/addition.zig");
const subtraction = @import("../math/subtraction.zig");
const shift = @import("../math/shift.zig");
const multiplication = @import("../math/multiplication.zig");
const fixtures = @import("../tests/fixtures.zig");

pub const EmissiveClass = enum {
    idle,
    active,
    highlight,
};

pub const EntityRole = enum {
    operand_primary_digit,
    operand_secondary_digit,
    result_digit,
    carry_packet,
    borrow_packet,
    shift_packet,
    partial_row_marker,
};

pub const PaperRowKind = enum {
    carry,
    operand_primary,
    operand_secondary,
    result,
    partial_product,
    borrow_reserve,
    annotation,
};

pub const Entity = struct {
    id: u32,
    role: EntityRole,
    row_kind: PaperRowKind,
    row_index: u16,
    column: u16,
    value: u16,
    visible: bool,
    in_transit: bool,
    pos_x: f32,
    pos_y: f32,
    pos_z: f32,
    scale: f32,
    yaw_deg: f32,
    emissive: EmissiveClass,
};

pub const TimeSample = struct {
    tick: u32,
    phase: f32, // [0.0, 1.0]
};

pub const CameraMode = enum {
    storyboard,
    cinematic,
    debug,
};

pub const CameraState = struct {
    yaw_deg: f32,
    pitch_deg: f32,
    perspective: f32,
};

pub const ArithmeticSceneState = struct {
    entities: []Entity,
    active_columns: []u16,
    is_finalized: bool,
    camera: CameraState,

    pub fn deinit(self: ArithmeticSceneState, allocator: std.mem.Allocator) void {
        allocator.free(self.entities);
        allocator.free(self.active_columns);
    }
};

fn clampPhase(phase: f32) f32 {
    if (phase < 0.0) return 0.0;
    if (phase > 1.0) return 1.0;
    return phase;
}

fn maxColumnInTape(t: tape.EventTape) u16 {
    var m: u16 = 0;
    for (t.events) |e| {
        m = @max(m, e.column);
        if (e.carry_to_column) |c| m = @max(m, c);
        if (e.borrow_from_column) |c| m = @max(m, c);
        if (e.target_column) |c| m = @max(m, c);
    }
    return m;
}

fn eventApplied(e: event.Event, sample: TimeSample) bool {
    if (e.time.tick < sample.tick) return true;
    if (e.time.tick > sample.tick) return false;
    const cutoff = clampPhase(sample.phase) * 100.0;
    return cutoff >= @as(f32, @floatFromInt(e.time.substep));
}

fn eventIsActiveThisTick(e: event.Event, sample: TimeSample) bool {
    return e.time.tick == sample.tick;
}

fn hasKind(t: tape.EventTape, kind: event.EventKind) bool {
    for (t.events) |e| {
        if (e.kind == kind) return true;
    }
    return false;
}

const CameraProfile = enum {
    add,
    sub,
    shift,
    mul,
};

const CameraMoment = enum {
    transfer,
    settle,
    final,
};

fn detectProfile(t: tape.EventTape) CameraProfile {
    if (hasKind(t, .partial_row_start)) return .mul;
    if (hasKind(t, .borrow_request)) return .sub;
    if (hasKind(t, .shift_start)) return .shift;
    return .add;
}

fn detectMoment(sample: TimeSample, is_finalized: bool) CameraMoment {
    if (is_finalized) return .final;
    if (clampPhase(sample.phase) >= 0.85) return .settle;
    return .transfer;
}

fn baseCamera(profile: CameraProfile, moment: CameraMoment) CameraState {
    return switch (profile) {
        .add => switch (moment) {
            .transfer => .{ .yaw_deg = 24.0, .pitch_deg = 16.0, .perspective = 0.36 },
            .settle => .{ .yaw_deg = 20.0, .pitch_deg = 14.0, .perspective = 0.33 },
            .final => .{ .yaw_deg = 14.0, .pitch_deg = 10.0, .perspective = 0.28 },
        },
        .sub => switch (moment) {
            .transfer => .{ .yaw_deg = 22.0, .pitch_deg = 17.0, .perspective = 0.37 },
            .settle => .{ .yaw_deg = 19.0, .pitch_deg = 15.0, .perspective = 0.34 },
            .final => .{ .yaw_deg = 13.0, .pitch_deg = 10.0, .perspective = 0.28 },
        },
        .shift => switch (moment) {
            .transfer => .{ .yaw_deg = 18.0, .pitch_deg = 12.0, .perspective = 0.31 },
            .settle => .{ .yaw_deg = 16.0, .pitch_deg = 10.0, .perspective = 0.29 },
            .final => .{ .yaw_deg = 12.0, .pitch_deg = 8.0, .perspective = 0.25 },
        },
        .mul => switch (moment) {
            .transfer => .{ .yaw_deg = 32.0, .pitch_deg = 20.0, .perspective = 0.44 },
            .settle => .{ .yaw_deg = 27.0, .pitch_deg = 17.0, .perspective = 0.40 },
            .final => .{ .yaw_deg = 18.0, .pitch_deg = 12.0, .perspective = 0.32 },
        },
    };
}

fn applyCameraMode(base: CameraState, mode: CameraMode) CameraState {
    var c = base;
    switch (mode) {
        .storyboard => {},
        .cinematic => {
            c.yaw_deg *= 1.20;
            c.pitch_deg *= 1.15;
            c.perspective *= 1.25;
        },
        .debug => {
            c.yaw_deg = 0.0;
            c.pitch_deg = 0.0;
            c.perspective = 0.05;
        },
    }
    return c;
}

fn deriveCamera(t: tape.EventTape, sample: TimeSample, is_finalized: bool, mode: CameraMode) CameraState {
    const profile = detectProfile(t);
    const moment = detectMoment(sample, is_finalized);
    return applyCameraMode(baseCamera(profile, moment), mode);
}

fn packetProgress(start_substep: u16, phase: f32) f32 {
    const start = clampPhase(@as(f32, @floatFromInt(start_substep)) / 100.0);
    const p = clampPhase(phase);
    if (start >= 1.0) return if (p >= 1.0) 1.0 else 0.0;
    if (p <= start) return 0.0;
    const window = 1.0 - start;
    return clampPhase((p - start) / window);
}

fn choreoProfileForCamera(mode: CameraMode) motion.ChoreoProfile {
    return switch (mode) {
        .storyboard => motion.storyboardProfile(),
        .cinematic => motion.cinematicProfile(),
        .debug => motion.debugProfile(),
    };
}

fn packetProgressForRole(role: EntityRole, start_substep: u16, phase: f32, profile: motion.ChoreoProfile) f32 {
    const base = packetProgress(start_substep, phase);
    const rate = switch (role) {
        .carry_packet => profile.carry_rate,
        .borrow_packet => profile.borrow_rate,
        .shift_packet => profile.shift_rate,
        else => 1.0,
    };
    return clampPhase(base * rate);
}

fn rowForRole(
    role: EntityRole,
    column: u16,
    value: u16,
    profile: CameraProfile,
    active_partial_row: ?u16,
) struct { row_kind: PaperRowKind, row_index: u16 } {
    _ = value;
    return switch (role) {
        .operand_primary_digit => .{ .row_kind = .operand_primary, .row_index = 1 },
        .operand_secondary_digit => .{ .row_kind = .operand_secondary, .row_index = 2 },
        .result_digit => .{ .row_kind = .result, .row_index = 3 },
        .carry_packet => if (profile == .mul and active_partial_row != null)
            .{
                .row_kind = .partial_product,
                .row_index = @as(u16, @intCast(4 + active_partial_row.?)),
            }
        else
            .{ .row_kind = .carry, .row_index = 0 },
        .borrow_packet => .{ .row_kind = .borrow_reserve, .row_index = 0 },
        .shift_packet => .{ .row_kind = .annotation, .row_index = 1 },
        .partial_row_marker => .{ .row_kind = .partial_product, .row_index = @as(u16, @intCast(4 + column)) },
    };
}

fn pushPacketEntity(
    allocator: std.mem.Allocator,
    entities: *std.ArrayList(Entity),
    next_id: *u32,
    role: EntityRole,
    value: u16,
    src_column: u16,
    dst_column: u16,
    substep: u16,
    phase: f32,
    profile: CameraProfile,
    active_partial_row: ?u16,
    choreo_profile: motion.ChoreoProfile,
) !void {
    const p = packetProgressForRole(role, substep, phase, choreo_profile);
    const row = rowForRole(role, src_column, value, profile, active_partial_row);
    const transform = switch (role) {
        .carry_packet => motion.calcCarryTransformWithProfile(p, src_column, dst_column, choreo_profile),
        .borrow_packet => motion.calcBorrowTransformWithProfile(p, src_column, dst_column, value, choreo_profile),
        .shift_packet => motion.calcShiftTransformWithProfile(p, src_column, dst_column, choreo_profile),
        else => motion.Transform{
            .pos_x = @as(f32, @floatFromInt(src_column)),
            .pos_y = 0.5,
            .pos_z = 0.08,
            .yaw_deg = 0.0,
            .scale = 1.0,
        },
    };

    try entities.append(allocator, .{
        .id = next_id.*,
        .role = role,
        .row_kind = row.row_kind,
        .row_index = row.row_index,
        .column = src_column,
        .value = value,
        .visible = true,
        .in_transit = true,
        .pos_x = transform.pos_x,
        .pos_y = transform.pos_y,
        .pos_z = transform.pos_z,
        .scale = transform.scale,
        .yaw_deg = transform.yaw_deg,
        .emissive = .highlight,
    });
    next_id.* += 1;
}

pub fn buildSceneAtTime(allocator: std.mem.Allocator, t: tape.EventTape, sample: TimeSample) !ArithmeticSceneState {
    return buildSceneAtTimeWithCameraMode(allocator, t, sample, .storyboard);
}

pub fn buildSceneAtTimeWithCameraMode(
    allocator: std.mem.Allocator,
    t: tape.EventTape,
    sample: TimeSample,
    camera_mode: CameraMode,
) !ArithmeticSceneState {
    const max_col = maxColumnInTape(t);
    const col_count: usize = @as(usize, max_col) + 1;
    const profile = detectProfile(t);
    const choreo_profile = choreoProfileForCamera(camera_mode);

    const source_primary_values = try allocator.alloc(i16, col_count);
    defer allocator.free(source_primary_values);
    const source_secondary_values = try allocator.alloc(i16, col_count);
    defer allocator.free(source_secondary_values);
    const result_values = try allocator.alloc(i16, col_count);
    defer allocator.free(result_values);
    const active_flags = try allocator.alloc(bool, col_count);
    defer allocator.free(active_flags);
    const partial_row_active = try allocator.alloc(bool, col_count);
    defer allocator.free(partial_row_active);

    @memset(source_primary_values, -1);
    @memset(source_secondary_values, -1);
    @memset(result_values, -1);
    @memset(active_flags, false);
    @memset(partial_row_active, false);

    var entities = try std.ArrayList(Entity).initCapacity(allocator, col_count * 2 + 4);
    defer entities.deinit(allocator);
    var next_id: u32 = 1;
    var is_finalized = false;
    var active_partial_row: ?u16 = null;
    const phase = clampPhase(sample.phase);

    for (t.events) |e| {
        if (eventIsActiveThisTick(e, sample)) {
            active_flags[e.column] = true;
        }

        if (e.time.tick == sample.tick and phase < 1.0) {
            const start = @as(f32, @floatFromInt(e.time.substep)) / 100.0;
            if (phase >= start) {
                switch (e.kind) {
                    .partial_row_start => {
                        active_partial_row = e.column;
                    },
                    .partial_row_complete => {
                        if (active_partial_row != null and active_partial_row.? == e.column) {
                            active_partial_row = null;
                        }
                    },
                    .carry_emit => {
                        const to = e.carry_to_column orelse @min(@as(u16, @intCast(col_count - 1)), e.column + 1);
                        try pushPacketEntity(
                            allocator,
                            &entities,
                            &next_id,
                            .carry_packet,
                            e.value,
                            e.column,
                            to,
                            e.time.substep,
                            phase,
                            profile,
                            active_partial_row,
                            choreo_profile,
                        );
                    },
                    .borrow_request => {
                        const from = e.borrow_from_column orelse @min(@as(u16, @intCast(col_count - 1)), e.column + 1);
                        try pushPacketEntity(
                            allocator,
                            &entities,
                            &next_id,
                            .borrow_packet,
                            e.value,
                            from,
                            e.column,
                            e.time.substep,
                            phase,
                            profile,
                            active_partial_row,
                            choreo_profile,
                        );
                    },
                    .shift_start => {
                        const to = e.target_column orelse @min(@as(u16, @intCast(col_count - 1)), e.column + 1);
                        try pushPacketEntity(
                            allocator,
                            &entities,
                            &next_id,
                            .shift_packet,
                            e.value,
                            e.column,
                            to,
                            e.time.substep,
                            phase,
                            profile,
                            active_partial_row,
                            choreo_profile,
                        );
                    },
                    else => {},
                }
            }
        }

        if (eventApplied(e, sample)) {
            switch (e.kind) {
                .digit_place => {
                    source_primary_values[e.column] = @as(i16, @intCast(e.value));
                    if (e.rhs_value) |rhs_v| {
                        source_secondary_values[e.column] = @as(i16, @intCast(rhs_v));
                    }
                },
                .digit_settle => result_values[e.column] = @as(i16, @intCast(e.value)),
                .partial_row_start => partial_row_active[e.column] = true,
                .partial_row_complete => partial_row_active[e.column] = false,
                .result_finalize => is_finalized = true,
                else => {},
            }
        }
    }

    var row: usize = 0;
    while (row < col_count) : (row += 1) {
        if (partial_row_active[row]) {
            const row_f = @as(f32, @floatFromInt(row));
            const row_meta = rowForRole(.partial_row_marker, @as(u16, @intCast(row)), 0, profile, null);
            try entities.append(allocator, .{
                .id = next_id,
                .role = .partial_row_marker,
                .row_kind = row_meta.row_kind,
                .row_index = row_meta.row_index,
                .column = @as(u16, @intCast(row)),
                .value = 0,
                .visible = true,
                .in_transit = false,
                .pos_x = @as(f32, @floatFromInt(row)),
                .pos_y = 1.5,
                .pos_z = 0.14 + row_f * 0.06,
                .scale = 1.15 + row_f * 0.03,
                .yaw_deg = 0.0,
                .emissive = .highlight,
            });
            next_id += 1;
        }
    }

    var col: usize = 0;
    while (col < col_count) : (col += 1) {
        if (source_primary_values[col] >= 0) {
            const row_meta = rowForRole(.operand_primary_digit, @as(u16, @intCast(col)), @as(u16, @intCast(source_primary_values[col])), profile, null);
            try entities.append(allocator, .{
                .id = next_id,
                .role = .operand_primary_digit,
                .row_kind = row_meta.row_kind,
                .row_index = row_meta.row_index,
                .column = @as(u16, @intCast(col)),
                .value = @as(u16, @intCast(source_primary_values[col])),
                .visible = true,
                .in_transit = false,
                .pos_x = @as(f32, @floatFromInt(col)),
                .pos_y = 0.0,
                .pos_z = 0.0,
                .scale = 1.0,
                .yaw_deg = 0.0,
                .emissive = if (active_flags[col]) .active else .idle,
            });
            next_id += 1;
        }
        if (source_secondary_values[col] >= 0) {
            const row_meta = rowForRole(.operand_secondary_digit, @as(u16, @intCast(col)), @as(u16, @intCast(source_secondary_values[col])), profile, null);
            try entities.append(allocator, .{
                .id = next_id,
                .role = .operand_secondary_digit,
                .row_kind = row_meta.row_kind,
                .row_index = row_meta.row_index,
                .column = @as(u16, @intCast(col)),
                .value = @as(u16, @intCast(source_secondary_values[col])),
                .visible = true,
                .in_transit = false,
                .pos_x = @as(f32, @floatFromInt(col)),
                .pos_y = 0.5,
                .pos_z = 0.01,
                .scale = 0.96,
                .yaw_deg = 0.0,
                .emissive = if (active_flags[col]) .active else .idle,
            });
            next_id += 1;
        }
        if (result_values[col] >= 0) {
            const row_meta = rowForRole(.result_digit, @as(u16, @intCast(col)), @as(u16, @intCast(result_values[col])), profile, null);
            try entities.append(allocator, .{
                .id = next_id,
                .role = .result_digit,
                .row_kind = row_meta.row_kind,
                .row_index = row_meta.row_index,
                .column = @as(u16, @intCast(col)),
                .value = @as(u16, @intCast(result_values[col])),
                .visible = true,
                .in_transit = false,
                .pos_x = @as(f32, @floatFromInt(col)),
                .pos_y = 1.0,
                .pos_z = 0.02,
                .scale = 1.0,
                .yaw_deg = 0.0,
                .emissive = if (active_flags[col]) .active else .idle,
            });
            next_id += 1;
        }
    }

    var active_columns_list = try std.ArrayList(u16).initCapacity(allocator, col_count);
    defer active_columns_list.deinit(allocator);
    col = 0;
    while (col < col_count) : (col += 1) {
        if (active_flags[col]) {
            try active_columns_list.append(allocator, @as(u16, @intCast(col)));
        }
    }

    return .{
        .entities = try entities.toOwnedSlice(allocator),
        .active_columns = try active_columns_list.toOwnedSlice(allocator),
        .is_finalized = is_finalized,
        .camera = deriveCamera(t, sample, is_finalized, camera_mode),
    };
}

fn countRole(scene: ArithmeticSceneState, role: EntityRole) usize {
    var n: usize = 0;
    for (scene.entities) |e| {
        if (e.role == role and e.visible) n += 1;
    }
    return n;
}

fn hasActiveColumn(scene: ArithmeticSceneState, col: u16) bool {
    for (scene.active_columns) |c| {
        if (c == col) return true;
    }
    return false;
}

fn firstRoleEntity(scene: ArithmeticSceneState, role: EntityRole) ?Entity {
    for (scene.entities) |e| {
        if (e.role == role and e.visible) return e;
    }
    return null;
}

test "packet progress normalizes strictly to active phase window" {
    try std.testing.expectEqual(@as(f32, 0.0), packetProgress(20, -0.5));
    try std.testing.expectEqual(@as(f32, 0.0), packetProgress(20, 0.2));
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), packetProgress(20, 0.6), 0.0001);
    try std.testing.expectEqual(@as(f32, 1.0), packetProgress(20, 1.5));
    try std.testing.expectEqual(@as(f32, 1.0), packetProgress(100, 1.0));
}

test "scene mapping: add single carry exposes carry packet in transit" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_decimal_single_carry;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try addition.addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.5 });
    defer scene.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), countRole(scene, .carry_packet));
    try std.testing.expect(hasActiveColumn(scene, 0));
    try std.testing.expect(!scene.is_finalized);
}

test "row semantics: decimal addition source/result digits map to explicit paper rows" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_decimal_single_carry;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try addition.addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 2, .phase = 1.0 });
    defer scene.deinit(allocator);

    var source_count: usize = 0;
    var result_count: usize = 0;
    for (scene.entities) |e| {
        if (!e.visible or e.in_transit) continue;
        switch (e.role) {
            .operand_primary_digit => {
                source_count += 1;
                try std.testing.expectEqual(PaperRowKind.operand_primary, e.row_kind);
                try std.testing.expectEqual(@as(u16, 1), e.row_index);
            },
            .result_digit => {
                result_count += 1;
                try std.testing.expectEqual(PaperRowKind.result, e.row_kind);
                try std.testing.expectEqual(@as(u16, 3), e.row_index);
            },
            else => {},
        }
    }

    try std.testing.expect(source_count > 0);
    try std.testing.expect(result_count > 0);
}

test "row semantics: decimal addition exposes secondary operand row from event payload" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_decimal_single_carry;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try addition.addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.0 });
    defer scene.deinit(allocator);

    var found_secondary = false;
    for (scene.entities) |e| {
        if (!e.visible or e.in_transit) continue;
        if (e.role == .operand_secondary_digit and e.row_kind == .operand_secondary and e.column == 0 and e.value == 8) {
            found_secondary = true;
            break;
        }
    }
    try std.testing.expect(found_secondary);
}

test "row semantics: decimal carry packet maps to carry row during transit" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_decimal_single_carry;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try addition.addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.5 });
    defer scene.deinit(allocator);

    const carry = firstRoleEntity(scene, .carry_packet) orelse return error.TestUnexpectedResult;
    try std.testing.expect(carry.in_transit);
    try std.testing.expectEqual(PaperRowKind.carry, carry.row_kind);
    try std.testing.expectEqual(@as(u16, 0), carry.row_index);
}

test "row semantics: multiplication carry packet follows active partial-product row" {
    const allocator = std.testing.allocator;
    const fx = fixtures.mul_base60_carry;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try multiplication.multiplyWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.5 });
    defer scene.deinit(allocator);

    const carry = firstRoleEntity(scene, .carry_packet) orelse return error.TestUnexpectedResult;
    try std.testing.expect(carry.in_transit);
    try std.testing.expectEqual(PaperRowKind.partial_product, carry.row_kind);
    try std.testing.expectEqual(@as(u16, 4), carry.row_index);
}

test "scene mapping: subtraction borrow chain exposes borrow packet in transit" {
    const allocator = std.testing.allocator;
    const fx = fixtures.sub_decimal_borrow_chain;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try subtraction.subWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 1, .phase = 0.4 });
    defer scene.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), countRole(scene, .borrow_packet));
    try std.testing.expect(hasActiveColumn(scene, 1));
    try std.testing.expect(!scene.is_finalized);
}

test "scene mapping: shift left exposes shift packet in transit" {
    const allocator = std.testing.allocator;
    const fx = fixtures.shift_decimal_left_once;

    var input = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer input.deinit(allocator);
    var res = try shift.multiplyByBaseWithEvents(allocator, input);
    defer res.deinit(allocator);

    var scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.5 });
    defer scene.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), countRole(scene, .shift_packet));
    try std.testing.expect(hasActiveColumn(scene, 0));
    try std.testing.expect(!scene.is_finalized);
}

test "scene mapping: carry destination activates only on destination tick events" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_decimal_single_carry;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try addition.addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var transfer = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.5 });
    defer transfer.deinit(allocator);
    try std.testing.expect(hasActiveColumn(transfer, 0));
    try std.testing.expect(!hasActiveColumn(transfer, 1));

    var receive = try buildSceneAtTime(allocator, res.tape, .{ .tick = 1, .phase = 0.0 });
    defer receive.deinit(allocator);
    try std.testing.expect(hasActiveColumn(receive, 1));
}

test "scene mapping: multiplication transfer sample exposes carry packet and active column" {
    const allocator = std.testing.allocator;
    const fx = fixtures.mul_base60_carry;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try multiplication.multiplyWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.5 });
    defer scene.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), countRole(scene, .carry_packet));
    try std.testing.expectEqual(@as(usize, 1), countRole(scene, .partial_row_marker));
    try std.testing.expect(hasActiveColumn(scene, 0));
    try std.testing.expect(!scene.is_finalized);
}

test "scene mapping: multiplication settle sample has no transit packets and is finalized" {
    const allocator = std.testing.allocator;
    const fx = fixtures.mul_base60_carry;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try multiplication.multiplyWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 4, .phase = 1.0 });
    defer scene.deinit(allocator);

    try std.testing.expect(scene.is_finalized);
    try std.testing.expectEqual(@as(usize, 0), countRole(scene, .carry_packet));
    try std.testing.expectEqual(@as(usize, 0), countRole(scene, .borrow_packet));
    try std.testing.expectEqual(@as(usize, 0), countRole(scene, .shift_packet));
    try std.testing.expectEqual(@as(usize, 0), countRole(scene, .partial_row_marker));
}

test "scene mapping: finalize appears at final sample" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_decimal_cascade_carry;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try addition.addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 4, .phase = 1.0 });
    defer scene.deinit(allocator);

    try std.testing.expect(scene.is_finalized);
    try std.testing.expectEqual(@as(usize, 0), countRole(scene, .carry_packet));
    try std.testing.expectEqual(@as(usize, 0), countRole(scene, .borrow_packet));
    try std.testing.expectEqual(@as(usize, 0), countRole(scene, .shift_packet));
}

test "camera rig is deterministic and operation-sensitive" {
    const allocator = std.testing.allocator;

    const add_fx = fixtures.add_decimal_single_carry;
    var add_lhs = try number.DigitNumber.fromU64(allocator, add_fx.base, add_fx.lhs);
    defer add_lhs.deinit(allocator);
    var add_rhs = try number.DigitNumber.fromU64(allocator, add_fx.base, add_fx.rhs);
    defer add_rhs.deinit(allocator);
    var add_res = try addition.addWithEvents(allocator, add_lhs, add_rhs);
    defer add_res.deinit(allocator);
    var add_scene = try buildSceneAtTime(allocator, add_res.tape, .{ .tick = 0, .phase = 0.5 });
    defer add_scene.deinit(allocator);

    const mul_fx = fixtures.mul_base60_carry;
    var mul_lhs = try number.DigitNumber.fromU64(allocator, mul_fx.base, mul_fx.lhs);
    defer mul_lhs.deinit(allocator);
    var mul_rhs = try number.DigitNumber.fromU64(allocator, mul_fx.base, mul_fx.rhs);
    defer mul_rhs.deinit(allocator);
    var mul_res = try multiplication.multiplyWithEvents(allocator, mul_lhs, mul_rhs);
    defer mul_res.deinit(allocator);
    var mul_scene = try buildSceneAtTime(allocator, mul_res.tape, .{ .tick = 0, .phase = 0.5 });
    defer mul_scene.deinit(allocator);

    try std.testing.expect(add_scene.camera.yaw_deg != mul_scene.camera.yaw_deg);
    try std.testing.expect(add_scene.camera.perspective != mul_scene.camera.perspective);
}

test "camera keyframe targets for multiplication and mode overrides" {
    const allocator = std.testing.allocator;
    const fx = fixtures.mul_base60_carry;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try multiplication.multiplyWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var transfer = try buildSceneAtTimeWithCameraMode(allocator, res.tape, .{ .tick = 0, .phase = 0.5 }, .storyboard);
    defer transfer.deinit(allocator);
    try std.testing.expectEqual(@as(f32, 32.0), transfer.camera.yaw_deg);
    try std.testing.expectEqual(@as(f32, 20.0), transfer.camera.pitch_deg);

    var final_story = try buildSceneAtTimeWithCameraMode(allocator, res.tape, .{ .tick = 4, .phase = 1.0 }, .storyboard);
    defer final_story.deinit(allocator);
    try std.testing.expectEqual(@as(f32, 18.0), final_story.camera.yaw_deg);
    try std.testing.expectEqual(@as(f32, 12.0), final_story.camera.pitch_deg);

    var final_debug = try buildSceneAtTimeWithCameraMode(allocator, res.tape, .{ .tick = 4, .phase = 1.0 }, .debug);
    defer final_debug.deinit(allocator);
    try std.testing.expectEqual(@as(f32, 0.0), final_debug.camera.yaw_deg);
    try std.testing.expectEqual(@as(f32, 0.0), final_debug.camera.pitch_deg);
    try std.testing.expectEqual(@as(f32, 0.05), final_debug.camera.perspective);

    var transfer_story = try buildSceneAtTimeWithCameraMode(allocator, res.tape, .{ .tick = 0, .phase = 0.5 }, .storyboard);
    defer transfer_story.deinit(allocator);
    var transfer_cine = try buildSceneAtTimeWithCameraMode(allocator, res.tape, .{ .tick = 0, .phase = 0.5 }, .cinematic);
    defer transfer_cine.deinit(allocator);
    try std.testing.expect(transfer_cine.camera.yaw_deg > transfer_story.camera.yaw_deg);
    try std.testing.expect(transfer_cine.camera.perspective > transfer_story.camera.perspective);
}

test "entities expose explicit 3d transform fields" {
    const allocator = std.testing.allocator;
    const fx = fixtures.mul_base60_carry;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try multiplication.multiplyWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.5 });
    defer scene.deinit(allocator);

    for (scene.entities) |e| {
        try std.testing.expect(std.math.isFinite(e.pos_x));
        try std.testing.expect(std.math.isFinite(e.pos_y));
        try std.testing.expect(std.math.isFinite(e.pos_z));
        try std.testing.expect(std.math.isFinite(e.scale));
        try std.testing.expect(std.math.isFinite(e.yaw_deg));
        try std.testing.expect(e.scale > 0.0);
    }
}

test "packet choreography uses role-specific 3d arcs" {
    const allocator = std.testing.allocator;

    var add_lhs = try number.DigitNumber.fromU64(allocator, fixtures.add_decimal_single_carry.base, fixtures.add_decimal_single_carry.lhs);
    defer add_lhs.deinit(allocator);
    var add_rhs = try number.DigitNumber.fromU64(allocator, fixtures.add_decimal_single_carry.base, fixtures.add_decimal_single_carry.rhs);
    defer add_rhs.deinit(allocator);
    var add_res = try addition.addWithEvents(allocator, add_lhs, add_rhs);
    defer add_res.deinit(allocator);
    var add_scene = try buildSceneAtTime(allocator, add_res.tape, .{ .tick = 0, .phase = 0.5 });
    defer add_scene.deinit(allocator);

    var shift_in = try number.DigitNumber.fromU64(allocator, fixtures.shift_decimal_left_once.base, fixtures.shift_decimal_left_once.lhs);
    defer shift_in.deinit(allocator);
    var shift_res = try shift.multiplyByBaseWithEvents(allocator, shift_in);
    defer shift_res.deinit(allocator);
    var shift_scene = try buildSceneAtTime(allocator, shift_res.tape, .{ .tick = 0, .phase = 0.5 });
    defer shift_scene.deinit(allocator);

    const carry = firstRoleEntity(add_scene, .carry_packet) orelse return error.TestUnexpectedResult;
    const shift_pkt = firstRoleEntity(shift_scene, .shift_packet) orelse return error.TestUnexpectedResult;

    try std.testing.expect(carry.pos_z > shift_pkt.pos_z);
    try std.testing.expect(carry.scale > shift_pkt.scale);
}

test "camera mode maps to different choreography profiles for packet motion" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_decimal_single_carry;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try addition.addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var story = try buildSceneAtTimeWithCameraMode(allocator, res.tape, .{ .tick = 0, .phase = 0.5 }, .storyboard);
    defer story.deinit(allocator);
    var cine = try buildSceneAtTimeWithCameraMode(allocator, res.tape, .{ .tick = 0, .phase = 0.5 }, .cinematic);
    defer cine.deinit(allocator);
    var debug = try buildSceneAtTimeWithCameraMode(allocator, res.tape, .{ .tick = 0, .phase = 0.5 }, .debug);
    defer debug.deinit(allocator);

    const carry_story = firstRoleEntity(story, .carry_packet) orelse return error.TestUnexpectedResult;
    const carry_cine = firstRoleEntity(cine, .carry_packet) orelse return error.TestUnexpectedResult;
    const carry_debug = firstRoleEntity(debug, .carry_packet) orelse return error.TestUnexpectedResult;

    try std.testing.expect(carry_cine.pos_z > carry_story.pos_z);
    try std.testing.expect(carry_story.pos_z > carry_debug.pos_z);
}

test "carry choreography key samples preserve arc identity at p≈0/0.5/1" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_decimal_single_carry;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try addition.addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var start_scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.03 });
    defer start_scene.deinit(allocator);
    var mid_scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.515 });
    defer mid_scene.deinit(allocator);
    var end_scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.999 });
    defer end_scene.deinit(allocator);

    const start = firstRoleEntity(start_scene, .carry_packet) orelse return error.TestUnexpectedResult;
    const mid = firstRoleEntity(mid_scene, .carry_packet) orelse return error.TestUnexpectedResult;
    const finish = firstRoleEntity(end_scene, .carry_packet) orelse return error.TestUnexpectedResult;

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), start.pos_x, 0.01);
    try std.testing.expect(mid.pos_y > start.pos_y);
    try std.testing.expect(mid.pos_y > finish.pos_y);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), finish.pos_x, 0.02);
}

test "borrow choreography key samples preserve lift-and-drop identity at p≈0/0.5/1" {
    const allocator = std.testing.allocator;
    const fx = fixtures.sub_decimal_borrow_once;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try subtraction.subWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var start_scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.01 });
    defer start_scene.deinit(allocator);
    var mid_scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.505 });
    defer mid_scene.deinit(allocator);
    var end_scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.999 });
    defer end_scene.deinit(allocator);

    const start = firstRoleEntity(start_scene, .borrow_packet) orelse return error.TestUnexpectedResult;
    const mid = firstRoleEntity(mid_scene, .borrow_packet) orelse return error.TestUnexpectedResult;
    const finish = firstRoleEntity(end_scene, .borrow_packet) orelse return error.TestUnexpectedResult;

    try std.testing.expect(mid.pos_y > start.pos_y);
    try std.testing.expect(mid.pos_y > finish.pos_y);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), finish.pos_x, 0.03);
}

test "shift choreography key samples preserve horizontal identity at p≈0/0.5/1" {
    const allocator = std.testing.allocator;
    const fx = fixtures.shift_decimal_left_once;

    var input = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer input.deinit(allocator);
    var res = try shift.multiplyByBaseWithEvents(allocator, input);
    defer res.deinit(allocator);

    var start_scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.0 });
    defer start_scene.deinit(allocator);
    var mid_scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.5 });
    defer mid_scene.deinit(allocator);
    var end_scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.999 });
    defer end_scene.deinit(allocator);

    const start = firstRoleEntity(start_scene, .shift_packet) orelse return error.TestUnexpectedResult;
    const mid = firstRoleEntity(mid_scene, .shift_packet) orelse return error.TestUnexpectedResult;
    const finish = firstRoleEntity(end_scene, .shift_packet) orelse return error.TestUnexpectedResult;

    try std.testing.expectApproxEqAbs(@as(f32, 0.5), start.pos_y, 0.02);
    try std.testing.expectApproxEqAbs(start.pos_y, mid.pos_y, 0.02);
    try std.testing.expectApproxEqAbs(mid.pos_y, finish.pos_y, 0.02);
    try std.testing.expect(finish.pos_x > mid.pos_x and mid.pos_x > start.pos_x);
    try std.testing.expect(finish.yaw_deg > mid.yaw_deg and mid.yaw_deg > start.yaw_deg);
}

test "multiplication partial rows are depth-separated by row index across samples" {
    const allocator = std.testing.allocator;
    const fx = fixtures.mul_base60_carry;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try multiplication.multiplyWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    var row0_scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 0, .phase = 0.5 });
    defer row0_scene.deinit(allocator);
    var row1_scene = try buildSceneAtTime(allocator, res.tape, .{ .tick = 2, .phase = 0.5 });
    defer row1_scene.deinit(allocator);

    const row0 = firstRoleEntity(row0_scene, .partial_row_marker) orelse return error.TestUnexpectedResult;
    const row1 = firstRoleEntity(row1_scene, .partial_row_marker) orelse return error.TestUnexpectedResult;
    try std.testing.expect(row1.column > row0.column);
    try std.testing.expect(row1.pos_z > row0.pos_z);
}
