const builtin = @import("builtin");
const std = @import("std");
const win32 = @import("../platform/win32/window.zig");
const log = @import("../util/logging.zig");
const number = @import("../math/number.zig");
const addition = @import("../math/addition.zig");
const fixtures = @import("../tests/fixtures.zig");
const event_scene = @import("../scene/event_scene.zig");
const layout_map = @import("../scene/layout_map.zig");
const render_plan = @import("render_plan.zig");
const subtraction = @import("../math/subtraction.zig");
const shift = @import("../math/shift.zig");

const c = if (builtin.os.tag == .windows) @cImport({
    @cInclude("windows.h");
    @cInclude("d3d11.h");
    @cInclude("dxgi.h");
    @cInclude("d3dcompiler.h");
}) else struct {};

pub const Renderer = if (builtin.os.tag == .windows) WindowsRenderer else StubRenderer;
pub const SceneKind = enum {
    add,
    sub,
    shift,
};

const StubRenderer = struct {
    pub fn init(_: win32.HWND, _: u32, _: u32, _: SceneKind) !StubRenderer {
        return error.UnsupportedPlatform;
    }

    pub fn render(_: *StubRenderer, _: u32, _: u32) void {}

    pub fn resize(_: *StubRenderer, _: u32, _: u32) !void {}

    pub fn deinit(_: *StubRenderer) void {}
};

