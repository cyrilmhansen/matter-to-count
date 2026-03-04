const std = @import("std");
const number = @import("number.zig");
const event = @import("../events/event.zig");
const tape = @import("../events/tape.zig");
const fixtures = @import("../tests/fixtures.zig");
const ta = @import("../tests/tape_assert.zig");

pub const ShiftResult = struct {
    result: number.DigitNumber,
    tape: tape.EventTape,

    pub fn deinit(self: ShiftResult, allocator: std.mem.Allocator) void {
        self.result.deinit(allocator);
        self.tape.deinit(allocator);
    }
};

pub fn multiplyByBaseWithEvents(allocator: std.mem.Allocator, input: number.DigitNumber) !ShiftResult {
    try input.validate();

    var ev = try std.ArrayList(event.Event).initCapacity(allocator, 8 + input.digits.len * 2);
    defer ev.deinit(allocator);

    // Zero stays zero after shift.
    if (input.digits.len == 1 and input.digits[0] == 0) {
        const d = try allocator.alloc(u8, 1);
        d[0] = 0;
        try ev.append(allocator, .{
            .time = .{ .tick = 0, .substep = 0 },
            .kind = .shift_complete,
            .column = 0,
            .value = 0,
        });
        try ev.append(allocator, .{
            .time = .{ .tick = 1, .substep = 99 },
            .kind = .result_finalize,
            .column = 0,
            .value = 0,
        });
        return .{ .result = .{ .base = input.base, .digits = d }, .tape = .{ .events = try ev.toOwnedSlice(allocator) } };
    }

    const out = try allocator.alloc(u8, input.digits.len + 1);
    out[0] = 0;
    @memcpy(out[1..], input.digits);

    var i: usize = 0;
    while (i < input.digits.len) : (i += 1) {
        try ev.append(allocator, .{
            .time = .{ .tick = @as(u32, @intCast(i)), .substep = 0 },
            .kind = .shift_start,
            .column = @as(u16, @intCast(i)),
            .value = input.digits[i],
            .target_column = @as(u16, @intCast(i + 1)),
        });
        try ev.append(allocator, .{
            .time = .{ .tick = @as(u32, @intCast(i)), .substep = 1 },
            .kind = .shift_complete,
            .column = @as(u16, @intCast(i + 1)),
            .value = input.digits[i],
        });
    }

    try ev.append(allocator, .{
        .time = .{ .tick = @as(u32, @intCast(input.digits.len + 1)), .substep = 99 },
        .kind = .result_finalize,
        .column = 0,
        .value = 0,
    });

    return .{
        .result = .{ .base = input.base, .digits = out },
        .tape = .{ .events = try ev.toOwnedSlice(allocator) },
    };
}

test "shift_decimal_left_once fixture" {
    const allocator = std.testing.allocator;
    const fx = fixtures.shift_decimal_left_once;

    var n = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer n.deinit(allocator);

    var res = try multiplyByBaseWithEvents(allocator, n);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
    try ta.expectKindCount(res.tape, .shift_start, 2);
    try ta.expectKindCount(res.tape, .shift_complete, 2);
}

test "shift_binary_left_once fixture" {
    const allocator = std.testing.allocator;
    const fx = fixtures.shift_binary_left_once;

    var n = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer n.deinit(allocator);

    var res = try multiplyByBaseWithEvents(allocator, n);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
    try ta.expectKindCount(res.tape, .shift_start, 4);
    try ta.expectKindCount(res.tape, .shift_complete, 4);
}

test "shift_base60_left_once fixture" {
    const allocator = std.testing.allocator;
    const fx = fixtures.shift_base60_left_once;

    var n = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer n.deinit(allocator);

    var res = try multiplyByBaseWithEvents(allocator, n);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
    try ta.expectKindCount(res.tape, .shift_start, 2);
    try ta.expectKindCount(res.tape, .shift_complete, 2);
}

test "cross-base invariant: multiply by base keeps numeric meaning and per-digit shift events" {
    const allocator = std.testing.allocator;

    const Case = struct {
        base: u8,
    };
    const cases = [_]Case{
        .{ .base = 60 },
        .{ .base = 16 },
        .{ .base = 10 },
        .{ .base = 2 },
        .{ .base = 8 },
    };

    const input_value: u64 = 7;
    for (cases) |c| {
        var n = try number.DigitNumber.fromU64(allocator, c.base, input_value);
        defer n.deinit(allocator);

        const expected_shift_events = n.digits.len;
        var res = try multiplyByBaseWithEvents(allocator, n);
        defer res.deinit(allocator);

        try std.testing.expectEqual(input_value * c.base, try res.result.toU64());
        try ta.expectMonotonic(res.tape);
        try ta.expectHasFinalize(res.tape);
        try ta.expectKindCount(res.tape, .shift_start, expected_shift_events);
        try ta.expectKindCount(res.tape, .shift_complete, expected_shift_events);
    }
}
