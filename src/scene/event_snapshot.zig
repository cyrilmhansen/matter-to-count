const std = @import("std");
const number = @import("../math/number.zig");
const addition = @import("../math/addition.zig");
const subtraction = @import("../math/subtraction.zig");
const shift = @import("../math/shift.zig");
const fixtures = @import("../tests/fixtures.zig");
const es = @import("event_scene.zig");

fn quantizeCoord(v: f32) i32 {
    const scaled = std.math.round(v * 1000.0);
    return @as(i32, @intFromFloat(scaled));
}

pub fn writeCompactSnapshot(writer: anytype, scene: es.ArithmeticSceneState) !void {
    const finalized: u8 = if (scene.is_finalized) 1 else 0;
    try writer.print("v1|f={d}|ac=", .{finalized});
    for (scene.active_columns, 0..) |col, i| {
        if (i != 0) try writer.writeByte(',');
        try writer.print("{d}", .{col});
    }
    try writer.writeAll("|e=");
    for (scene.entities, 0..) |e, i| {
        if (i != 0) try writer.writeByte(';');
        try writer.print(
            "{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}",
            .{
                e.id,
                @intFromEnum(e.role),
                e.column,
                e.value,
                @as(u8, if (e.visible) 1 else 0),
                @as(u8, if (e.in_transit) 1 else 0),
                quantizeCoord(e.x),
                quantizeCoord(e.y),
                @intFromEnum(e.emissive),
            },
        );
    }
}

pub fn toOwnedCompactSnapshot(allocator: std.mem.Allocator, scene: es.ArithmeticSceneState) ![]u8 {
    var out = try std.ArrayList(u8).initCapacity(allocator, 256);
    defer out.deinit(allocator);
    try writeCompactSnapshot(out.writer(allocator), scene);
    return out.toOwnedSlice(allocator);
}

pub fn snapshotHash(allocator: std.mem.Allocator, scene: es.ArithmeticSceneState) !u64 {
    const bytes = try toOwnedCompactSnapshot(allocator, scene);
    defer allocator.free(bytes);
    return std.hash.Wyhash.hash(0, bytes);
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

test "compact snapshot includes semantic fields" {
    const allocator = std.testing.allocator;
    var scene = try addSceneAt(allocator, fixtures.add_decimal_single_carry, .{ .tick = 0, .phase = 0.5 });
    defer scene.deinit(allocator);

    const text = try toOwnedCompactSnapshot(allocator, scene);
    defer allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "v1|f=") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "|ac=") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "|e=") != null);
}

test "snapshot baseline values" {
    const allocator = std.testing.allocator;

    var add_mid = try addSceneAt(allocator, fixtures.add_decimal_single_carry, .{ .tick = 0, .phase = 0.5 });
    defer add_mid.deinit(allocator);
    var sub_mid = try subSceneAt(allocator, fixtures.sub_decimal_borrow_chain, .{ .tick = 1, .phase = 0.4 });
    defer sub_mid.deinit(allocator);
    var shift_mid = try shiftSceneAt(allocator, fixtures.shift_decimal_left_once, .{ .tick = 0, .phase = 0.5 });
    defer shift_mid.deinit(allocator);
    var add_final = try addSceneAt(allocator, fixtures.add_decimal_cascade_carry, .{ .tick = 4, .phase = 1.0 });
    defer add_final.deinit(allocator);

    const h_add_mid = try snapshotHash(allocator, add_mid);
    const h_sub_mid = try snapshotHash(allocator, sub_mid);
    const h_shift_mid = try snapshotHash(allocator, shift_mid);
    const h_add_final = try snapshotHash(allocator, add_final);
    // Baseline values are pinned on this repository/toolchain for deterministic keyframes.
    try std.testing.expectEqual(@as(u64, 0x42afce89f02d1378), h_add_mid);
    try std.testing.expectEqual(@as(u64, 0xf2e2b6c9af9d7647), h_sub_mid);
    try std.testing.expectEqual(@as(u64, 0xf9f5a0747b43e28c), h_shift_mid);
    try std.testing.expectEqual(@as(u64, 0x506392639f6b1b4d), h_add_final);
}
