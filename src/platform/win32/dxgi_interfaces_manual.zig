const builtin = @import("builtin");
const win = @import("win_types.zig");
const dxgi_manual = @import("dxgi_manual.zig");

pub const IDXGISwapChain = if (builtin.os.tag == .windows) extern struct {
    lpVtbl: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: *const fn (self: *IDXGISwapChain, riid: *const win.GUID, out: *?*anyopaque) callconv(.winapi) win.HRESULT,
        AddRef: *const fn (self: *IDXGISwapChain) callconv(.winapi) win.UINT,
        Release: *const fn (self: *IDXGISwapChain) callconv(.winapi) win.UINT,
        SetPrivateData: *const anyopaque,
        SetPrivateDataInterface: *const anyopaque,
        GetPrivateData: *const anyopaque,
        GetParent: *const anyopaque,
        GetDevice: *const anyopaque,
        Present: *const fn (self: *IDXGISwapChain, sync_interval: win.UINT, flags: win.UINT) callconv(.winapi) win.HRESULT,
        GetBuffer: *const fn (self: *IDXGISwapChain, buffer: win.UINT, riid: *const win.GUID, out: *?*anyopaque) callconv(.winapi) win.HRESULT,
        SetFullscreenState: *const anyopaque,
        GetFullscreenState: *const anyopaque,
        GetDesc: *const anyopaque,
        ResizeBuffers: *const fn (
            self: *IDXGISwapChain,
            buffer_count: win.UINT,
            width: win.UINT,
            height: win.UINT,
            new_format: dxgi_manual.DXGI_FORMAT,
            flags: win.UINT,
        ) callconv(.winapi) win.HRESULT,
        ResizeTarget: *const anyopaque,
        GetContainingOutput: *const anyopaque,
        GetFrameStatistics: *const anyopaque,
        GetLastPresentCount: *const anyopaque,
    };
} else struct {};

pub const IDXGIDevice = if (builtin.os.tag == .windows) extern struct {
    lpVtbl: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: *const fn (self: *IDXGIDevice, riid: *const win.GUID, out: *?*anyopaque) callconv(.winapi) win.HRESULT,
        AddRef: *const fn (self: *IDXGIDevice) callconv(.winapi) win.UINT,
        Release: *const fn (self: *IDXGIDevice) callconv(.winapi) win.UINT,
        SetPrivateData: *const anyopaque,
        SetPrivateDataInterface: *const anyopaque,
        GetPrivateData: *const anyopaque,
        GetParent: *const anyopaque,
        GetAdapter: *const fn (self: *IDXGIDevice, adapter: *?*IDXGIAdapter) callconv(.winapi) win.HRESULT,
        CreateSurface: *const anyopaque,
        QueryResourceResidency: *const anyopaque,
        SetGPUThreadPriority: *const anyopaque,
        GetGPUThreadPriority: *const anyopaque,
    };
} else struct {};

pub const IDXGIAdapter = if (builtin.os.tag == .windows) extern struct {
    lpVtbl: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: *const fn (self: *IDXGIAdapter, riid: *const win.GUID, out: *?*anyopaque) callconv(.winapi) win.HRESULT,
        AddRef: *const fn (self: *IDXGIAdapter) callconv(.winapi) win.UINT,
        Release: *const fn (self: *IDXGIAdapter) callconv(.winapi) win.UINT,
        SetPrivateData: *const anyopaque,
        SetPrivateDataInterface: *const anyopaque,
        GetPrivateData: *const anyopaque,
        GetParent: *const fn (self: *IDXGIAdapter, riid: *const win.GUID, out: *?*anyopaque) callconv(.winapi) win.HRESULT,
        EnumOutputs: *const anyopaque,
        GetDesc: *const anyopaque,
        CheckInterfaceSupport: *const anyopaque,
    };
} else struct {};
