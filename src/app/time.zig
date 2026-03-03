const std = @import("std");

pub const FixedClock = struct {
    sim_dt: f32,
    sim_time: f32,
    frame_index: u64,

    pub fn init(sim_dt: f32) FixedClock {
        std.debug.assert(sim_dt > 0);
        return .{ .sim_dt = sim_dt, .sim_time = 0, .frame_index = 0 };
    }

    pub fn tick(self: *FixedClock) void {
        self.frame_index += 1;
        self.sim_time += self.sim_dt;
    }
};

test "fixed clock advances deterministically" {
    var c = FixedClock.init(1.0 / 60.0);
    var i: usize = 0;
    while (i < 120) : (i += 1) c.tick();
    try std.testing.expectEqual(@as(u64, 120), c.frame_index);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), c.sim_time, 0.0001);
}
