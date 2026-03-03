const std = @import("std");

pub const DigitNumber = struct {
    base: u8,
    // Least-significant digit first.
    digits: []u8,

    pub fn deinit(self: DigitNumber, allocator: std.mem.Allocator) void {
        allocator.free(self.digits);
    }

    pub fn clone(self: DigitNumber, allocator: std.mem.Allocator) !DigitNumber {
        const d = try allocator.dupe(u8, self.digits);
        return .{ .base = self.base, .digits = d };
    }

    pub fn normalize(self: *DigitNumber, allocator: std.mem.Allocator) !void {
        var n = self.digits.len;
        while (n > 1 and self.digits[n - 1] == 0) : (n -= 1) {}
        if (n == self.digits.len) return;
        const out = try allocator.alloc(u8, n);
        @memcpy(out, self.digits[0..n]);
        allocator.free(self.digits);
        self.digits = out;
    }

    pub fn validate(self: DigitNumber) !void {
        if (self.base < 2) return error.InvalidBase;
        for (self.digits) |d| {
            if (d >= self.base) return error.InvalidDigit;
        }
    }

    pub fn fromU64(allocator: std.mem.Allocator, base: u8, value: u64) !DigitNumber {
        if (base < 2) return error.InvalidBase;
        if (value == 0) {
            const d = try allocator.alloc(u8, 1);
            d[0] = 0;
            return .{ .base = base, .digits = d };
        }

        var n: usize = 0;
        var c = value;
        while (c > 0) : (c /= base) n += 1;

        const d = try allocator.alloc(u8, n);
        var v = value;
        var i: usize = 0;
        while (i < n) : (i += 1) {
            d[i] = @as(u8, @intCast(v % base));
            v /= base;
        }
        return .{ .base = base, .digits = d };
    }

    pub fn toU64(self: DigitNumber) !u64 {
        try self.validate();
        var out: u64 = 0;
        var mul: u64 = 1;
        for (self.digits) |d| {
            out = std.math.add(u64, out, std.math.mul(u64, mul, d) catch return error.Overflow) catch return error.Overflow;
            mul = std.math.mul(u64, mul, self.base) catch return error.Overflow;
        }
        return out;
    }
};

test "from and to u64 roundtrip" {
    const allocator = std.testing.allocator;
    var n = try DigitNumber.fromU64(allocator, 10, 206);
    defer n.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 10), n.base);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 6, 0, 2 }, n.digits);
    try std.testing.expectEqual(@as(u64, 206), try n.toU64());
}
