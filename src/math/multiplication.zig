const std = @import("std");
const number = @import("number.zig");
const event = @import("../events/event.zig");
const tape = @import("../events/tape.zig");
const fixtures = @import("../tests/fixtures.zig");
const ta = @import("../tests/tape_assert.zig");

pub const MulResult = struct {
    result: number.DigitNumber,
    tape: tape.EventTape,

    pub fn deinit(self: MulResult, allocator: std.mem.Allocator) void {
        self.result.deinit(allocator);
        self.tape.deinit(allocator);
    }
};

pub fn multiplyWithEvents(allocator: std.mem.Allocator, lhs: number.DigitNumber, rhs: number.DigitNumber) !MulResult {
    try lhs.validate();
    try rhs.validate();
    if (lhs.base != rhs.base) return error.BaseMismatch;

    const base: u32 = lhs.base;

    if ((lhs.digits.len == 1 and lhs.digits[0] == 0) or (rhs.digits.len == 1 and rhs.digits[0] == 0)) {
        const d = try allocator.alloc(u8, 1);
        d[0] = 0;
        var zero_events = try std.ArrayList(event.Event).initCapacity(allocator, 2);
        defer zero_events.deinit(allocator);
        try zero_events.append(allocator, .{
            .time = .{ .tick = 0, .substep = 0 },
            .kind = .digit_settle,
            .column = 0,
            .value = 0,
        });
        try zero_events.append(allocator, .{
            .time = .{ .tick = 1, .substep = 99 },
            .kind = .result_finalize,
            .column = 0,
            .value = 0,
        });
        return .{
            .result = .{ .base = lhs.base, .digits = d },
            .tape = .{ .events = try zero_events.toOwnedSlice(allocator) },
        };
    }

    const out_len = lhs.digits.len + rhs.digits.len;
    const out = try allocator.alloc(u8, out_len);
    errdefer allocator.free(out);
    @memset(out, 0);

    var ev = try std.ArrayList(event.Event).initCapacity(allocator, lhs.digits.len * rhs.digits.len * 4 + 8);
    defer ev.deinit(allocator);
    var tick: u32 = 0;

    var i: usize = 0;
    while (i < lhs.digits.len) : (i += 1) {
        try ev.append(allocator, .{
            .time = .{ .tick = tick, .substep = 0 },
            .kind = .partial_row_start,
            .column = @as(u16, @intCast(i)),
            .value = lhs.digits[i],
            .target_column = @as(u16, @intCast(i + rhs.digits.len - 1)),
        });
        var carry: u32 = 0;
        var j: usize = 0;
        while (j < rhs.digits.len) : (j += 1) {
            const col = i + j;
            const l = @as(u32, lhs.digits[i]);
            const r = @as(u32, rhs.digits[j]);
            const prod = l * r;

            try ev.append(allocator, .{
                .time = .{ .tick = tick, .substep = 0 },
                .kind = .digit_place,
                .column = @as(u16, @intCast(col)),
                .value = @as(u16, @intCast(prod)),
            });

            const s = @as(u32, out[col]) + prod + carry;
            out[col] = @as(u8, @intCast(s % base));

            try ev.append(allocator, .{
                .time = .{ .tick = tick, .substep = 1 },
                .kind = .digit_settle,
                .column = @as(u16, @intCast(col)),
                .value = out[col],
            });

            const next_carry = s / base;
            if (next_carry != 0) {
                try ev.append(allocator, .{
                    .time = .{ .tick = tick, .substep = 2 },
                    .kind = .column_overflow,
                    .column = @as(u16, @intCast(col)),
                    .value = @as(u16, @intCast(s)),
                });
                try ev.append(allocator, .{
                    .time = .{ .tick = tick, .substep = 3 },
                    .kind = .carry_emit,
                    .column = @as(u16, @intCast(col)),
                    .value = @as(u16, @intCast(next_carry)),
                    .carry_to_column = @as(u16, @intCast(col + 1)),
                });
            }

            carry = next_carry;
            tick += 1;
        }

        var col = i + rhs.digits.len;
        while (carry != 0) : (col += 1) {
            const s = @as(u32, out[col]) + carry;
            out[col] = @as(u8, @intCast(s % base));
            carry = s / base;

            try ev.append(allocator, .{
                .time = .{ .tick = tick, .substep = 0 },
                .kind = .digit_settle,
                .column = @as(u16, @intCast(col)),
                .value = out[col],
            });
            if (carry != 0) {
                try ev.append(allocator, .{
                    .time = .{ .tick = tick, .substep = 1 },
                    .kind = .carry_emit,
                    .column = @as(u16, @intCast(col)),
                    .value = @as(u16, @intCast(carry)),
                    .carry_to_column = @as(u16, @intCast(col + 1)),
                });
            }
            tick += 1;
        }

        try ev.append(allocator, .{
            .time = .{ .tick = tick, .substep = 0 },
            .kind = .partial_row_complete,
            .column = @as(u16, @intCast(i)),
            .value = lhs.digits[i],
            .target_column = @as(u16, @intCast(i + rhs.digits.len - 1)),
        });
    }

    var result = number.DigitNumber{ .base = lhs.base, .digits = out };
    try result.normalize(allocator);

    try ev.append(allocator, .{
        .time = .{ .tick = tick, .substep = 99 },
        .kind = .result_finalize,
        .column = 0,
        .value = 0,
    });

    return .{
        .result = result,
        .tape = .{ .events = try ev.toOwnedSlice(allocator) },
    };
}

