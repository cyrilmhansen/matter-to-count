const builtin = @import("builtin");
const d3d_c = @import("d3d_c.zig");
const c = d3d_c.c;

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