const WindowsRenderer = struct {
    const Vertex = extern struct { x: f32, y: f32, z: f32, r: f32, g: f32, b: f32, a: f32 };
    const MaxDynamicVertices: u32 = 8192;
    const PhaseFrames: u32 = 30;
    const LegendZ: f32 = 0.95;
    const LegendCellW: f32 = 0.010;
    const LegendCellH: f32 = 0.018;
    const LegendGap: f32 = 0.003;
    const LegendCharSpacing: f32 = 0.010;

    swap_chain: *c.IDXGISwapChain,
    device: *c.ID3D11Device,
    context: *c.ID3D11DeviceContext,
    back_buffer: *c.ID3D11Texture2D,
    rtv: *c.ID3D11RenderTargetView,
    checker_texture: *c.ID3D11Texture2D,
    checker_srv: *c.ID3D11ShaderResourceView,
    capture_texture: *c.ID3D11Texture2D,
    vertex_shader: *c.ID3D11VertexShader,
    pixel_shader: *c.ID3D11PixelShader,
    input_layout: *c.ID3D11InputLayout,
    vertex_buffer: *c.ID3D11Buffer,
    frame_index: u32,
    scene_kind: SceneKind,

    pub fn init(hwnd: win32.HWND, width: u32, height: u32, scene_kind: SceneKind) !WindowsRenderer {
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

        if (try tryCreate(desc, c.D3D_DRIVER_TYPE_HARDWARE, scene_kind)) |r| {
            log.info("d3d11 init: driver=hardware", .{});
            return r;
        }

        log.err("d3d11 hardware init failed, retrying with WARP", .{});
        if (try tryCreate(desc, c.D3D_DRIVER_TYPE_WARP, scene_kind)) |r| {
            log.info("d3d11 init: driver=warp", .{});
            return r;
        }

        return error.D3D11CreateDeviceAndSwapChainFailed;
    }

    fn tryCreate(desc: c.DXGI_SWAP_CHAIN_DESC, driver: c.D3D_DRIVER_TYPE, scene_kind: SceneKind) !?WindowsRenderer {
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
        const capture_texture = createCaptureTexture(device.?, desc.BufferDesc.Width, desc.BufferDesc.Height) catch |err| {
            _ = tri.vertex_buffer.lpVtbl.*.Release.?(tri.vertex_buffer);
            _ = tri.input_layout.lpVtbl.*.Release.?(tri.input_layout);
            _ = tri.pixel_shader.lpVtbl.*.Release.?(tri.pixel_shader);
            _ = tri.vertex_shader.lpVtbl.*.Release.?(tri.vertex_shader);
            _ = checker.srv.lpVtbl.*.Release.?(checker.srv);
            _ = checker.texture.lpVtbl.*.Release.?(checker.texture);
            _ = bb.rtv.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(bb.rtv)));
            _ = bb.back_buffer.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(bb.back_buffer)));
            _ = context.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(context.?)));
            _ = device.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(device.?)));
            _ = swap_chain.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(swap_chain.?)));
            log.err("d3d11 create capture texture failed: {}", .{err});
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
            .capture_texture = capture_texture,
            .vertex_shader = tri.vertex_shader,
            .pixel_shader = tri.pixel_shader,
            .input_layout = tri.input_layout,
            .vertex_buffer = tri.vertex_buffer,
            .frame_index = 0,
            .scene_kind = scene_kind,
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

    fn createCaptureTexture(device: *c.ID3D11Device, tex_w: u32, tex_h: u32) !*c.ID3D11Texture2D {
        var tex_desc: c.D3D11_TEXTURE2D_DESC = std.mem.zeroes(c.D3D11_TEXTURE2D_DESC);
        tex_desc.Width = tex_w;
        tex_desc.Height = tex_h;
        tex_desc.MipLevels = 1;
        tex_desc.ArraySize = 1;
        tex_desc.Format = c.DXGI_FORMAT_R8G8B8A8_UNORM;
        tex_desc.SampleDesc.Count = 1;
        tex_desc.Usage = c.D3D11_USAGE_DEFAULT;

        var texture: ?*c.ID3D11Texture2D = null;
        const hr_tex = device.lpVtbl.*.CreateTexture2D.?(
            device,
            &tex_desc,
            null,
            &texture,
        );
        if (hr_tex != c.S_OK or texture == null) return error.D3D11CreateCaptureTextureFailed;
        return texture.?;
    }

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

        var vb_desc: c.D3D11_BUFFER_DESC = std.mem.zeroes(c.D3D11_BUFFER_DESC);
        vb_desc.ByteWidth = MaxDynamicVertices * @sizeOf(Vertex);
        vb_desc.Usage = c.D3D11_USAGE_DYNAMIC;
        vb_desc.BindFlags = c.D3D11_BIND_VERTEX_BUFFER;
        vb_desc.CPUAccessFlags = c.D3D11_CPU_ACCESS_WRITE;

        var vb: ?*c.ID3D11Buffer = null;
        const hr_vb = device.lpVtbl.*.CreateBuffer.?(
            device,
            &vb_desc,
            null,
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

    fn clamp01(v: f32) f32 {
        if (v < 0.0) return 0.0;
        if (v > 1.0) return 1.0;
        return v;
    }

    fn buildDemoPlan(self: *WindowsRenderer, allocator: std.mem.Allocator, frame_index: u32) !render_plan.RenderPlan {
        const cycle: u32 = 5 * PhaseFrames;
        const local = frame_index % cycle;
        const tick = local / PhaseFrames;
        const phase = @as(f32, @floatFromInt(local % PhaseFrames)) / @as(f32, @floatFromInt(PhaseFrames));
        const sample = event_scene.TimeSample{ .tick = tick, .phase = phase };
        const fx = fixtures.add_decimal_cascade_carry;
        var lhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.lhs);
        defer lhs.deinit(allocator);
        var rhs = try number.DigitNumber.fromU64(allocator, fx.base, fx.rhs);
        defer rhs.deinit(allocator);
        var scene: event_scene.ArithmeticSceneState = undefined;
        switch (self.scene_kind) {
            .add => {
                var res = try addition.addWithEvents(allocator, lhs, rhs);
                defer res.deinit(allocator);
                scene = try event_scene.buildSceneAtTime(allocator, res.tape, sample);
            },
            .sub => {
                const sfx = fixtures.sub_decimal_borrow_chain;
                var sl = try number.DigitNumber.fromU64(allocator, sfx.base, sfx.lhs);
                defer sl.deinit(allocator);
                var sr = try number.DigitNumber.fromU64(allocator, sfx.base, sfx.rhs);
                defer sr.deinit(allocator);
                var res = try subtraction.subWithEvents(allocator, sl, sr);
                defer res.deinit(allocator);
                scene = try event_scene.buildSceneAtTime(allocator, res.tape, sample);
            },
            .shift => {
                const shfx = fixtures.shift_decimal_left_once;
                var input = try number.DigitNumber.fromU64(allocator, shfx.base, shfx.lhs);
                defer input.deinit(allocator);
                var res = try shift.multiplyByBaseWithEvents(allocator, input);
                defer res.deinit(allocator);
                scene = try event_scene.buildSceneAtTime(allocator, res.tape, sample);
            },
        }
        defer scene.deinit(allocator);

        return render_plan.buildPlan(allocator, scene, layout_map.LayoutConfig{});
    }

    fn glyphRows(ch: u8) [5]u8 {
        return switch (ch) {
            '0' => .{ 0b111, 0b101, 0b101, 0b101, 0b111 },
            '1' => .{ 0b010, 0b110, 0b010, 0b010, 0b111 },
            '2' => .{ 0b111, 0b001, 0b111, 0b100, 0b111 },
            '3' => .{ 0b111, 0b001, 0b111, 0b001, 0b111 },
            '4' => .{ 0b101, 0b101, 0b111, 0b001, 0b001 },
            '5' => .{ 0b111, 0b100, 0b111, 0b001, 0b111 },
            '6' => .{ 0b111, 0b100, 0b111, 0b101, 0b111 },
            '7' => .{ 0b111, 0b001, 0b001, 0b001, 0b001 },
            '8' => .{ 0b111, 0b101, 0b111, 0b101, 0b111 },
            '9' => .{ 0b111, 0b101, 0b111, 0b001, 0b111 },
            'A' => .{ 0b111, 0b101, 0b111, 0b101, 0b101 },
            'B' => .{ 0b110, 0b101, 0b110, 0b101, 0b110 },
            'D' => .{ 0b110, 0b101, 0b101, 0b101, 0b110 },
            'F' => .{ 0b111, 0b100, 0b111, 0b100, 0b100 },
            'H' => .{ 0b101, 0b101, 0b111, 0b101, 0b101 },
            'I' => .{ 0b111, 0b010, 0b010, 0b010, 0b111 },
            'P' => .{ 0b111, 0b101, 0b111, 0b100, 0b100 },
            'S' => .{ 0b111, 0b100, 0b111, 0b001, 0b111 },
            'T' => .{ 0b111, 0b010, 0b010, 0b010, 0b010 },
            'U' => .{ 0b101, 0b101, 0b101, 0b101, 0b111 },
            ' ' => .{ 0, 0, 0, 0, 0 },
            else => .{ 0, 0, 0, 0, 0 },
        };
    }

    fn sceneLabel(kind: SceneKind) []const u8 {
        return switch (kind) {
            .add => "ADD",
            .sub => "SUB",
            .shift => "SHIFT",
        };
    }

    fn appendSolidQuadNdc(
        verts: []Vertex,
        base: *usize,
        x0: f32,
        y0: f32,
        x1: f32,
        y1: f32,
        z: f32,
        r: f32,
        g: f32,
        b: f32,
        a: f32,
    ) void {
        verts[base.* + 0] = .{ .x = x0, .y = y0, .z = z, .r = r, .g = g, .b = b, .a = a };
        verts[base.* + 1] = .{ .x = x1, .y = y1, .z = z, .r = r, .g = g, .b = b, .a = a };
        verts[base.* + 2] = .{ .x = x1, .y = y0, .z = z, .r = r, .g = g, .b = b, .a = a };
        verts[base.* + 3] = .{ .x = x0, .y = y0, .z = z, .r = r, .g = g, .b = b, .a = a };
        verts[base.* + 4] = .{ .x = x0, .y = y1, .z = z, .r = r, .g = g, .b = b, .a = a };
        verts[base.* + 5] = .{ .x = x1, .y = y1, .z = z, .r = r, .g = g, .b = b, .a = a };
        base.* += 6;
    }

    fn appendLegendText(verts: []Vertex, base: *usize, text: []const u8) void {
        var pen_x: f32 = -0.96;
        const top_y: f32 = 0.96;
        for (text) |ch| {
            const rows = glyphRows(ch);
            for (rows, 0..) |mask, row| {
                const py0 = top_y - @as(f32, @floatFromInt(row)) * (LegendCellH + LegendGap) - LegendCellH;
                const py1 = py0 + LegendCellH;
                var col: usize = 0;
                while (col < 3) : (col += 1) {
                    const bit: u8 = @as(u8, 1) << @as(u3, @intCast(2 - col));
                    if ((mask & bit) == 0) continue;
                    const px0 = pen_x + @as(f32, @floatFromInt(col)) * (LegendCellW + LegendGap);
                    const px1 = px0 + LegendCellW;
                    appendSolidQuadNdc(verts, base, px0, py0, px1, py1, LegendZ, 0.98, 0.98, 0.98, 1.0);
                }
            }
            pen_x += 3.0 * (LegendCellW + LegendGap) + LegendCharSpacing;
        }
    }

    fn roleSize(role: render_plan.DrawRole) f32 {
        return switch (role) {
            .source_digit, .result_digit => 0.070,
            .carry_packet, .borrow_packet, .shift_packet => 0.090,
            .active_marker => 0.050,
        };
    }

    fn appendQuad(
        verts: []Vertex,
        base: *usize,
        cx: f32,
        cy: f32,
        z: f32,
        half_size: f32,
        r: f32,
        g: f32,
        b: f32,
        a: f32,
    ) void {
        const x0 = cx - half_size;
        const x1 = cx + half_size;
        const y0 = cy - half_size;
        const y1 = cy + half_size;

        // Emit clockwise triangles to match D3D11 default front-face winding.
        verts[base.* + 0] = .{ .x = x0, .y = y0, .z = z, .r = r, .g = g, .b = b, .a = a };
        verts[base.* + 1] = .{ .x = x1, .y = y1, .z = z, .r = r, .g = g, .b = b, .a = a };
        verts[base.* + 2] = .{ .x = x1, .y = y0, .z = z, .r = r, .g = g, .b = b, .a = a };
        verts[base.* + 3] = .{ .x = x0, .y = y0, .z = z, .r = r, .g = g, .b = b, .a = a };
        verts[base.* + 4] = .{ .x = x0, .y = y1, .z = z, .r = r, .g = g, .b = b, .a = a };
        verts[base.* + 5] = .{ .x = x1, .y = y1, .z = z, .r = r, .g = g, .b = b, .a = a };
        base.* += 6;
    }

    fn buildPlanVertices(
        self: *WindowsRenderer,
        allocator: std.mem.Allocator,
        width: u32,
        height: u32,
    ) ![]Vertex {
        _ = width;
        _ = height;

        var plan = try self.buildDemoPlan(allocator, self.frame_index);
        defer plan.deinit(allocator);

        const cycle: u32 = 5 * PhaseFrames;
        const local = self.frame_index % cycle;
        const tick = local / PhaseFrames;
        const phase_pct: u32 = ((local % PhaseFrames) * 100) / PhaseFrames;
        const label = sceneLabel(self.scene_kind);
        var legend_buf: [64]u8 = undefined;
        const legend_text = try std.fmt.bufPrint(&legend_buf, "{s} T{d} P{d:0>2}", .{ label, tick, phase_pct });

        if (plan.points.len == 0 and legend_text.len == 0) return allocator.alloc(Vertex, 0);
        const legend_budget: usize = legend_text.len * 15 * 6;
        const needed: usize = plan.points.len * 6 + legend_budget;
        if (needed > MaxDynamicVertices) return error.RenderPlanTooLarge;

        var min_x = plan.points[0].x;
        var max_x = plan.points[0].x;
        var min_y = plan.points[0].y;
        var max_y = plan.points[0].y;
        for (plan.points[1..]) |p| {
            min_x = @min(min_x, p.x);
            max_x = @max(max_x, p.x);
            min_y = @min(min_y, p.y);
            max_y = @max(max_y, p.y);
        }
        const pad = 0.25;
        min_x -= pad;
        max_x += pad;
        min_y -= pad;
        max_y += pad;
        var span_x = max_x - min_x;
        var span_y = max_y - min_y;
        if (span_x < 0.001) span_x = 1.0;
        if (span_y < 0.001) span_y = 1.0;

        const vertices = try allocator.alloc(Vertex, needed);
        errdefer allocator.free(vertices);
        var n: usize = 0;

        for (plan.points) |p| {
            const nx = ((p.x - min_x) / span_x) * 1.8 - 0.9;
            const ny = ((p.y - min_y) / span_y) * 1.8 - 0.9;
            const nz = clamp01(p.z);
            appendQuad(
                vertices,
                &n,
                nx,
                ny,
                nz,
                roleSize(p.role),
                clamp01(p.r),
                clamp01(p.g),
                clamp01(p.b),
                clamp01(p.a),
            );
        }
        appendLegendText(vertices, &n, legend_text);

        return vertices[0..n];
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

        var vertex_count: u32 = 0;
        const verts = self.buildPlanVertices(std.heap.c_allocator, width, height) catch |err| {
            log.err("render plan build failed: {}", .{err});
            _ = self.swap_chain.lpVtbl.*.Present.?(self.swap_chain, 1, 0);
            self.frame_index +%= 1;
            return;
        };
        defer std.heap.c_allocator.free(verts);
        vertex_count = @as(u32, @intCast(verts.len));

        if (vertex_count > 0) {
            var mapped: c.D3D11_MAPPED_SUBRESOURCE = std.mem.zeroes(c.D3D11_MAPPED_SUBRESOURCE);
            const hr_map = self.context.lpVtbl.*.Map.?(
                self.context,
                ptrAs(*c.ID3D11Resource, self.vertex_buffer),
                0,
                c.D3D11_MAP_WRITE_DISCARD,
                0,
                &mapped,
            );
            if (hr_map == c.S_OK and mapped.pData != null) {
                const src = std.mem.sliceAsBytes(verts);
                const dst = ptrAs([*]u8, mapped.pData.?)[0..src.len];
                @memcpy(dst, src);
                self.context.lpVtbl.*.Unmap.?(self.context, ptrAs(*c.ID3D11Resource, self.vertex_buffer), 0);
                self.context.lpVtbl.*.Draw.?(self.context, vertex_count, 0);
            } else {
                log.err("d3d11 map vertex buffer failed hr=0x{x}", .{@as(u32, @bitCast(@as(i32, hr_map)))});
            }
        }

        self.context.lpVtbl.*.CopyResource.?(
            self.context,
            ptrAs(*c.ID3D11Resource, self.capture_texture),
            ptrAs(*c.ID3D11Resource, self.back_buffer),
        );
        _ = self.swap_chain.lpVtbl.*.Present.?(self.swap_chain, 1, 0);
        self.frame_index +%= 1;
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

        _ = self.capture_texture.lpVtbl.*.Release.?(self.capture_texture);
        self.capture_texture = try createCaptureTexture(self.device, width, height);
    }

    pub fn deinit(self: *WindowsRenderer) void {
        @setRuntimeSafety(false);
        _ = self.vertex_buffer.lpVtbl.*.Release.?(self.vertex_buffer);
        _ = self.input_layout.lpVtbl.*.Release.?(self.input_layout);
        _ = self.pixel_shader.lpVtbl.*.Release.?(self.pixel_shader);
        _ = self.vertex_shader.lpVtbl.*.Release.?(self.vertex_shader);
        _ = self.checker_srv.lpVtbl.*.Release.?(self.checker_srv);
        _ = self.checker_texture.lpVtbl.*.Release.?(self.checker_texture);
        _ = self.capture_texture.lpVtbl.*.Release.?(self.capture_texture);
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
            ptrAs(*c.ID3D11Resource, self.capture_texture),
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
