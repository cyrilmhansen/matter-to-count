const builtin = @import("builtin");
const win = @import("win_types.zig");
const win32 = @import("window.zig");

// Minimal manual COM declaration used to avoid depending on dxgi1_2.h for the
// stereo capability probe path.
pub const IDXGIFactory2 = if (builtin.os.tag == .windows) extern struct {
    lpVtbl: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: *const fn (self: *IDXGIFactory2, riid: *const win.GUID, out: *?*anyopaque) callconv(.winapi) win.HRESULT,
        AddRef: *const fn (self: *IDXGIFactory2) callconv(.winapi) win.UINT,
        Release: *const fn (self: *IDXGIFactory2) callconv(.winapi) win.UINT,

        // IDXGIObject
        SetPrivateData: *const anyopaque,
        SetPrivateDataInterface: *const anyopaque,
        GetPrivateData: *const anyopaque,
        GetParent: *const anyopaque,

        // IDXGIFactory
        EnumAdapters: *const anyopaque,
        MakeWindowAssociation: *const anyopaque,
        GetWindowAssociation: *const anyopaque,
        CreateSwapChain: *const anyopaque,
        CreateSoftwareAdapter: *const anyopaque,

        // IDXGIFactory1
        EnumAdapters1: *const anyopaque,
        IsCurrent: *const anyopaque,

        // IDXGIFactory2
        IsWindowedStereoEnabled: *const fn (self: *IDXGIFactory2) callconv(.winapi) win.BOOL,
    };
} else struct {};

pub const DXGI_FORMAT = u32;
pub const DXGI_FORMAT_UNKNOWN: DXGI_FORMAT = 0;
pub const DXGI_FORMAT_R32G32B32A32_FLOAT: DXGI_FORMAT = 2;
pub const DXGI_FORMAT_R32G32B32_FLOAT: DXGI_FORMAT = 6;
pub const DXGI_FORMAT_R8G8B8A8_UNORM: DXGI_FORMAT = 28;

pub const DXGI_MODE_SCANLINE_ORDER = u32;
pub const DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED: DXGI_MODE_SCANLINE_ORDER = 0;

pub const DXGI_MODE_SCALING = u32;
pub const DXGI_MODE_SCALING_UNSPECIFIED: DXGI_MODE_SCALING = 0;

pub const DXGI_SWAP_EFFECT = u32;
pub const DXGI_SWAP_EFFECT_DISCARD: DXGI_SWAP_EFFECT = 0;

pub const DXGI_USAGE_RENDER_TARGET_OUTPUT: win.UINT = 0x00000020;

// Minimal manual DXGI structs for swap-chain creation.
pub const DXGI_RATIONAL = if (builtin.os.tag == .windows) extern struct {
    Numerator: win.UINT,
    Denominator: win.UINT,
} else struct {};

pub const DXGI_MODE_DESC = if (builtin.os.tag == .windows) extern struct {
    Width: win.UINT,
    Height: win.UINT,
    RefreshRate: DXGI_RATIONAL,
    Format: DXGI_FORMAT,
    ScanlineOrdering: DXGI_MODE_SCANLINE_ORDER,
    Scaling: DXGI_MODE_SCALING,
} else struct {};

pub const DXGI_SAMPLE_DESC = if (builtin.os.tag == .windows) extern struct {
    Count: win.UINT,
    Quality: win.UINT,
} else struct {};

pub const DXGI_SWAP_CHAIN_DESC = if (builtin.os.tag == .windows) extern struct {
    BufferDesc: DXGI_MODE_DESC,
    SampleDesc: DXGI_SAMPLE_DESC,
    BufferUsage: win.UINT,
    BufferCount: win.UINT,
    OutputWindow: win.HWND,
    Windowed: win.BOOL,
    SwapEffect: DXGI_SWAP_EFFECT,
    Flags: win.UINT,
} else struct {};

fn asCHwnd(hwnd: win32.HWND) win.HWND {
    return hwnd;
}

pub fn makeSwapChainDesc(hwnd: win32.HWND, width: u32, height: u32) DXGI_SWAP_CHAIN_DESC {
    return .{
        .BufferDesc = .{
            .Width = width,
            .Height = height,
            .RefreshRate = .{ .Numerator = 60, .Denominator = 1 },
            .Format = DXGI_FORMAT_R8G8B8A8_UNORM,
            .ScanlineOrdering = DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED,
            .Scaling = DXGI_MODE_SCALING_UNSPECIFIED,
        },
        .SampleDesc = .{
            .Count = 1,
            .Quality = 0,
        },
        .BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT,
        .BufferCount = 1,
        .OutputWindow = asCHwnd(hwnd),
        .Windowed = win.TRUE,
        .SwapEffect = DXGI_SWAP_EFFECT_DISCARD,
        .Flags = 0,
    };
}
