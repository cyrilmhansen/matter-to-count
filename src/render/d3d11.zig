const builtin = @import("builtin");
const std = @import("std");
const win32 = @import("../platform/win32/window.zig");
const log = @import("../util/logging.zig");

const c = if (builtin.os.tag == .windows) @cImport({
    @cInclude("windows.h");
    @cInclude("d3d11.h");
    @cInclude("dxgi.h");
}) else struct {};

pub const Renderer = if (builtin.os.tag == .windows) WindowsRenderer else StubRenderer;

const StubRenderer = struct {
    pub fn init(_: win32.HWND, _: u32, _: u32) !StubRenderer {
        return error.UnsupportedPlatform;
    }

    pub fn render(_: *StubRenderer, _: u32, _: u32) void {}

    pub fn resize(_: *StubRenderer, _: u32, _: u32) !void {}

    pub fn deinit(_: *StubRenderer) void {}
};

const WindowsRenderer = struct {
    swap_chain: *c.IDXGISwapChain,
    device: *c.ID3D11Device,
    context: *c.ID3D11DeviceContext,
    rtv: *c.ID3D11RenderTargetView,
    checker_texture: *c.ID3D11Texture2D,
    checker_srv: *c.ID3D11ShaderResourceView,

    pub fn init(hwnd: win32.HWND, width: u32, height: u32) !WindowsRenderer {
        @setRuntimeSafety(false);
        var desc: c.DXGI_SWAP_CHAIN_DESC = std.mem.zeroes(c.DXGI_SWAP_CHAIN_DESC);
        desc.BufferDesc.Width = width;
        desc.BufferDesc.Height = height;
        desc.BufferDesc.RefreshRate.Numerator = 60;
        desc.BufferDesc.RefreshRate.Denominator = 1;
        desc.BufferDesc.Format = c.DXGI_FORMAT_R8G8B8A8_UNORM;
        desc.SampleDesc.Count = 1;
        desc.BufferUsage = c.DXGI_USAGE_RENDER_TARGET_OUTPUT;
        desc.BufferCount = 1;
        desc.OutputWindow = @ptrFromInt(@intFromPtr(hwnd.?));
        desc.Windowed = c.TRUE;
        desc.SwapEffect = c.DXGI_SWAP_EFFECT_DISCARD;

        if (try tryCreate(desc, c.D3D_DRIVER_TYPE_HARDWARE)) |r| {
            log.info("d3d11 init: driver=hardware", .{});
            return r;
        }

        log.err("d3d11 hardware init failed, retrying with WARP", .{});
        if (try tryCreate(desc, c.D3D_DRIVER_TYPE_WARP)) |r| {
            log.info("d3d11 init: driver=warp", .{});
            return r;
        }

        return error.D3D11CreateDeviceAndSwapChainFailed;
    }

    fn tryCreate(desc: c.DXGI_SWAP_CHAIN_DESC, driver: c.D3D_DRIVER_TYPE) !?WindowsRenderer {
        @setRuntimeSafety(false);
        var swap_chain: ?*c.IDXGISwapChain = null;
        var device: ?*c.ID3D11Device = null;
        var context: ?*c.ID3D11DeviceContext = null;
        var feature_level: c.D3D_FEATURE_LEVEL = undefined;
        var local_desc = desc;

        const hr = c.D3D11CreateDeviceAndSwapChain(
            null,
            driver,
            null,
            c.D3D11_CREATE_DEVICE_BGRA_SUPPORT,
            null,
            0,
            c.D3D11_SDK_VERSION,
            &local_desc,
            &swap_chain,
            &device,
            &feature_level,
            &context,
        );

        if (hr != c.S_OK or swap_chain == null or device == null or context == null) {
            log.err("d3d11 init attempt failed hr=0x{x}", .{@as(u32, @bitCast(@as(i32, hr)))});
            return null;
        }

        const rtv = createRTV(device.?, swap_chain.?) catch |err| {
            _ = context.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(context.?)));
            _ = device.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(device.?)));
            _ = swap_chain.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(swap_chain.?)));
            log.err("d3d11 create RTV failed: {}", .{err});
            return null;
        };

        const checker = createCheckerTexture(device.?) catch |err| {
            _ = rtv.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(rtv)));
            _ = context.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(context.?)));
            _ = device.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(device.?)));
            _ = swap_chain.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(swap_chain.?)));
            log.err("d3d11 create checker texture failed: {}", .{err});
            return null;
        };

        return .{
            .swap_chain = swap_chain.?,
            .device = device.?,
            .context = context.?,
            .rtv = rtv,
            .checker_texture = checker.texture,
            .checker_srv = checker.srv,
        };
    }

    const Checker = struct {
        texture: *c.ID3D11Texture2D,
        srv: *c.ID3D11ShaderResourceView,
    };

    fn createCheckerTexture(device: *c.ID3D11Device) !Checker {
        @setRuntimeSafety(false);
        const tex_w: u32 = 64;
        const tex_h: u32 = 64;
        var pixels: [tex_w * tex_h]u32 = undefined;

        for (0..tex_h) |y| {
            for (0..tex_w) |x| {
                const check = ((x / 8) + (y / 8)) % 2 == 0;
                const color: u32 = if (check) 0xFF2A2A2A else 0xFFD9D9D9;
                pixels[y * tex_w + x] = color;
            }
        }

        var tex_desc: c.D3D11_TEXTURE2D_DESC = std.mem.zeroes(c.D3D11_TEXTURE2D_DESC);
        tex_desc.Width = tex_w;
        tex_desc.Height = tex_h;
        tex_desc.MipLevels = 1;
        tex_desc.ArraySize = 1;
        tex_desc.Format = c.DXGI_FORMAT_R8G8B8A8_UNORM;
        tex_desc.SampleDesc.Count = 1;
        tex_desc.Usage = c.D3D11_USAGE_DEFAULT;
        tex_desc.BindFlags = c.D3D11_BIND_SHADER_RESOURCE;

        var init_data: c.D3D11_SUBRESOURCE_DATA = std.mem.zeroes(c.D3D11_SUBRESOURCE_DATA);
        init_data.pSysMem = ptrAs(*const anyopaque, &pixels);
        init_data.SysMemPitch = tex_w * 4;

        var texture: ?*c.ID3D11Texture2D = null;
        const hr_tex = device.lpVtbl.*.CreateTexture2D.?(
            device,
            &tex_desc,
            &init_data,
            &texture,
        );
        if (hr_tex != c.S_OK or texture == null) return error.D3D11CreateTextureFailed;

        var srv: ?*c.ID3D11ShaderResourceView = null;
        const hr_srv = device.lpVtbl.*.CreateShaderResourceView.?(
            device,
            ptrAs(*c.ID3D11Resource, texture.?),
            null,
            &srv,
        );
        if (hr_srv != c.S_OK or srv == null) {
            _ = texture.?.lpVtbl.*.Release.?(ptrAs(*c.ID3D11Texture2D, texture.?));
            return error.D3D11CreateShaderResourceViewFailed;
        }

        return .{ .texture = texture.?, .srv = srv.? };
    }

    fn createRTV(device: *c.ID3D11Device, swap_chain: *c.IDXGISwapChain) !*c.ID3D11RenderTargetView {
        @setRuntimeSafety(false);
        var back_buffer_raw: ?*anyopaque = null;
        const hr_buf = swap_chain.lpVtbl.*.GetBuffer.?(
            swap_chain,
            0,
            &c.IID_ID3D11Texture2D,
            ptrAs(*?*anyopaque, &back_buffer_raw),
        );
        if (hr_buf != c.S_OK or back_buffer_raw == null) return error.D3D11GetBackBufferFailed;
        const back_buffer: *c.ID3D11Texture2D = ptrAs(*c.ID3D11Texture2D, back_buffer_raw.?);
        defer _ = back_buffer.lpVtbl.*.Release.?(back_buffer);

        var rtv: ?*c.ID3D11RenderTargetView = null;
        const hr_rtv = device.lpVtbl.*.CreateRenderTargetView.?(device, ptrAs(*c.ID3D11Resource, back_buffer), null, &rtv);
        if (hr_rtv != c.S_OK or rtv == null) return error.D3D11CreateRTVFailed;
        return rtv.?;
    }

    pub fn render(self: *WindowsRenderer, width: u32, height: u32) void {
        @setRuntimeSafety(false);
        var rtvs = [_]?*c.ID3D11RenderTargetView{self.rtv};
        self.context.lpVtbl.*.OMSetRenderTargets.?(self.context, 1, &rtvs, null);

        var vp: c.D3D11_VIEWPORT = std.mem.zeroes(c.D3D11_VIEWPORT);
        vp.Width = @floatFromInt(width);
        vp.Height = @floatFromInt(height);
        vp.MinDepth = 0.0;
        vp.MaxDepth = 1.0;
        self.context.lpVtbl.*.RSSetViewports.?(self.context, 1, &vp);

        const clear = [_]f32{ 0.07, 0.08, 0.10, 1.0 };
        self.context.lpVtbl.*.ClearRenderTargetView.?(self.context, self.rtv, &clear);
        _ = self.swap_chain.lpVtbl.*.Present.?(self.swap_chain, 1, 0);
    }

    pub fn resize(self: *WindowsRenderer, width: u32, height: u32) !void {
        @setRuntimeSafety(false);
        if (width == 0 or height == 0) return;

        _ = self.rtv.lpVtbl.*.Release.?(self.rtv);
        const hr = self.swap_chain.lpVtbl.*.ResizeBuffers.?(self.swap_chain, 0, width, height, c.DXGI_FORMAT_UNKNOWN, 0);
        if (hr != c.S_OK) return error.D3D11ResizeBuffersFailed;
        self.rtv = try createRTV(self.device, self.swap_chain);
    }

    pub fn deinit(self: *WindowsRenderer) void {
        @setRuntimeSafety(false);
        _ = self.checker_srv.lpVtbl.*.Release.?(self.checker_srv);
        _ = self.checker_texture.lpVtbl.*.Release.?(self.checker_texture);
        _ = self.rtv.lpVtbl.*.Release.?(self.rtv);
        _ = self.context.lpVtbl.*.Release.?(self.context);
        _ = self.device.lpVtbl.*.Release.?(self.device);
        _ = self.swap_chain.lpVtbl.*.Release.?(self.swap_chain);
    }
};

fn ptrAs(comptime T: type, p: anytype) T {
    return @ptrFromInt(@intFromPtr(p));
}
