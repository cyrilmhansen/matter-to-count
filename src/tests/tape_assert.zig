const std = @import("std");
const event = @import("../events/event.zig");
const tape = @import("../events/tape.zig");

pub fn expectMonotonic(t: tape.EventTape) !void {
    try std.testing.expect(t.isMonotonic());
}

pub fn expectHasFinalize(t: tape.EventTape) !void {
    var has_finalize = false;
    for (t.events) |e| {
        if (e.kind == .result_finalize) {
            has_finalize = true;
            break;
        }
    }
    try std.testing.expect(has_finalize);
}

pub fn countKind(t: tape.EventTape, k: event.EventKind) usize {
    var n: usize = 0;
    for (t.events) |e| {
        if (e.kind == k) n += 1;
    }
    return n;
}

pub fn expectKindCount(t: tape.EventTape, k: event.EventKind, expected: usize) !void {
    try std.testing.expectEqual(expected, countKind(t, k));
}
