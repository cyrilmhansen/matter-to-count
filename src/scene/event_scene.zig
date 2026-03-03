const std = @import("std");
const event = @import("../events/event.zig");
const tape = @import("../events/tape.zig");
const number = @import("../math/number.zig");
const addition = @import("../math/addition.zig");
const subtraction = @import("../math/subtraction.zig");
const shift = @import("../math/shift.zig");
const fixtures = @import("../tests/fixtures.zig");

pub const EmissiveClass = enum {
    idle,
    active,
    highlight,
};

pub const EntityRole = enum {
    source_digit,
    result_digit,
    carry_packet,
    borrow_packet,
    shift_packet,
};

pub const Entity = struct {
    id: u32,
    role: EntityRole,
    column: u16,
    value: u16,
    visible: bool,
    in_transit: bool,
    x: f32,
    y: f32,
    emissive: EmissiveClass,
};

pub const TimeSample = struct {
    tick: u32,
    phase: f32, // [0.0, 1.0]
};

pub const ArithmeticSceneState = struct {
    entities: []Entity,
    active_columns: []u16,
    is_finalized: bool,

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

fn packetProgress(start_substep: u16, phase: f32) f32 {
    const start = @as(f32, @floatFromInt(start_substep)) / 100.0;
    const p = clampPhase(phase);
    if (p <= start) return 0.0;
    const den = 1.0 - start;
    if (den <= 0.0) return 1.0;
    const v = (p - start) / den;
    if (v < 0.0) return 0.0;
    if (v > 1.0) return 1.0;
    return v;
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
) !void {
    const p = packetProgress(substep, phase);
    const x0 = @as(f32, @floatFromInt(src_column));
    const x1 = @as(f32, @floatFromInt(dst_column));
    try entities.append(allocator, .{
        .id = next_id.*,
        .role = role,
        .column = src_column,
        .value = value,
        .visible = true,
        .in_transit = true,
        .x = x0 + (x1 - x0) * p,
        .y = 0.5,
        .emissive = .highlight,
    });
    next_id.* += 1;
}

pub fn buildSceneAtTime(allocator: std.mem.Allocator, t: tape.EventTape, sample: TimeSample) !ArithmeticSceneState {
    const max_col = maxColumnInTape(t);
    const col_count: usize = @as(usize, max_col) + 1;

    const source_values = try allocator.alloc(i16, col_count);
    defer allocator.free(source_values);
    const result_values = try allocator.alloc(i16, col_count);
    defer allocator.free(result_values);
    const active_flags = try allocator.alloc(bool, col_count);
    defer allocator.free(active_flags);

    @memset(source_values, -1);
    @memset(result_values, -1);
    @memset(active_flags, false);

    var entities = try std.ArrayList(Entity).initCapacity(allocator, col_count * 2 + 4);
    defer entities.deinit(allocator);
    var next_id: u32 = 1;
    var is_finalized = false;
    const phase = clampPhase(sample.phase);

    for (t.events) |e| {
        if (eventIsActiveThisTick(e, sample)) {
            active_flags[e.column] = true;
        }

        if (e.time.tick == sample.tick and phase < 1.0) {
            const start = @as(f32, @floatFromInt(e.time.substep)) / 100.0;
            if (phase >= start) {
                switch (e.kind) {
                    .carry_emit => {
                        const to = e.carry_to_column orelse @min(@as(u16, @intCast(col_count - 1)), e.column + 1);
                        try pushPacketEntity(allocator, &entities, &next_id, .carry_packet, e.value, e.column, to, e.time.substep, phase);
                    },
                    .borrow_request => {
                        const from = e.borrow_from_column orelse @min(@as(u16, @intCast(col_count - 1)), e.column + 1);
                        try pushPacketEntity(allocator, &entities, &next_id, .borrow_packet, e.value, from, e.column, e.time.substep, phase);
                    },
                    .shift_start => {
                        const to = e.target_column orelse @min(@as(u16, @intCast(col_count - 1)), e.column + 1);
                        try pushPacketEntity(allocator, &entities, &next_id, .shift_packet, e.value, e.column, to, e.time.substep, phase);
                    },
                    else => {},
                }
            }
        }

        if (eventApplied(e, sample)) {
            switch (e.kind) {
                .digit_place => source_values[e.column] = @as(i16, @intCast(e.value)),
                .digit_settle => result_values[e.column] = @as(i16, @intCast(e.value)),
                .result_finalize => is_finalized = true,
                else => {},
            }
        }
    }

    var col: usize = 0;
    while (col < col_count) : (col += 1) {
        if (source_values[col] >= 0) {
                try entities.append(allocator, .{
                .id = next_id,
                .role = .source_digit,
                .column = @as(u16, @intCast(col)),
                .value = @as(u16, @intCast(source_values[col])),
                .visible = true,
                .in_transit = false,
                .x = @as(f32, @floatFromInt(col)),
                .y = 0.0,
                .emissive = if (active_flags[col]) .active else .idle,
            });
            next_id += 1;
        }
        if (result_values[col] >= 0) {
                try entities.append(allocator, .{
                .id = next_id,
                .role = .result_digit,
                .column = @as(u16, @intCast(col)),
                .value = @as(u16, @intCast(result_values[col])),
                .visible = true,
                .in_transit = false,
                .x = @as(f32, @floatFromInt(col)),
                .y = 1.0,
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
