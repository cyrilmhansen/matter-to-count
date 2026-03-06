const builtin = @import("builtin");
const d3d_c = @import("d3d_c.zig");
const c = d3d_c.c;

pub const IDXGISwapChain = if (builtin.os.tag == .windows) extern struct {
    lpVtbl: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: *const fn (self: *IDXGISwapChain, riid: *const c.GUID, out: *?*anyopaque) callconv(.winapi) c.HRESULT,
        AddRef: *const fn (self: *IDXGISwapChain) callconv(.winapi) c.UINT,
        Release: *const fn (self: *IDXGISwapChain) callconv(.winapi) c.UINT,
        SetPrivateData: *const anyopaque,
        SetPrivateDataInterface: *const anyopaque,
        GetPrivateData: *const anyopaque,
        GetParent: *const anyopaque,
        GetDevice: *const anyopaque,
        Present: *const fn (self: *IDXGISwapChain, sync_interval: c.UINT, flags: c.UINT) callconv(.winapi) c.HRESULT,
        GetBuffer: *const fn (self: *IDXGISwapChain, buffer: c.UINT, riid: *const c.GUID, out: *?*anyopaque) callconv(.winapi) c.HRESULT,
        SetFullscreenState: *const anyopaque,
        GetFullscreenState: *const anyopaque,
        GetDesc: *const anyopaque,
        ResizeBuffers: *const fn (
            self: *IDXGISwapChain,
            buffer_count: c.UINT,
            width: c.UINT,
            height: c.UINT,
            new_format: c.DXGI_FORMAT,
            flags: c.UINT,
        ) callconv(.winapi) c.HRESULT,
        ResizeTarget: *const anyopaque,
        GetContainingOutput: *const anyopaque,
        GetFrameStatistics: *const anyopaque,
        GetLastPresentCount: *const anyopaque,
    };
} else struct {};

pub const IDXGIDevice = if (builtin.os.tag == .windows) extern struct {
    lpVtbl: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: *const fn (self: *IDXGIDevice, riid: *const c.GUID, out: *?*anyopaque) callconv(.winapi) c.HRESULT,
        AddRef: *const fn (self: *IDXGIDevice) callconv(.winapi) c.UINT,
        Release: *const fn (self: *IDXGIDevice) callconv(.winapi) c.UINT,
        SetPrivateData: *const anyopaque,
        SetPrivateDataInterface: *const anyopaque,
        GetPrivateData: *const anyopaque,
        GetParent: *const anyopaque,
        GetAdapter: *const fn (self: *IDXGIDevice, adapter: *?*IDXGIAdapter) callconv(.winapi) c.HRESULT,
        CreateSurface: *const anyopaque,
        QueryResourceResidency: *const anyopaque,
        SetGPUThreadPriority: *const anyopaque,
        GetGPUThreadPriority: *const anyopaque,
    };
} else struct {};

pub const IDXGIAdapter = if (builtin.os.tag == .windows) extern struct {
    lpVtbl: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: *const fn (self: *IDXGIAdapter, riid: *const c.GUID, out: *?*anyopaque) callconv(.winapi) c.HRESULT,
        AddRef: *const fn (self: *IDXGIAdapter) callconv(.winapi) c.UINT,
        Release: *const fn (self: *IDXGIAdapter) callconv(.winapi) c.UINT,
        SetPrivateData: *const anyopaque,
        SetPrivateDataInterface: *const anyopaque,
        GetPrivateData: *const anyopaque,
        GetParent: *const fn (self: *IDXGIAdapter, riid: *const c.GUID, out: *?*anyopaque) callconv(.winapi) c.HRESULT,
        EnumOutputs: *const anyopaque,
        GetDesc: *const anyopaque,
        CheckInterfaceSupport: *const anyopaque,
    };
} else struct {};

