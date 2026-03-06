const builtin = @import("builtin");
const win = @import("win_types.zig");

pub const ID3DBlob = if (builtin.os.tag == .windows) extern struct {
    lpVtbl: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: *const fn (self: *ID3DBlob, riid: *const win.GUID, out: *?*anyopaque) callconv(.winapi) win.HRESULT,
        AddRef: *const fn (self: *ID3DBlob) callconv(.winapi) win.UINT,
        Release: *const fn (self: *ID3DBlob) callconv(.winapi) win.UINT,
        GetBufferPointer: *const fn (self: *ID3DBlob) callconv(.winapi) *anyopaque,
        GetBufferSize: *const fn (self: *ID3DBlob) callconv(.winapi) usize,
    };
} else struct {};

extern "d3dcompiler_47" fn D3DCompile(
    src_data: *const anyopaque,
    src_data_size: usize,
    source_name: ?[*:0]const u8,
    defines: ?*const anyopaque,
    include: ?*const anyopaque,
    entrypoint: [*:0]const u8,
    target: [*:0]const u8,
    flags1: win.UINT,
    flags2: win.UINT,
    code: *?*ID3DBlob,
    error_msgs: *?*ID3DBlob,
) callconv(.winapi) win.HRESULT;

pub fn compile(
    source: []const u8,
    entry: [*:0]const u8,
    target: [*:0]const u8,
    code: *?*ID3DBlob,
    errors: *?*ID3DBlob,
) win.HRESULT {
    return D3DCompile(
        source.ptr,
        source.len,
        null,
        null,
        null,
        entry,
        target,
        0,
        0,
        code,
        errors,
    );
}
