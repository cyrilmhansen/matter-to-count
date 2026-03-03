const builtin = @import("builtin");
const win32 = @import("../platform/win32/window.zig");
const log = @import("../util/logging.zig");

pub const Renderer = if (builtin.os.tag == .windows) WindowsRenderer else StubRenderer;

const StubRenderer = struct {
    pub fn init(_: win32.HWND, _: u32, _: u32) !StubRenderer {
        return error.UnsupportedPlatform;
    }

    pub fn render(_: *StubRenderer, _: u32, _: u32) void {}

    pub fn resize(_: *StubRenderer, _: u32, _: u32) !void {}

    pub fn deinit(_: *StubRenderer) void {}
};

const UINT = u32;
const BOOL = i32;
const HRESULT = i32;

const DXGI_FORMAT_UNKNOWN: UINT = 0;
const DXGI_FORMAT_R8G8B8A8_UNORM: UINT = 28;
const DXGI_USAGE_RENDER_TARGET_OUTPUT: UINT = 0x20;
const DXGI_SWAP_EFFECT_DISCARD: UINT = 0;

const D3D_DRIVER_TYPE_HARDWARE: UINT = 1;
const D3D_DRIVER_TYPE_WARP: UINT = 5;
const D3D11_CREATE_DEVICE_BGRA_SUPPORT: UINT = 0x20;
const D3D11_SDK_VERSION: UINT = 7;

const S_OK: HRESULT = 0;

const DXGI_RATIONAL = extern struct {
    Numerator: UINT,
    Denominator: UINT,
};

const DXGI_MODE_DESC = extern struct {
    Width: UINT,
    Height: UINT,
    RefreshRate: DXGI_RATIONAL,
    Format: UINT,
    ScanlineOrdering: UINT,
    Scaling: UINT,
};

const DXGI_SAMPLE_DESC = extern struct {
    Count: UINT,
    Quality: UINT,
};

const DXGI_SWAP_CHAIN_DESC = extern struct {
    BufferDesc: DXGI_MODE_DESC,
    SampleDesc: DXGI_SAMPLE_DESC,
    BufferUsage: UINT,
    BufferCount: UINT,
    OutputWindow: win32.HWND,
    Windowed: BOOL,
    SwapEffect: UINT,
    Flags: UINT,
};

const IID = extern struct {
    Data1: u32,
    Data2: u16,
    Data3: u16,
    Data4: [8]u8,
};

const IDXGISwapChainVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const fn (*IDXGISwapChain) callconv(.winapi) u32,
    SetPrivateData: *const anyopaque,
    SetPrivateDataInterface: *const anyopaque,
    GetPrivateData: *const anyopaque,
    GetParent: *const anyopaque,
    GetDevice: *const anyopaque,
    Present: *const fn (*IDXGISwapChain, UINT, UINT) callconv(.winapi) HRESULT,
    GetBuffer: *const fn (*IDXGISwapChain, UINT, *const IID, *?*anyopaque) callconv(.winapi) HRESULT,
    SetFullscreenState: *const anyopaque,
    GetFullscreenState: *const anyopaque,
    GetDesc: *const anyopaque,
    ResizeBuffers: *const fn (*IDXGISwapChain, UINT, UINT, UINT, UINT, UINT) callconv(.winapi) HRESULT,
};

const IDXGISwapChain = extern struct {
    lpVtbl: *const IDXGISwapChainVtbl,
};

const ID3D11DeviceVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const fn (*ID3D11Device) callconv(.winapi) u32,
    CreateBuffer: *const anyopaque,
    CreateTexture1D: *const anyopaque,
    CreateTexture2D: *const anyopaque,
    CreateTexture3D: *const anyopaque,
    CreateShaderResourceView: *const anyopaque,
    CreateUnorderedAccessView: *const anyopaque,
    CreateRenderTargetView: *const fn (*ID3D11Device, *anyopaque, ?*anyopaque, *?*ID3D11RenderTargetView) callconv(.winapi) HRESULT,
};

const ID3D11Device = extern struct {
    lpVtbl: *const ID3D11DeviceVtbl,
};

const ID3D11DeviceContextVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const fn (*ID3D11DeviceContext) callconv(.winapi) u32,
};

const ID3D11DeviceContext = extern struct {
    lpVtbl: *const ID3D11DeviceContextVtbl,
};

const ID3D11RenderTargetViewVtbl = extern struct {
    QueryInterface: *const anyopaque,
    AddRef: *const anyopaque,
    Release: *const fn (*ID3D11RenderTargetView) callconv(.winapi) u32,
};

const ID3D11RenderTargetView = extern struct {
    lpVtbl: *const ID3D11RenderTargetViewVtbl,
};

extern "d3d11" fn D3D11CreateDeviceAndSwapChain(
    pAdapter: ?*anyopaque,
    DriverType: UINT,
    Software: ?*anyopaque,
    Flags: UINT,
    pFeatureLevels: ?*const UINT,
    FeatureLevels: UINT,
    SDKVersion: UINT,
    pSwapChainDesc: *const DXGI_SWAP_CHAIN_DESC,
    ppSwapChain: *?*IDXGISwapChain,
    ppDevice: *?*ID3D11Device,
    pFeatureLevel: ?*UINT,
    ppImmediateContext: *?*ID3D11DeviceContext,
) callconv(.winapi) HRESULT;

