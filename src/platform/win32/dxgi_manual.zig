const builtin = @import("builtin");
const d3d_c = @import("d3d_c.zig");
const c = d3d_c.c;
const win32 = @import("window.zig");

// Minimal manual COM declaration used to avoid depending on dxgi1_2.h for the
// stereo capability probe path.
pub const IDXGIFactory2 = if (builtin.os.tag == .windows) extern struct {
    lpVtbl: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: *const fn (self: *IDXGIFactory2, riid: *const c.GUID, out: *?*anyopaque) callconv(.winapi) c.HRESULT,
        AddRef: *const fn (self: *IDXGIFactory2) callconv(.winapi) c.UINT,
        Release: *const fn (self: *IDXGIFactory2) callconv(.winapi) c.UINT,

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
        IsWindowedStereoEnabled: *const fn (self: *IDXGIFactory2) callconv(.winapi) c.BOOL,
    };
} else struct {};

// Minimal manual DXGI structs for swap-chain creation.
pub const DXGI_RATIONAL = if (builtin.os.tag == .windows) extern struct {
    Numerator: c.UINT,
    Denominator: c.UINT,
} else struct {};

pub const DXGI_MODE_DESC = if (builtin.os.tag == .windows) extern struct {
    Width: c.UINT,
    Height: c.UINT,
    RefreshRate: DXGI_RATIONAL,
    Format: c.DXGI_FORMAT,
    ScanlineOrdering: c.DXGI_MODE_SCANLINE_ORDER,
    Scaling: c.DXGI_MODE_SCALING,
} else struct {};

pub const DXGI_SAMPLE_DESC = if (builtin.os.tag == .windows) extern struct {
    Count: c.UINT,
    Quality: c.UINT,
} else struct {};

pub const DXGI_SWAP_CHAIN_DESC = if (builtin.os.tag == .windows) extern struct {
    BufferDesc: DXGI_MODE_DESC,
    SampleDesc: DXGI_SAMPLE_DESC,
    BufferUsage: c.UINT,
    BufferCount: c.UINT,
    OutputWindow: c.HWND,
    Windowed: c.BOOL,
    SwapEffect: c.DXGI_SWAP_EFFECT,
    Flags: c.UINT,
} else struct {};

fn asCHwnd(hwnd: win32.HWND) c.HWND {
    return @ptrFromInt(@intFromPtr(hwnd.?));
}

pub fn makeSwapChainDesc(hwnd: win32.HWND, width: u32, height: u32) DXGI_SWAP_CHAIN_DESC {
    return .{
        .BufferDesc = .{
            .Width = width,
            .Height = height,
            .RefreshRate = .{ .Numerator = 60, .Denominator = 1 },
            .Format = c.DXGI_FORMAT_R8G8B8A8_UNORM,
            .ScanlineOrdering = c.DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED,
            .Scaling = c.DXGI_MODE_SCALING_UNSPECIFIED,
        },
        .SampleDesc = .{
            .Count = 1,
            .Quality = 0,
        },
        .BufferUsage = c.DXGI_USAGE_RENDER_TARGET_OUTPUT,
        .BufferCount = 1,
        .OutputWindow = asCHwnd(hwnd),
        .Windowed = c.TRUE,
        .SwapEffect = c.DXGI_SWAP_EFFECT_DISCARD,
        .Flags = 0,
    };
}