test "mul_base60_basic fixture" {
    const allocator = std.testing.allocator;
    const fx = fixtures.mul_base60_basic;
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);

    var res = try multiplyWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
}

test "mul_base60_carry fixture" {
    const allocator = std.testing.allocator;
    const fx = fixtures.mul_base60_carry;
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);

    var res = try multiplyWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
    try std.testing.expect(ta.countKind(res.tape, .carry_emit) >= 1);
    try ta.expectKindCount(res.tape, .partial_row_start, lhs.digits.len);
    try ta.expectKindCount(res.tape, .partial_row_complete, lhs.digits.len);
}

test "mul partial-row events are paired in order" {
    const allocator = std.testing.allocator;
    const fx = fixtures.mul_base60_carry;
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);

    var res = try multiplyWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    const row_start_seen = try allocator.alloc(bool, lhs.digits.len);
    defer allocator.free(row_start_seen);
    const row_complete_seen = try allocator.alloc(bool, lhs.digits.len);
    defer allocator.free(row_complete_seen);
    @memset(row_start_seen, false);
    @memset(row_complete_seen, false);
    for (res.tape.events) |e| {
        if (e.kind == .partial_row_start) {
            const row: usize = e.column;
            try std.testing.expect(row < lhs.digits.len);
            try std.testing.expect(!row_start_seen[row]);
            try std.testing.expect(!row_complete_seen[row]);
            row_start_seen[row] = true;
        } else if (e.kind == .partial_row_complete) {
            const row: usize = e.column;
            try std.testing.expect(row < lhs.digits.len);
            try std.testing.expect(row_start_seen[row]);
            try std.testing.expect(!row_complete_seen[row]);
            row_complete_seen[row] = true;
        }
    }

    var i: usize = 0;
    while (i < lhs.digits.len) : (i += 1) {
        try std.testing.expect(row_start_seen[i]);
        try std.testing.expect(row_complete_seen[i]);
    }
}

test "cross-base invariant: 7 * 3 keeps numeric meaning" {
    const allocator = std.testing.allocator;

    const cases = [_]u8{ 60, 16, 10, 2, 8 };
    for (cases) |base| {
        var lhs = try number.DigitNumber.fromU64(allocator, base, 7);
        defer lhs.deinit(allocator);
        var rhs = try number.DigitNumber.fromU64(allocator, base, 3);
        defer rhs.deinit(allocator);

        var res = try multiplyWithEvents(allocator, lhs, rhs);
        defer res.deinit(allocator);

        try std.testing.expectEqual(@as(u64, 21), try res.result.toU64());
        try ta.expectMonotonic(res.tape);
        try ta.expectHasFinalize(res.tape);
    }
}

test "mul fixtures for base16/base2/base8" {
    const allocator = std.testing.allocator;
    const cases = [_]fixtures.Fixture{
        fixtures.mul_base16_basic,
        fixtures.mul_base2_basic,
        fixtures.mul_base8_basic,
    };

    for (cases) |fx| {
        var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
        defer lhs.deinit(allocator);
        var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
        defer rhs.deinit(allocator);

        var res = try multiplyWithEvents(allocator, lhs, rhs);
        defer res.deinit(allocator);

        try std.testing.expectEqual(fx.expected, try res.result.toU64());
        try ta.expectMonotonic(res.tape);
        try ta.expectHasFinalize(res.tape);
    }
}
