const builtin = @import("builtin");
const win = @import("win_types.zig");

pub const windows = builtin.os.tag == .windows;

fn guid(
    data1: u32,
    data2: u16,
    data3: u16,
    data4: [8]u8,
) win.GUID {
    return .{
        .Data1 = data1,
        .Data2 = data2,
        .Data3 = data3,
        .Data4 = data4,
    };
}

// Values from Microsoft SDK interface definitions (dxgi/d3d11 headers).
pub const IID_IDXGIFactory2 = if (windows)
    guid(0x50c83a1c, 0xe072, 0x4c48, .{ 0x87, 0xb0, 0x36, 0x30, 0xfa, 0x36, 0xa6, 0xd0 })
else
    struct {};

pub const IID_IDXGIDevice = if (windows)
    guid(0x54ec77fa, 0x1377, 0x44e6, .{ 0x8c, 0x32, 0x88, 0xfd, 0x5f, 0x44, 0xc8, 0x4c })
else
    struct {};

pub const IID_ID3D11Texture2D = if (windows)
    guid(0x6f15aaf2, 0xd208, 0x4e89, .{ 0x9a, 0xb4, 0x48, 0x95, 0x35, 0xd3, 0x4f, 0x9c })
else
    struct {};
