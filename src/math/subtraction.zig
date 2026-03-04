const std = @import("std");
const number = @import("number.zig");
const event = @import("../events/event.zig");
const tape = @import("../events/tape.zig");
const fixtures = @import("../tests/fixtures.zig");
const ta = @import("../tests/tape_assert.zig");

pub const SubResult = struct {
    result: number.DigitNumber,
    tape: tape.EventTape,

    pub fn deinit(self: SubResult, allocator: std.mem.Allocator) void {
        self.result.deinit(allocator);
        self.tape.deinit(allocator);
    }
};

pub fn subWithEvents(allocator: std.mem.Allocator, lhs: number.DigitNumber, rhs: number.DigitNumber) !SubResult {
    try lhs.validate();
    try rhs.validate();
    if (lhs.base != rhs.base) return error.BaseMismatch;

    // Current product scope is u64-backed fixtures/inputs; use this check to reject
    // negative results before running the borrow pass.
    const lhs_v = try lhs.toU64();
    const rhs_v = try rhs.toU64();
    if (lhs_v < rhs_v) return error.NegativeResultNotSupported;

    const base = lhs.base;
    const max_len = @max(lhs.digits.len, rhs.digits.len);

    var out_digits = try allocator.alloc(u8, max_len);
    errdefer allocator.free(out_digits);

    var ev = try std.ArrayList(event.Event).initCapacity(allocator, 16);
    defer ev.deinit(allocator);

    var borrow: i16 = 0;
    var col: usize = 0;
    while (col < max_len) : (col += 1) {
        const l_raw: i16 = if (col < lhs.digits.len) lhs.digits[col] else 0;
        const r_raw: i16 = if (col < rhs.digits.len) rhs.digits[col] else 0;

        try ev.append(allocator, .{
            .time = .{ .tick = @as(u32, @intCast(col)), .substep = 0 },
            .kind = .digit_place,
            .column = @as(u16, @intCast(col)),
            .value = @as(u16, @intCast(l_raw)),
        });

        var v = l_raw - borrow - r_raw;
        if (v < 0) {
            try ev.append(allocator, .{
                .time = .{ .tick = @as(u32, @intCast(col)), .substep = 1 },
                .kind = .borrow_request,
                .column = @as(u16, @intCast(col)),
                .value = 1,
                .borrow_from_column = @as(u16, @intCast(col + 1)),
            });
            v += base;
            borrow = 1;
            try ev.append(allocator, .{
                .time = .{ .tick = @as(u32, @intCast(col)), .substep = 2 },
                .kind = .borrow_expand,
                .column = @as(u16, @intCast(col + 1)),
                .value = base,
            });
        } else {
            borrow = 0;
        }

        out_digits[col] = @as(u8, @intCast(v));

        try ev.append(allocator, .{
            .time = .{ .tick = @as(u32, @intCast(col)), .substep = 3 },
            .kind = .digit_settle,
            .column = @as(u16, @intCast(col)),
            .value = out_digits[col],
        });
    }

    var out = number.DigitNumber{ .base = base, .digits = out_digits };
    try out.normalize(allocator);

    try ev.append(allocator, .{
        .time = .{ .tick = @as(u32, @intCast(max_len + 1)), .substep = 99 },
        .kind = .result_finalize,
        .column = 0,
        .value = 0,
    });

    return .{
        .result = out,
        .tape = .{ .events = try ev.toOwnedSlice(allocator) },
    };
}

test "sub_decimal_borrow_once fixture" {
    const allocator = std.testing.allocator;
    const fx = fixtures.sub_decimal_borrow_once;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);

    var res = try subWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
    try ta.expectKindCount(res.tape, .borrow_request, 1);
    try ta.expectKindCount(res.tape, .borrow_expand, 1);
}

test "sub_decimal_borrow_chain fixture" {
    const allocator = std.testing.allocator;
    const fx = fixtures.sub_decimal_borrow_chain;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);

    var res = try subWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
    try ta.expectKindCount(res.tape, .borrow_request, 3);
    try ta.expectKindCount(res.tape, .borrow_expand, 3);
}

test "sub_base60_borrow_chain fixture" {
    const allocator = std.testing.allocator;
    const fx = fixtures.sub_base60_borrow_chain;

    var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
    defer rhs.deinit(allocator);

    var res = try subWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(fx.expected, try res.result.toU64());
    try ta.expectMonotonic(res.tape);
    try ta.expectHasFinalize(res.tape);
    try ta.expectKindCount(res.tape, .borrow_request, 2);
    try ta.expectKindCount(res.tape, .borrow_expand, 2);
}

test "cross-base invariant: 8 - 1 keeps numeric meaning with expected borrow profile" {
    const allocator = std.testing.allocator;

    const Case = struct {
        base: u8,
        expected_borrows: usize,
    };
    const cases = [_]Case{
        .{ .base = 60, .expected_borrows = 0 },
        .{ .base = 16, .expected_borrows = 0 },
        .{ .base = 10, .expected_borrows = 0 },
        .{ .base = 8, .expected_borrows = 1 },
        .{ .base = 2, .expected_borrows = 3 },
    };

    for (cases) |c| {
        var lhs = try number.DigitNumber.fromU64(allocator, c.base, 8);
        defer lhs.deinit(allocator);
        var rhs = try number.DigitNumber.fromU64(allocator, c.base, 1);
        defer rhs.deinit(allocator);

        var res = try subWithEvents(allocator, lhs, rhs);
        defer res.deinit(allocator);

        try std.testing.expectEqual(@as(u64, 7), try res.result.toU64());
        try ta.expectMonotonic(res.tape);
        try ta.expectHasFinalize(res.tape);
        try ta.expectKindCount(res.tape, .borrow_request, c.expected_borrows);
        try ta.expectKindCount(res.tape, .borrow_expand, c.expected_borrows);
    }
}
