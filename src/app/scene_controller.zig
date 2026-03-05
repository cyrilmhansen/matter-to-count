const std = @import("std");
const number = @import("../math/number.zig");
const addition = @import("../math/addition.zig");
const subtraction = @import("../math/subtraction.zig");
const shift = @import("../math/shift.zig");
const multiplication = @import("../math/multiplication.zig");
const fixtures = @import("../tests/fixtures.zig");
const event_scene = @import("../scene/event_scene.zig");
const layout_map = @import("../scene/layout_map.zig");
const render_plan = @import("../render/render_plan.zig");

pub const SceneKind = enum {
    add,
    sub,
    shift,
    mul,

    pub fn parse(raw: []const u8) ?SceneKind {
        if (std.mem.eql(u8, raw, "add")) return .add;
        if (std.mem.eql(u8, raw, "sub")) return .sub;
        if (std.mem.eql(u8, raw, "shift")) return .shift;
        if (std.mem.eql(u8, raw, "mul")) return .mul;
        return null;
    }

    pub fn label(self: SceneKind) []const u8 {
        return switch (self) {
            .add => "ADD",
            .sub => "SUB",
            .shift => "SHIFT",
            .mul => "MUL",
        };
    }
};

pub const CameraMode = event_scene.CameraMode;
pub fn parseCameraMode(raw: []const u8) ?CameraMode {
    if (std.mem.eql(u8, raw, "storyboard")) return .storyboard;
    if (std.mem.eql(u8, raw, "cinematic")) return .cinematic;
    if (std.mem.eql(u8, raw, "debug")) return .debug;
    return null;
}

pub const FrameData = struct {
    plan: render_plan.RenderPlan,
    legend_buf: [64]u8,
    legend_len: usize,

    pub fn deinit(self: *FrameData, allocator: std.mem.Allocator) void {
        self.plan.deinit(allocator);
    }

    pub fn legend(self: *const FrameData) []const u8 {
        return self.legend_buf[0..self.legend_len];
    }
};

pub const Controller = struct {
    pub const phase_frames: u32 = 30;
    pub const tick_count: u32 = 5;

    scene_kind: SceneKind,
    camera_mode: CameraMode,
    frame_index: u32 = 0,

    pub fn init(scene_kind: SceneKind, camera_mode: CameraMode) Controller {
        return .{ .scene_kind = scene_kind, .camera_mode = camera_mode };
    }

    pub fn nextFrame(self: *Controller, allocator: std.mem.Allocator) !FrameData {
        const cycle: u32 = tick_count * phase_frames;
        const local = self.frame_index % cycle;
        const tick = local / phase_frames;
        const phase = @as(f32, @floatFromInt(local % phase_frames)) / @as(f32, @floatFromInt(phase_frames));
        const phase_pct: u32 = ((local % phase_frames) * 100) / phase_frames;

        var scene: event_scene.ArithmeticSceneState = switch (self.scene_kind) {
            .add => try buildAddScene(allocator, tick, phase, self.camera_mode),
            .sub => try buildSubScene(allocator, tick, phase, self.camera_mode),
            .shift => try buildShiftScene(allocator, tick, phase, self.camera_mode),
            .mul => try buildMulScene(allocator, tick, phase, self.camera_mode),
        };
        defer scene.deinit(allocator);

        var out = FrameData{
            .plan = try render_plan.buildPlan(allocator, scene, layout_map.LayoutConfig{}),
            .legend_buf = undefined,
            .legend_len = 0,
        };
        out.legend_len = (try std.fmt.bufPrint(&out.legend_buf, "{s} T{d} P{d:0>2}", .{ self.scene_kind.label(), tick, phase_pct })).len;
        self.frame_index +%= 1;
        return out;
    }
};

fn buildAddScene(allocator: std.mem.Allocator, tick: u32, phase: f32, camera_mode: CameraMode) !event_scene.ArithmeticSceneState {
    const fx = fixtures.add_decimal_cascade_carry;
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try addition.addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);
    return event_scene.buildSceneAtTimeWithCameraMode(allocator, res.tape, .{ .tick = tick, .phase = phase }, camera_mode);
}

fn buildSubScene(allocator: std.mem.Allocator, tick: u32, phase: f32, camera_mode: CameraMode) !event_scene.ArithmeticSceneState {
    const fx = fixtures.sub_decimal_borrow_chain;
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try subtraction.subWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);
    return event_scene.buildSceneAtTimeWithCameraMode(allocator, res.tape, .{ .tick = tick, .phase = phase }, camera_mode);
}

fn buildShiftScene(allocator: std.mem.Allocator, tick: u32, phase: f32, camera_mode: CameraMode) !event_scene.ArithmeticSceneState {
    const fx = fixtures.shift_decimal_left_once;
    var input = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer input.deinit(allocator);
    var res = try shift.multiplyByBaseWithEvents(allocator, input);
    defer res.deinit(allocator);
    return event_scene.buildSceneAtTimeWithCameraMode(allocator, res.tape, .{ .tick = tick, .phase = phase }, camera_mode);
}

fn buildMulScene(allocator: std.mem.Allocator, tick: u32, phase: f32, camera_mode: CameraMode) !event_scene.ArithmeticSceneState {
    const fx = fixtures.mul_base60_carry;
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);
    var res = try multiplication.multiplyWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);
    return event_scene.buildSceneAtTimeWithCameraMode(allocator, res.tape, .{ .tick = tick, .phase = phase }, camera_mode);
}
