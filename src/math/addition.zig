const std = @import("std");
const number = @import("number.zig");
const event = @import("../events/event.zig");
const tape = @import("../events/tape.zig");

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
    var lhs = try number.DigitNumber.fromU64(allocator, 10, 17);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, 10, 8);
    defer rhs.deinit(allocator);

    var res = try addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(@as(u64, 25), try res.result.toU64());
    try std.testing.expect(res.tape.isMonotonic());

    var carry_count: usize = 0;
    var has_finalize = false;
    for (res.tape.events) |e| {
        if (e.kind == .carry_emit) carry_count += 1;
        if (e.kind == .result_finalize) has_finalize = true;
    }
    try std.testing.expectEqual(@as(usize, 1), carry_count);
    try std.testing.expect(has_finalize);
}

test "199 + 7 base10 -> 206 with cascade carries" {
    const allocator = std.testing.allocator;
    var lhs = try number.DigitNumber.fromU64(allocator, 10, 199);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, 10, 7);
    defer rhs.deinit(allocator);

    var res = try addWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(@as(u64, 206), try res.result.toU64());

    var carry_count: usize = 0;
    for (res.tape.events) |e| {
        if (e.kind == .carry_emit) carry_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), carry_count);
}
