const std = @import("std");
const number = @import("number.zig");
const event = @import("../events/event.zig");
const tape = @import("../events/tape.zig");

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

test "52 - 7 base10 -> 45 with one borrow" {
    const allocator = std.testing.allocator;
    var lhs = try number.DigitNumber.fromU64(allocator, 10, 52);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, 10, 7);
    defer rhs.deinit(allocator);

    var res = try subWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(@as(u64, 45), try res.result.toU64());
    try std.testing.expect(res.tape.isMonotonic());

    var borrow_count: usize = 0;
    var has_finalize = false;
    for (res.tape.events) |e| {
        if (e.kind == .borrow_request) borrow_count += 1;
        if (e.kind == .result_finalize) has_finalize = true;
    }
    try std.testing.expectEqual(@as(usize, 1), borrow_count);
    try std.testing.expect(has_finalize);
}

test "1000 - 1 base10 -> 999 with borrow chain" {
    const allocator = std.testing.allocator;
    var lhs = try number.DigitNumber.fromU64(allocator, 10, 1000);
    defer lhs.deinit(allocator);
    var rhs = try number.DigitNumber.fromU64(allocator, 10, 1);
    defer rhs.deinit(allocator);

    var res = try subWithEvents(allocator, lhs, rhs);
    defer res.deinit(allocator);

    try std.testing.expectEqual(@as(u64, 999), try res.result.toU64());

    var borrow_count: usize = 0;
    for (res.tape.events) |e| {
        if (e.kind == .borrow_request) borrow_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), borrow_count);
}
