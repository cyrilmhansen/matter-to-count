const std = @import("std");
const com = @import("../../platform/win32/com_helpers.zig");
const com_iids = @import("../../platform/win32/com_iids.zig");
const d3d11_if = @import("../../platform/win32/d3d11_interfaces_manual.zig");
const d3d11_manual = @import("../../platform/win32/d3d11_manual.zig");
const dxgi_if_manual = @import("../../platform/win32/dxgi_interfaces_manual.zig");
const dxgi_manual = @import("../../platform/win32/dxgi_manual.zig");
const win = @import("../../platform/win32/win_types.zig");

pub const Checker = struct {
    texture: *d3d11_if.ID3D11Texture2D,
    srv: *d3d11_if.ID3D11ShaderResourceView,
};

pub const BackBufferBundle = struct {
    back_buffer: *d3d11_if.ID3D11Texture2D,
    rtv: *d3d11_if.ID3D11RenderTargetView,
};

pub fn createCaptureTexture(device: *d3d11_if.ID3D11Device, tex_w: u32, tex_h: u32) !*d3d11_if.ID3D11Texture2D {
    var tex_desc: d3d11_manual.D3D11_TEXTURE2D_DESC = std.mem.zeroes(d3d11_manual.D3D11_TEXTURE2D_DESC);
    tex_desc.Width = tex_w;
    tex_desc.Height = tex_h;
    tex_desc.MipLevels = 1;
    tex_desc.ArraySize = 1;
    tex_desc.Format = dxgi_manual.DXGI_FORMAT_R8G8B8A8_UNORM;
    tex_desc.SampleDesc.Count = 1;
    tex_desc.Usage = d3d11_manual.D3D11_USAGE_DEFAULT;

    var texture: ?*d3d11_if.ID3D11Texture2D = null;
    const hr_tex = device.lpVtbl.*.CreateTexture2D.?(
        device,
        @as(*const d3d11_manual.D3D11_TEXTURE2D_DESC, @ptrCast(&tex_desc)),
        null,
        &texture,
    );
    if (hr_tex != win.S_OK or texture == null) return error.D3D11CreateCaptureTextureFailed;
    return texture.?;
}

pub fn createCheckerTexture(device: *d3d11_if.ID3D11Device, tex_w: u32, tex_h: u32) !Checker {
    @setRuntimeSafety(false);
    const pixel_count: usize = @as(usize, tex_w) * @as(usize, tex_h);
    const pixels = try std.heap.page_allocator.alloc(u32, pixel_count);
    defer std.heap.page_allocator.free(pixels);

    for (0..tex_h) |y| {
        for (0..tex_w) |x| {
            const check = ((x / 8) + (y / 8)) % 2 == 0;
            const color: u32 = if (check) 0xFF1E96FF else 0xFFFFA31A;
            pixels[y * tex_w + x] = color;
        }
    }

    var tex_desc: d3d11_manual.D3D11_TEXTURE2D_DESC = std.mem.zeroes(d3d11_manual.D3D11_TEXTURE2D_DESC);
    tex_desc.Width = tex_w;
    tex_desc.Height = tex_h;
    tex_desc.MipLevels = 1;
    tex_desc.ArraySize = 1;
    tex_desc.Format = dxgi_manual.DXGI_FORMAT_R8G8B8A8_UNORM;
    tex_desc.SampleDesc.Count = 1;
    tex_desc.Usage = d3d11_manual.D3D11_USAGE_DEFAULT;
    tex_desc.BindFlags = d3d11_manual.D3D11_BIND_SHADER_RESOURCE;

    var init_data: d3d11_manual.D3D11_SUBRESOURCE_DATA = std.mem.zeroes(d3d11_manual.D3D11_SUBRESOURCE_DATA);
    init_data.pSysMem = com.cast(*const anyopaque, pixels.ptr);
    init_data.SysMemPitch = tex_w * 4;

    var texture: ?*d3d11_if.ID3D11Texture2D = null;
    const hr_tex = device.lpVtbl.*.CreateTexture2D.?(
        device,
        @as(*const d3d11_manual.D3D11_TEXTURE2D_DESC, @ptrCast(&tex_desc)),
        @as(*const d3d11_manual.D3D11_SUBRESOURCE_DATA, @ptrCast(&init_data)),
        &texture,
    );
    if (hr_tex != win.S_OK or texture == null) return error.D3D11CreateTextureFailed;

    var srv: ?*d3d11_if.ID3D11ShaderResourceView = null;
    const hr_srv = device.lpVtbl.*.CreateShaderResourceView.?(
        device,
        com.cast(*d3d11_if.ID3D11Resource, texture.?),
        null,
        &srv,
    );
    if (hr_srv != win.S_OK or srv == null) {
        com.release(texture.?);
        return error.D3D11CreateShaderResourceViewFailed;
    }

    return .{ .texture = texture.?, .srv = srv.? };
}

pub fn createBackBufferAndRTV(device: *d3d11_if.ID3D11Device, swap_chain: *dxgi_if_manual.IDXGISwapChain) !BackBufferBundle {
    @setRuntimeSafety(false);
    var back_buffer_raw: ?*anyopaque = null;
    const hr_buf = swap_chain.lpVtbl.GetBuffer(
        swap_chain,
        0,
        &com_iids.IID_ID3D11Texture2D,
        com.cast(*?*anyopaque, &back_buffer_raw),
    );
    if (hr_buf != win.S_OK or back_buffer_raw == null) return error.D3D11GetBackBufferFailed;
    const back_buffer: *d3d11_if.ID3D11Texture2D = com.cast(*d3d11_if.ID3D11Texture2D, back_buffer_raw.?);

    var rtv: ?*d3d11_if.ID3D11RenderTargetView = null;
    const hr_rtv = device.lpVtbl.*.CreateRenderTargetView.?(device, com.cast(*d3d11_if.ID3D11Resource, back_buffer), null, &rtv);
    if (hr_rtv != win.S_OK or rtv == null) {
        com.release(back_buffer);
        return error.D3D11CreateRTVFailed;
    }
    return .{ .back_buffer = back_buffer, .rtv = rtv.? };
}