const IID_ID3D11Texture2D = IID{
    .Data1 = 0x6f15aaf2,
    .Data2 = 0xd208,
    .Data3 = 0x4e89,
    .Data4 = .{ 0x9a, 0xb4, 0x48, 0x95, 0x35, 0xd3, 0x4f, 0x9c },
};

const WindowsRenderer = struct {
    swap_chain: *IDXGISwapChain,
    device: *ID3D11Device,
    context: *ID3D11DeviceContext,
    render_target_view: *ID3D11RenderTargetView,

    pub fn init(hwnd: win32.HWND, width: u32, height: u32) !WindowsRenderer {
        const desc = DXGI_SWAP_CHAIN_DESC{
            .BufferDesc = .{
                .Width = width,
                .Height = height,
                .RefreshRate = .{ .Numerator = 60, .Denominator = 1 },
                .Format = DXGI_FORMAT_R8G8B8A8_UNORM,
                .ScanlineOrdering = 0,
                .Scaling = 0,
            },
            .SampleDesc = .{ .Count = 1, .Quality = 0 },
            .BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT,
            .BufferCount = 1,
            .OutputWindow = hwnd,
            .Windowed = 1,
            .SwapEffect = DXGI_SWAP_EFFECT_DISCARD,
            .Flags = 0,
        };

        const hw = try createDeviceAndSwapchainWithDriver(desc, D3D_DRIVER_TYPE_HARDWARE);
        if (hw) |ok| {
            log.info("d3d11 init: driver=hardware", .{});
            return ok;
        }

        log.err("d3d11 hardware init failed, retrying with WARP", .{});
        const warp = try createDeviceAndSwapchainWithDriver(desc, D3D_DRIVER_TYPE_WARP);
        if (warp) |ok| {
            log.info("d3d11 init: driver=warp", .{});
            return ok;
        }

        return error.D3D11CreateDeviceAndSwapChainFailed;
    }

    fn createDeviceAndSwapchainWithDriver(desc: DXGI_SWAP_CHAIN_DESC, driver_type: UINT) !?WindowsRenderer {
        var swap_chain: ?*IDXGISwapChain = null;
        var device: ?*ID3D11Device = null;
        var context: ?*ID3D11DeviceContext = null;
        var feature_level: UINT = 0;

        var local_desc = desc;
        const hr = D3D11CreateDeviceAndSwapChain(
            null,
            driver_type,
            null,
            D3D11_CREATE_DEVICE_BGRA_SUPPORT,
            null,
            0,
            D3D11_SDK_VERSION,
            &local_desc,
            &swap_chain,
            &device,
            &feature_level,
            &context,
        );

        if (hr != S_OK or swap_chain == null or device == null or context == null) {
            log.err("d3d11 init attempt failed hr=0x{x}", .{@as(u32, @bitCast(hr))});
            return null;
        }

        const rtv = createRenderTargetView(device.?, swap_chain.?) catch |err| {
            _ = context.?.lpVtbl.Release(context.?);
            _ = device.?.lpVtbl.Release(device.?);
            _ = swap_chain.?.lpVtbl.Release(swap_chain.?);
            log.err("d3d11 create RTV failed: {}", .{err});
            return null;
        };

        return .{
            .swap_chain = swap_chain.?,
            .device = device.?,
            .context = context.?,
            .render_target_view = rtv,
        };
    }

    fn createRenderTargetView(device: *ID3D11Device, swap_chain: *IDXGISwapChain) !*ID3D11RenderTargetView {
        var back_buffer: ?*anyopaque = null;
        const hr_buf = swap_chain.lpVtbl.GetBuffer(swap_chain, 0, &IID_ID3D11Texture2D, &back_buffer);
        if (hr_buf != S_OK or back_buffer == null) return error.D3D11GetBackBufferFailed;

        var rtv: ?*ID3D11RenderTargetView = null;
        const hr_rtv = device.lpVtbl.CreateRenderTargetView(device, back_buffer.?, null, &rtv);
        if (hr_rtv != S_OK or rtv == null) return error.D3D11CreateRTVFailed;
        return rtv.?;
    }

    pub fn render(self: *WindowsRenderer, _: u32, _: u32) void {
        _ = self.swap_chain.lpVtbl.Present(self.swap_chain, 1, 0);
    }

    pub fn resize(self: *WindowsRenderer, width: u32, height: u32) !void {
        if (width == 0 or height == 0) return;

        _ = self.render_target_view.lpVtbl.Release(self.render_target_view);
        const hr = self.swap_chain.lpVtbl.ResizeBuffers(self.swap_chain, 0, width, height, DXGI_FORMAT_UNKNOWN, 0);
        if (hr != S_OK) return error.D3D11ResizeBuffersFailed;

        self.render_target_view = try createRenderTargetView(self.device, self.swap_chain);
    }

    pub fn deinit(self: *WindowsRenderer) void {
        _ = self.render_target_view.lpVtbl.Release(self.render_target_view);
        _ = self.context.lpVtbl.Release(self.context);
        _ = self.device.lpVtbl.Release(self.device);
        _ = self.swap_chain.lpVtbl.Release(self.swap_chain);
    }
};
