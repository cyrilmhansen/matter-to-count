const std = @import("std");
const event = @import("event.zig");

pub const EventTape = struct {
    events: []event.Event,

    pub fn deinit(self: EventTape, allocator: std.mem.Allocator) void {
        allocator.free(self.events);
    }

    pub fn isMonotonic(self: EventTape) bool {
        if (self.events.len <= 1) return true;
        var i: usize = 1;
        while (i < self.events.len) : (i += 1) {
            const a = self.events[i - 1].time;
            const b = self.events[i].time;
            if (b.tick < a.tick) return false;
            if (b.tick == a.tick and b.substep < a.substep) return false;
        }
        return true;
    }
};

test "monotonic check" {
    var arr = [_]event.Event{
        .{ .time = .{ .tick = 0, .substep = 0 }, .kind = .digit_place, .column = 0, .value = 1 },
        .{ .time = .{ .tick = 0, .substep = 1 }, .kind = .digit_settle, .column = 0, .value = 1 },
    };
    const t = EventTape{ .events = arr[0..] };
    try std.testing.expect(t.isMonotonic());
}
