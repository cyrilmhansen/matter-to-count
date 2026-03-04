const std = @import("std");
const number = @import("number.zig");
const event = @import("../events/event.zig");
const tape = @import("../events/tape.zig");
const fixtures = @import("../tests/fixtures.zig");
const ta = @import("../tests/tape_assert.zig");

pub const AddResult = struct {
    result: number.DigitNumber,
    tape: tape.EventTape,

    pub fn deinit(self: AddResult, allocator: std.mem.Allocator) void {
        self.result.deinit(allocator);
        self.tape.deinit(allocator);
    }
};

pub fn addWithEvents(allocator: std.mem.Allocator, lhs: number.DigitNumber, rhs: number.DigitNumber) !AddResult {
    try lhs.validate();
    try rhs.validate();
    if (lhs.base != rhs.base) return error.BaseMismatch;

    const base = lhs.base;
    const max_len = @max(lhs.digits.len, rhs.digits.len);

    var out_digits = try allocator.alloc(u8, max_len + 1);
    errdefer allocator.free(out_digits);

    var ev = try std.ArrayList(event.Event).initCapacity(allocator, 16);
    defer ev.deinit(allocator);

    var carry: u16 = 0;
    var col: usize = 0;
    while (col < max_len) : (col += 1) {
        const l: u16 = if (col < lhs.digits.len) lhs.digits[col] else 0;
        const r: u16 = if (col < rhs.digits.len) rhs.digits[col] else 0;

        try ev.append(allocator, .{
            .time = .{ .tick = @as(u32, @intCast(col)), .substep = 0 },
            .kind = .digit_place,
            .column = @as(u16, @intCast(col)),
            .value = l + r,
        });

        const s: u16 = l + r + carry;
        out_digits[col] = @as(u8, @intCast(s % base));

        try ev.append(allocator, .{
            .time = .{ .tick = @as(u32, @intCast(col)), .substep = 1 },
            .kind = .digit_settle,
            .column = @as(u16, @intCast(col)),
            .value = out_digits[col],
        });

        if (s >= base) {
            try ev.append(allocator, .{
                .time = .{ .tick = @as(u32, @intCast(col)), .substep = 2 },
                .kind = .column_overflow,
                .column = @as(u16, @intCast(col)),
                .value = s,
            });
            try ev.append(allocator, .{
                .time = .{ .tick = @as(u32, @intCast(col)), .substep = 3 },
                .kind = .carry_emit,
                .column = @as(u16, @intCast(col)),
                .value = 1,
                .carry_to_column = @as(u16, @intCast(col + 1)),
            });
            try ev.append(allocator, .{
                .time = .{ .tick = @as(u32, @intCast(col + 1)), .substep = 0 },
                .kind = .carry_receive,
                .column = @as(u16, @intCast(col + 1)),
                .value = 1,
            });
            carry = 1;
        } else {
            carry = 0;
        }
    }

    var out_len = max_len;
    if (carry != 0) {
        out_digits[max_len] = @as(u8, @intCast(carry));
        out_len = max_len + 1;
    }

    const result_digits = try allocator.alloc(u8, out_len);
    @memcpy(result_digits, out_digits[0..out_len]);
    allocator.free(out_digits);

    var result = number.DigitNumber{ .base = base, .digits = result_digits };
    try result.normalize(allocator);

    try ev.append(allocator, .{
        .time = .{ .tick = @as(u32, @intCast(out_len)), .substep = 99 },
        .kind = .result_finalize,
        .column = 0,
        .value = 0,
    });

    return .{
        .result = result,
        .tape = .{ .events = try ev.toOwnedSlice(allocator) },
    };
}

test "17 + 8 base10 -> 25 with carry events" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_decimal_single_carry;
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);

    var res = try addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
    try ta.expectKindCount(res.tape, .carry_emit, 1);
}

test "199 + 7 base10 -> 206 with cascade carries" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_decimal_cascade_carry;
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);

    var res = try addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
    try ta.expectKindCount(res.tape, .carry_emit, 2);
}

test "base60 single carry fixture" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_base60_single_carry;
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);

    var res = try addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
    try ta.expectKindCount(res.tape, .carry_emit, 1);
}

test "base60 cascade carry fixture" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_base60_cascade_carry;
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);

    var res = try addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
    try ta.expectKindCount(res.tape, .carry_emit, 2);
}

test "base16 single carry fixture" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_hex_single_carry;
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);

    var res = try addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
    try ta.expectKindCount(res.tape, .carry_emit, 1);
}

test "base2 cascade carry fixture" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_binary_cascade_carry;
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);

    var res = try addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
    try ta.expectKindCount(res.tape, .carry_emit, 3);
}

test "base8 single carry fixture" {
    const allocator = std.testing.allocator;
    const fx = fixtures.add_octal_single_carry;
    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);

    var res = try addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
    try ta.expectKindCount(res.tape, .carry_emit, 2);
}

test "cross-base invariant: 7 + 1 keeps numeric meaning with expected carry profile" {
    const allocator = std.testing.allocator;

    const Case = struct {
        base: u8,
        expected_carries: usize,
    };
    const cases = [_]Case{
        .{ .base = 60, .expected_carries = 0 },
        .{ .base = 16, .expected_carries = 0 },
        .{ .base = 10, .expected_carries = 0 },
        .{ .base = 8, .expected_carries = 1 },
        .{ .base = 2, .expected_carries = 3 },
    };

    for (cases) |c| {
        var lhs = try number.DigitNumber.fromU64(allocator, c.base, 7);
        defer lhs.deinit(allocator);
        var rhs = try number.DigitNumber.fromU64(allocator, c.base, 1);
        defer rhs.deinit(allocator);

        var res = try addWithEvents(allocator, lhs, rhs);
        defer res.deinit(allocator);

        try std.testing.expectEqual(@as(u64, 8), try res.result.toU64());
        try ta.expectMonotonic(res.tape);
        try ta.expectHasFinalize(res.tape);
        try ta.expectKindCount(res.tape, .carry_emit, c.expected_carries);
        try ta.expectKindCount(res.tape, .carry_receive, c.expected_carries);
    }
}
