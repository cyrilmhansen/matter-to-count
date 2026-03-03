const std = @import("std");
const scene_controller = @import("../app/scene_controller.zig");
const event_scene = @import("../scene/event_scene.zig");
const number = @import("../math/number.zig");
const addition = @import("../math/addition.zig");
const subtraction = @import("../math/subtraction.zig");
const shift = @import("../math/shift.zig");
const fixtures = @import("fixtures.zig");

pub const SceneCase = enum {
    add_single_carry,
    add_cascade_carry,
    sub_borrow_chain,
    shift_decimal_left,
};

pub const CanonicalKeyframe = struct {
    id: []const u8,
    scene_kind: scene_controller.SceneKind,
    case_id: SceneCase,
    sample: event_scene.TimeSample,
};

pub const BaselineHashes = struct {
    semantic: u64,
    layout: u64,
    plan: u64,
};

// Canonical milestone-2 keyframes, shared across semantic/layout/render-plan regression tests.
pub const canonical = [_]CanonicalKeyframe{
    .{
        .id = "add_mid",
        .scene_kind = .add,
        .case_id = .add_single_carry,
        .sample = .{ .tick = 0, .phase = 0.5 },
    },
    .{
        .id = "sub_mid",
        .scene_kind = .sub,
        .case_id = .sub_borrow_chain,
        .sample = .{ .tick = 1, .phase = 0.4 },
    },
    .{
        .id = "shift_mid",
        .scene_kind = .shift,
        .case_id = .shift_decimal_left,
        .sample = .{ .tick = 0, .phase = 0.5 },
    },
    .{
        .id = "add_final",
        .scene_kind = .add,
        .case_id = .add_cascade_carry,
        .sample = .{ .tick = 4, .phase = 1.0 },
    },
};

pub const baselines = @import("keyframes_baselines.zig").baselines;

pub fn buildSceneForKeyframe(allocator: std.mem.Allocator, kf: CanonicalKeyframe) !event_scene.ArithmeticSceneState {
    return switch (kf.case_id) {
        .add_single_carry => try buildAddScene(allocator, fixtures.add_decimal_single_carry, kf.sample),
        .add_cascade_carry => try buildAddScene(allocator, fixtures.add_decimal_cascade_carry, kf.sample),
        .sub_borrow_chain => try buildSubScene(allocator, fixtures.sub_decimal_borrow_chain, kf.sample),
        .shift_decimal_left => try buildShiftScene(allocator, fixtures.shift_decimal_left_once, kf.sample),
    };
}

fn buildAddScene(
    allocator: std.mem.Allocator,
    fx: fixtures.Fixture,
    sample: event_scene.TimeSample,
) !event_scene.ArithmeticSceneState {
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try addition.addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);
    return event_scene.buildSceneAtTime(allocator, res.tape, sample);
}

fn buildSubScene(
    allocator: std.mem.Allocator,
    fx: fixtures.Fixture,
    sample: event_scene.TimeSample,
) !event_scene.ArithmeticSceneState {
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try subtraction.subWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);
    return event_scene.buildSceneAtTime(allocator, res.tape, sample);
}

fn buildShiftScene(
    allocator: std.mem.Allocator,
    fx: fixtures.Fixture,
    sample: event_scene.TimeSample,
) !event_scene.ArithmeticSceneState {
    var input = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer input.deinit(allocator);
    var res = try shift.multiplyByBaseWithEvents(allocator, input);
    defer res.deinit(allocator);
    return event_scene.buildSceneAtTime(allocator, res.tape, sample);
}
