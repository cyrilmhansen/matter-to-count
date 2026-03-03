const std = @import("std");

pub fn info(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}

pub fn err(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("ERROR: " ++ fmt ++ "\n", args);
}
