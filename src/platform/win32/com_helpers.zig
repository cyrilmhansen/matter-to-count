const win = @import("win_types.zig");

pub inline fn cast(comptime T: type, p: anytype) T {
    return @ptrFromInt(@intFromPtr(p));
}

pub inline fn release(obj: anytype) void {
    const rel = obj.lpVtbl.*.Release;
    switch (@typeInfo(@TypeOf(rel))) {
        .optional => _ = rel.?(obj),
        else => _ = rel(obj),
    }
}

pub inline fn queryInterface(obj: anytype, riid: *const win.GUID, out: *?*anyopaque) win.HRESULT {
    const qi = obj.lpVtbl.*.QueryInterface;
    return switch (@typeInfo(@TypeOf(qi))) {
        .optional => qi.?(obj, riid, out),
        else => qi(obj, riid, out),
    };
}
