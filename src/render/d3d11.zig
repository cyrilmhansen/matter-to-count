const builtin = @import("builtin");
const std = @import("std");
const win32 = @import("../platform/win32/window.zig");
const log = @import("../util/logging.zig");

const c = if (builtin.os.tag == .windows) @cImport({
    @cInclude("windows.h");
    @cInclude("d3d11.h");
    @cInclude("dxgi.h");
    @cInclude("d3dcompiler.h");
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
    back_buffer: *c.ID3D11Texture2D,
    rtv: *c.ID3D11RenderTargetView,
    checker_texture: *c.ID3D11Texture2D,
    checker_srv: *c.ID3D11ShaderResourceView,
    vertex_shader: *c.ID3D11VertexShader,
    pixel_shader: *c.ID3D11PixelShader,
    input_layout: *c.ID3D11InputLayout,
    vertex_buffer: *c.ID3D11Buffer,

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

        const bb = createBackBufferAndRTV(device.?, swap_chain.?) catch |err| {
            _ = context.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(context.?)));
            _ = device.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(device.?)));
            _ = swap_chain.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(swap_chain.?)));
            log.err("d3d11 create RTV failed: {}", .{err});
            return null;
        };

        const checker = createCheckerTexture(device.?, desc.BufferDesc.Width, desc.BufferDesc.Height) catch |err| {
            _ = bb.rtv.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(bb.rtv)));
            _ = bb.back_buffer.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(bb.back_buffer)));
            _ = context.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(context.?)));
            _ = device.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(device.?)));
            _ = swap_chain.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(swap_chain.?)));
            log.err("d3d11 create checker texture failed: {}", .{err});
            return null;
        };

        const tri = createTrianglePipeline(device.?) catch |err| {
            _ = checker.srv.lpVtbl.*.Release.?(checker.srv);
            _ = checker.texture.lpVtbl.*.Release.?(checker.texture);
            _ = bb.rtv.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(bb.rtv)));
            _ = bb.back_buffer.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(bb.back_buffer)));
            _ = context.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(context.?)));
            _ = device.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(device.?)));
            _ = swap_chain.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(swap_chain.?)));
            log.err("d3d11 create triangle pipeline failed: {}", .{err});
            return null;
        };

        return .{
            .swap_chain = swap_chain.?,
            .device = device.?,
            .context = context.?,
            .back_buffer = bb.back_buffer,
            .rtv = bb.rtv,
            .checker_texture = checker.texture,
            .checker_srv = checker.srv,
            .vertex_shader = tri.vertex_shader,
            .pixel_shader = tri.pixel_shader,
            .input_layout = tri.input_layout,
            .vertex_buffer = tri.vertex_buffer,
        };
    }

    const BackBufferBundle = struct {
        back_buffer: *c.ID3D11Texture2D,
        rtv: *c.ID3D11RenderTargetView,
    };

    const Checker = struct {
        texture: *c.ID3D11Texture2D,
        srv: *c.ID3D11ShaderResourceView,
    };

    const TrianglePipeline = struct {
        vertex_shader: *c.ID3D11VertexShader,
        pixel_shader: *c.ID3D11PixelShader,
        input_layout: *c.ID3D11InputLayout,
        vertex_buffer: *c.ID3D11Buffer,
    };

    fn compileShader(source: []const u8, entry: []const u8, target: []const u8) !*c.ID3DBlob {
        var code: ?*c.ID3DBlob = null;
        var errors: ?*c.ID3DBlob = null;
        const hr = c.D3DCompile(
            source.ptr,
            source.len,
            null,
            null,
            null,
            ptrAs([*:0]const u8, entry.ptr),
            ptrAs([*:0]const u8, target.ptr),
            0,
            0,
            &code,
            &errors,
        );
        if (hr != c.S_OK or code == null) {
            if (errors) |e| {
                const msg_ptr: [*]const u8 = @ptrFromInt(@intFromPtr(e.lpVtbl.*.GetBufferPointer.?(e)));
                const msg_len: usize = @intCast(e.lpVtbl.*.GetBufferSize.?(e));
                const msg = msg_ptr[0..msg_len];
                log.err("hlsl compile failed: {s}", .{msg});
                _ = e.lpVtbl.*.Release.?(e);
            }
            return error.D3D11CompileShaderFailed;
        }
        if (errors) |e| _ = e.lpVtbl.*.Release.?(e);
        return code.?;
    }

    fn createTrianglePipeline(device: *c.ID3D11Device) !TrianglePipeline {
        const vs_src =
            \\struct VSIn { float3 pos : POSITION; float4 col : COLOR; };
            \\struct VSOut { float4 pos : SV_POSITION; float4 col : COLOR; };
            \\VSOut main(VSIn i) { VSOut o; o.pos = float4(i.pos, 1.0); o.col = i.col; return o; }
        ;
        const ps_src =
            \\struct PSIn { float4 pos : SV_POSITION; float4 col : COLOR; };
            \\float4 main(PSIn i) : SV_TARGET { return i.col; }
        ;

        const vs_blob = try compileShader(vs_src, "main\x00", "vs_4_0\x00");
        defer _ = vs_blob.lpVtbl.*.Release.?(vs_blob);
        const ps_blob = try compileShader(ps_src, "main\x00", "ps_4_0\x00");
        defer _ = ps_blob.lpVtbl.*.Release.?(ps_blob);

        var vs: ?*c.ID3D11VertexShader = null;
        var ps: ?*c.ID3D11PixelShader = null;

        const hr_vs = device.lpVtbl.*.CreateVertexShader.?(
            device,
            vs_blob.lpVtbl.*.GetBufferPointer.?(vs_blob),
            vs_blob.lpVtbl.*.GetBufferSize.?(vs_blob),
            null,
            &vs,
        );
        if (hr_vs != c.S_OK or vs == null) return error.D3D11CreateVertexShaderFailed;

        const hr_ps = device.lpVtbl.*.CreatePixelShader.?(
            device,
            ps_blob.lpVtbl.*.GetBufferPointer.?(ps_blob),
            ps_blob.lpVtbl.*.GetBufferSize.?(ps_blob),
            null,
            &ps,
        );
        if (hr_ps != c.S_OK or ps == null) {
            _ = vs.?.lpVtbl.*.Release.?(vs.?);
            return error.D3D11CreatePixelShaderFailed;
        }

        var elems = [_]c.D3D11_INPUT_ELEMENT_DESC{
            .{
                .SemanticName = ptrAs([*c]const u8, "POSITION\x00".ptr),
                .SemanticIndex = 0,
                .Format = c.DXGI_FORMAT_R32G32B32_FLOAT,
                .InputSlot = 0,
                .AlignedByteOffset = 0,
                .InputSlotClass = c.D3D11_INPUT_PER_VERTEX_DATA,
                .InstanceDataStepRate = 0,
            },
            .{
                .SemanticName = ptrAs([*c]const u8, "COLOR\x00".ptr),
                .SemanticIndex = 0,
                .Format = c.DXGI_FORMAT_R32G32B32A32_FLOAT,
                .InputSlot = 0,
                .AlignedByteOffset = 12,
                .InputSlotClass = c.D3D11_INPUT_PER_VERTEX_DATA,
                .InstanceDataStepRate = 0,
            },
        };

        var layout: ?*c.ID3D11InputLayout = null;
        const hr_layout = device.lpVtbl.*.CreateInputLayout.?(
            device,
            &elems,
            elems.len,
            vs_blob.lpVtbl.*.GetBufferPointer.?(vs_blob),
            vs_blob.lpVtbl.*.GetBufferSize.?(vs_blob),
            &layout,
        );
        if (hr_layout != c.S_OK or layout == null) {
            _ = ps.?.lpVtbl.*.Release.?(ps.?);
            _ = vs.?.lpVtbl.*.Release.?(vs.?);
            return error.D3D11CreateInputLayoutFailed;
        }

        const Vertex = extern struct { x: f32, y: f32, z: f32, r: f32, g: f32, b: f32, a: f32 };
        const verts = [_]Vertex{
            .{ .x = 0.0, .y = 0.6, .z = 0.0, .r = 1.0, .g = 0.2, .b = 0.2, .a = 1.0 },
            .{ .x = 0.6, .y = -0.6, .z = 0.0, .r = 0.2, .g = 1.0, .b = 0.2, .a = 1.0 },
            .{ .x = -0.6, .y = -0.6, .z = 0.0, .r = 0.2, .g = 0.3, .b = 1.0, .a = 1.0 },
        };
        var vb_desc: c.D3D11_BUFFER_DESC = std.mem.zeroes(c.D3D11_BUFFER_DESC);
        vb_desc.ByteWidth = @sizeOf(@TypeOf(verts));
        vb_desc.Usage = c.D3D11_USAGE_DEFAULT;
        vb_desc.BindFlags = c.D3D11_BIND_VERTEX_BUFFER;
        var vb_data: c.D3D11_SUBRESOURCE_DATA = std.mem.zeroes(c.D3D11_SUBRESOURCE_DATA);
        vb_data.pSysMem = ptrAs(*const anyopaque, &verts);

        var vb: ?*c.ID3D11Buffer = null;
        const hr_vb = device.lpVtbl.*.CreateBuffer.?(
            device,
            &vb_desc,
            &vb_data,
            &vb,
        );
        if (hr_vb != c.S_OK or vb == null) {
            _ = layout.?.lpVtbl.*.Release.?(layout.?);
            _ = ps.?.lpVtbl.*.Release.?(ps.?);
            _ = vs.?.lpVtbl.*.Release.?(vs.?);
            return error.D3D11CreateVertexBufferFailed;
        }

        return .{
            .vertex_shader = vs.?,
            .pixel_shader = ps.?,
            .input_layout = layout.?,
            .vertex_buffer = vb.?,
        };
    }

    fn createCheckerTexture(device: *c.ID3D11Device, tex_w: u32, tex_h: u32) !Checker {
        @setRuntimeSafety(false);
        const pixel_count: usize = @as(usize, tex_w) * @as(usize, tex_h);
        const pixels = try std.heap.c_allocator.alloc(u32, pixel_count);
        defer std.heap.c_allocator.free(pixels);

        for (0..tex_h) |y| {
            for (0..tex_w) |x| {
                const check = ((x / 8) + (y / 8)) % 2 == 0;
                // RGBA8 two-tone palette: warm orange and cyan-blue.
                const color: u32 = if (check) 0xFF1E96FF else 0xFFFFA31A;
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
        init_data.pSysMem = ptrAs(*const anyopaque, pixels.ptr);
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

    fn createBackBufferAndRTV(device: *c.ID3D11Device, swap_chain: *c.IDXGISwapChain) !BackBufferBundle {
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

        var rtv: ?*c.ID3D11RenderTargetView = null;
        const hr_rtv = device.lpVtbl.*.CreateRenderTargetView.?(device, ptrAs(*c.ID3D11Resource, back_buffer), null, &rtv);
        if (hr_rtv != c.S_OK or rtv == null) {
            _ = back_buffer.lpVtbl.*.Release.?(back_buffer);
            return error.D3D11CreateRTVFailed;
        }
        return .{ .back_buffer = back_buffer, .rtv = rtv.? };
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

        self.context.lpVtbl.*.CopyResource.?(
            self.context,
            ptrAs(*c.ID3D11Resource, self.back_buffer),
            ptrAs(*c.ID3D11Resource, self.checker_texture),
        );

        const stride = [_]c.UINT{@sizeOf(f32) * 7};
        const offset = [_]c.UINT{0};
        const vb = [_]?*c.ID3D11Buffer{self.vertex_buffer};
        self.context.lpVtbl.*.IASetInputLayout.?(self.context, self.input_layout);
        self.context.lpVtbl.*.IASetPrimitiveTopology.?(self.context, c.D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        self.context.lpVtbl.*.IASetVertexBuffers.?(self.context, 0, 1, &vb, &stride, &offset);
        self.context.lpVtbl.*.VSSetShader.?(self.context, self.vertex_shader, null, 0);
        self.context.lpVtbl.*.PSSetShader.?(self.context, self.pixel_shader, null, 0);
        self.context.lpVtbl.*.Draw.?(self.context, 3, 0);

        _ = self.swap_chain.lpVtbl.*.Present.?(self.swap_chain, 1, 0);
    }

    pub fn resize(self: *WindowsRenderer, width: u32, height: u32) !void {
        @setRuntimeSafety(false);
        if (width == 0 or height == 0) return;

        _ = self.rtv.lpVtbl.*.Release.?(self.rtv);
        _ = self.back_buffer.lpVtbl.*.Release.?(self.back_buffer);
        const hr = self.swap_chain.lpVtbl.*.ResizeBuffers.?(self.swap_chain, 0, width, height, c.DXGI_FORMAT_UNKNOWN, 0);
        if (hr != c.S_OK) return error.D3D11ResizeBuffersFailed;

        const bb = try createBackBufferAndRTV(self.device, self.swap_chain);
        self.back_buffer = bb.back_buffer;
        self.rtv = bb.rtv;

        _ = self.checker_srv.lpVtbl.*.Release.?(self.checker_srv);
        _ = self.checker_texture.lpVtbl.*.Release.?(self.checker_texture);
        const checker = try createCheckerTexture(self.device, width, height);
        self.checker_texture = checker.texture;
        self.checker_srv = checker.srv;
    }

    pub fn deinit(self: *WindowsRenderer) void {
        @setRuntimeSafety(false);
        _ = self.vertex_buffer.lpVtbl.*.Release.?(self.vertex_buffer);
        _ = self.input_layout.lpVtbl.*.Release.?(self.input_layout);
        _ = self.pixel_shader.lpVtbl.*.Release.?(self.pixel_shader);
        _ = self.vertex_shader.lpVtbl.*.Release.?(self.vertex_shader);
        _ = self.checker_srv.lpVtbl.*.Release.?(self.checker_srv);
        _ = self.checker_texture.lpVtbl.*.Release.?(self.checker_texture);
        _ = self.rtv.lpVtbl.*.Release.?(self.rtv);
        _ = self.back_buffer.lpVtbl.*.Release.?(self.back_buffer);
        _ = self.context.lpVtbl.*.Release.?(self.context);
        _ = self.device.lpVtbl.*.Release.?(self.device);
        _ = self.swap_chain.lpVtbl.*.Release.?(self.swap_chain);
    }

    pub fn captureScreenshot(self: *WindowsRenderer, path: []const u8, width: u32, height: u32) !void {
        @setRuntimeSafety(false);
        var desc: c.D3D11_TEXTURE2D_DESC = std.mem.zeroes(c.D3D11_TEXTURE2D_DESC);
        desc.Width = width;
        desc.Height = height;
        desc.MipLevels = 1;
        desc.ArraySize = 1;
        desc.Format = c.DXGI_FORMAT_R8G8B8A8_UNORM;
        desc.SampleDesc.Count = 1;
        desc.Usage = c.D3D11_USAGE_STAGING;
        desc.CPUAccessFlags = c.D3D11_CPU_ACCESS_READ;

        var staging: ?*c.ID3D11Texture2D = null;
        const hr_tex = self.device.lpVtbl.*.CreateTexture2D.?(
            self.device,
            &desc,
            null,
            &staging,
        );
        if (hr_tex != c.S_OK or staging == null) return error.D3D11CreateStagingTextureFailed;
        defer _ = staging.?.lpVtbl.*.Release.?(staging.?);

        self.context.lpVtbl.*.CopyResource.?(
            self.context,
            ptrAs(*c.ID3D11Resource, staging.?),
            ptrAs(*c.ID3D11Resource, self.checker_texture),
        );

        var mapped: c.D3D11_MAPPED_SUBRESOURCE = std.mem.zeroes(c.D3D11_MAPPED_SUBRESOURCE);
        const hr_map = self.context.lpVtbl.*.Map.?(
            self.context,
            ptrAs(*c.ID3D11Resource, staging.?),
            0,
            c.D3D11_MAP_READ,
            0,
            &mapped,
        );
        if (hr_map != c.S_OK) return error.D3D11MapStagingFailed;
        defer self.context.lpVtbl.*.Unmap.?(self.context, ptrAs(*c.ID3D11Resource, staging.?), 0);

        var file = try std.fs.cwd().createFile(path, .{ .truncate = true });
        defer file.close();
        var header_buf: [64]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf, "P3\n{d} {d}\n255\n", .{ width, height });
        try file.writeAll(header);

        const row_pitch: usize = @intCast(mapped.RowPitch);
        const bytes: [*]const u8 = ptrAs([*]const u8, mapped.pData.?);
        var y: usize = 0;
        while (y < height) : (y += 1) {
            const row = bytes + y * row_pitch;
            var x: usize = 0;
            while (x < width) : (x += 1) {
                const p = row + x * 4;
                const r = p[0];
                const g = p[1];
                const b = p[2];
                var line_buf: [24]u8 = undefined;
                const line = try std.fmt.bufPrint(&line_buf, "{d} {d} {d}\n", .{ r, g, b });
                try file.writeAll(line);
            }
        }
    }
};

fn ptrAs(comptime T: type, p: anytype) T {
    return @ptrFromInt(@intFromPtr(p));
}
