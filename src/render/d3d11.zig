const builtin = @import("builtin");
const std = @import("std");
const win32 = @import("../platform/win32/window.zig");
const d3d_c = @import("../platform/win32/d3d_c.zig");
const d3d11_core = @import("../platform/win32/d3d11_core_manual.zig");
const d3d11_if = @import("../platform/win32/d3d11_interfaces_manual.zig");
const d3d11_manual = @import("../platform/win32/d3d11_manual.zig");
const d3dcompiler_manual = @import("../platform/win32/d3dcompiler_manual.zig");
const dxgi_manual = @import("../platform/win32/dxgi_manual.zig");
const dxgi_if_manual = @import("../platform/win32/dxgi_interfaces_manual.zig");
const com_iids = @import("../platform/win32/com_iids.zig");
const log = @import("../util/logging.zig");
const render_plan = @import("render_plan.zig");
const c = d3d_c.c;

pub const Renderer = if (builtin.os.tag == .windows) WindowsRenderer else StubRenderer;
pub const RenderView = enum(u32) {
    beauty = 0,
    depth = 1,
    role_id = 2,
};
pub const Display3DStatus = struct {
    requested: bool,
    enabled: bool,
    supported: bool,
};

const StubRenderer = struct {
    pub fn init(_: win32.HWND, _: u32, _: u32) !StubRenderer {
        return error.UnsupportedPlatform;
    }

    pub fn setDisplay3DMode(_: *StubRenderer, enable: bool) Display3DStatus {
        return .{
            .requested = enable,
            .enabled = false,
            .supported = false,
        };
    }

    pub fn render(_: *StubRenderer, _: u32, _: u32, _: render_plan.RenderPlan, _: []const u8, _: RenderView) void {}

    pub fn resize(_: *StubRenderer, _: u32, _: u32) !void {}

    pub fn deinit(_: *StubRenderer) void {}
};

const WindowsRenderer = struct {
    const Vertex = extern struct { x: f32, y: f32, z: f32, r: f32, g: f32, b: f32, a: f32 };
    const MaxDynamicVertices: u32 = 8192;
    const MaxRaymarchInstances: usize = 64;
    const LegendZ: f32 = 0.95;
    const LegendCellW: f32 = 0.010;
    const LegendCellH: f32 = 0.018;
    const LegendGap: f32 = 0.003;
    const LegendCharSpacing: f32 = 0.010;

    swap_chain: *dxgi_if_manual.IDXGISwapChain,
    device: *d3d11_if.ID3D11Device,
    context: *d3d11_if.ID3D11DeviceContext,
    back_buffer: *c.ID3D11Texture2D,
    rtv: *c.ID3D11RenderTargetView,
    checker_texture: *c.ID3D11Texture2D,
    checker_srv: *c.ID3D11ShaderResourceView,
    capture_texture: *c.ID3D11Texture2D,
    vertex_shader: *c.ID3D11VertexShader,
    pixel_shader: *c.ID3D11PixelShader,
    input_layout: *c.ID3D11InputLayout,
    vertex_buffer: *c.ID3D11Buffer,
    scene_cb: *c.ID3D11Buffer,
    display_3d_active: bool,

    pub fn init(hwnd: win32.HWND, width: u32, height: u32) !WindowsRenderer {
        @setRuntimeSafety(false);
        const desc = dxgi_manual.makeSwapChainDesc(hwnd, width, height);

        if (try tryCreate(desc, d3d11_core.D3D_DRIVER_TYPE_HARDWARE)) |r| {
            log.info("d3d11 init: driver=hardware", .{});
            return r;
        }

        log.err("d3d11 hardware init failed, retrying with WARP", .{});
        if (try tryCreate(desc, d3d11_core.D3D_DRIVER_TYPE_WARP)) |r| {
            log.info("d3d11 init: driver=warp", .{});
            return r;
        }

        return error.D3D11CreateDeviceAndSwapChainFailed;
    }

    fn tryCreate(desc: dxgi_manual.DXGI_SWAP_CHAIN_DESC, driver: d3d11_core.D3D_DRIVER_TYPE) !?WindowsRenderer {
        @setRuntimeSafety(false);
        var swap_chain: ?*dxgi_if_manual.IDXGISwapChain = null;
        var device: ?*d3d11_if.ID3D11Device = null;
        var context: ?*d3d11_if.ID3D11DeviceContext = null;
        var feature_level: d3d11_core.D3D_FEATURE_LEVEL = undefined;
        var local_desc = desc;

        const hr = d3d11_core.createDeviceAndSwapChain(
            driver,
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
            _ = swap_chain.?.lpVtbl.Release(swap_chain.?);
            log.err("d3d11 create RTV failed: {}", .{err});
            return null;
        };

        const checker = createCheckerTexture(device.?, desc.BufferDesc.Width, desc.BufferDesc.Height) catch |err| {
            _ = bb.rtv.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(bb.rtv)));
            _ = bb.back_buffer.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(bb.back_buffer)));
            _ = context.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(context.?)));
            _ = device.?.lpVtbl.*.Release.?(@ptrFromInt(@intFromPtr(device.?)));
            _ = swap_chain.?.lpVtbl.Release(swap_chain.?);
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
            _ = swap_chain.?.lpVtbl.Release(swap_chain.?);
            log.err("d3d11 create triangle pipeline failed: {}", .{err});
            return null;
        };
        const capture_texture = createCaptureTexture(device.?, desc.BufferDesc.Width, desc.BufferDesc.Height) catch |err| {
            _ = tri.scene_cb.lpVtbl.*.Release.?(tri.scene_cb);
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
            _ = swap_chain.?.lpVtbl.Release(swap_chain.?);
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
            .scene_cb = tri.scene_cb,
            .display_3d_active = false,
        };
    }

    pub fn setDisplay3DMode(self: *WindowsRenderer, enable: bool) Display3DStatus {
        if (!enable) {
            self.display_3d_active = false;
            return .{
                .requested = false,
                .enabled = false,
                .supported = false,
            };
        }

        const supported = self.isWindowedStereoSupported();
        self.display_3d_active = supported;
        return .{
            .requested = true,
            .enabled = supported,
            .supported = supported,
        };
    }

    fn isWindowedStereoSupported(self: *WindowsRenderer) bool {
        var dxgi_device_raw: ?*anyopaque = null;
        const hr_qi = self.device.lpVtbl.*.QueryInterface.?(
            self.device,
            &com_iids.IID_IDXGIDevice,
            ptrAs(*?*anyopaque, &dxgi_device_raw),
        );
        if (hr_qi != c.S_OK or dxgi_device_raw == null) return false;
        const dxgi_device: *dxgi_if_manual.IDXGIDevice = ptrAs(*dxgi_if_manual.IDXGIDevice, dxgi_device_raw.?);
        defer _ = dxgi_device.lpVtbl.Release(dxgi_device);

        var adapter: ?*dxgi_if_manual.IDXGIAdapter = null;
        const hr_adapter = dxgi_device.lpVtbl.GetAdapter(dxgi_device, &adapter);
        if (hr_adapter != c.S_OK or adapter == null) return false;
        defer _ = adapter.?.lpVtbl.Release(adapter.?);

        var factory_raw: ?*anyopaque = null;
        const hr_factory = adapter.?.lpVtbl.GetParent(
            adapter.?,
            &com_iids.IID_IDXGIFactory2,
            ptrAs(*?*anyopaque, &factory_raw),
        );
        if (hr_factory != c.S_OK or factory_raw == null) return false;
        const factory2: *dxgi_manual.IDXGIFactory2 = ptrAs(*dxgi_manual.IDXGIFactory2, factory_raw.?);
        defer _ = factory2.lpVtbl.Release(factory2);

        return factory2.lpVtbl.IsWindowedStereoEnabled(factory2) == c.TRUE;
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
        var tex_desc: d3d11_manual.D3D11_TEXTURE2D_DESC = std.mem.zeroes(d3d11_manual.D3D11_TEXTURE2D_DESC);
        tex_desc.Width = tex_w;
        tex_desc.Height = tex_h;
        tex_desc.MipLevels = 1;
        tex_desc.ArraySize = 1;
        tex_desc.Format = c.DXGI_FORMAT_R8G8B8A8_UNORM;
        tex_desc.SampleDesc.Count = 1;
        tex_desc.Usage = d3d11_manual.D3D11_USAGE_DEFAULT;

        var texture: ?*c.ID3D11Texture2D = null;
        const hr_tex = device.lpVtbl.*.CreateTexture2D.?(
            device,
            @as(*const c.D3D11_TEXTURE2D_DESC, @ptrCast(&tex_desc)),
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
        scene_cb: *c.ID3D11Buffer,
    };

    const SceneCB = extern struct {
        cam: [4]f32, // yaw_rad, pitch_rad, perspective, aspect
        light: [4]f32,
        screen: [4]f32, // width, height, _, _
        meta: [4]f32, // inst_count, debug_view, _, _
        inst_data0: [MaxRaymarchInstances][4]f32, // pos.xyz, scale
        inst_data1: [MaxRaymarchInstances][4]f32, // yaw_rad, shape_id, _, _
        inst_col: [MaxRaymarchInstances][4]f32, // rgba
    };

    fn compileShader(source: []const u8, entry: []const u8, target: []const u8) !*d3dcompiler_manual.ID3DBlob {
        var code: ?*d3dcompiler_manual.ID3DBlob = null;
        var errors: ?*d3dcompiler_manual.ID3DBlob = null;
        const hr = d3dcompiler_manual.compile(source, ptrAs([*:0]const u8, entry.ptr), ptrAs([*:0]const u8, target.ptr), &code, &errors);
        if (hr != c.S_OK or code == null) {
            if (errors) |e| {
                const msg_ptr: [*]const u8 = @ptrFromInt(@intFromPtr(e.lpVtbl.GetBufferPointer(e)));
                const msg_len: usize = e.lpVtbl.GetBufferSize(e);
                const msg = msg_ptr[0..msg_len];
                log.err("hlsl compile failed: {s}", .{msg});
                _ = e.lpVtbl.Release(e);
            }
            return error.D3D11CompileShaderFailed;
        }
        if (errors) |e| _ = e.lpVtbl.Release(e);
        return code.?;
    }

    fn createTrianglePipeline(device: *c.ID3D11Device) !TrianglePipeline {
        const vs_src =
            \\struct VSIn { float3 pos : POSITION; float4 col : COLOR; };
            \\struct VSOut { float4 pos : SV_POSITION; float4 col : COLOR; };
            \\VSOut main(VSIn i) {
            \\  VSOut o;
            \\  o.pos = float4(i.pos, 1.0);
            \\  o.col = i.col;
            \\  return o;
            \\}
        ;
        const ps_src =
            \\// Raymarch SDF primitives inspired by Inigo Quilez references.
            \\// Requested source: https://www.shadertoy.com/view/Xds3zN
            \\cbuffer SceneCB : register(b0) {
            \\  float4 cam;
            \\  float4 light_dir;
            \\  float4 screen;
            \\  float4 meta;
            \\  float4 inst_data0[64];
            \\  float4 inst_data1[64];
            \\  float4 inst_col[64];
            \\};
            \\struct PSIn { float4 pos : SV_POSITION; float4 col : COLOR; };
            \\struct Hit { float d; float4 col; float shape; };
            \\float3 roleIdColor(float shape) {
            \\  if (shape < 0.5) return float3(1.0, 0.34, 0.20);   // carry
            \\  if (shape < 1.5) return float3(0.98, 0.78, 0.20);  // borrow
            \\  if (shape < 2.5) return float3(0.22, 0.90, 1.0);   // shift
            \\  if (shape < 3.5) return float3(0.60, 0.95, 0.48);  // source
            \\  if (shape < 4.5) return float3(0.34, 0.72, 1.0);   // result
            \\  if (shape < 5.5) return float3(0.98, 0.46, 0.88);  // partial row
            \\  if (shape < 6.5) return float3(1.0, 1.0, 1.0);     // active
            \\  return float3(0.30, 0.30, 0.30);                   // ground/other
            \\}
            \\float sdSphere(float3 p, float s) { return length(p) - s; }
            \\float sdBox(float3 p, float3 b) {
            \\  float3 q = abs(p) - b;
            \\  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
            \\}
            \\float sdTorus(float3 p, float2 t) {
            \\  float2 q = float2(length(p.xz) - t.x, p.y);
            \\  return length(q) - t.y;
            \\}
            \\float sdCapsuleY(float3 p, float h, float r) {
            \\  p.y -= clamp(p.y, -h, h);
            \\  return length(p) - r;
            \\}
            \\float opU(float a, float b) { return min(a, b); }
            \\float3 rotY(float3 p, float a) {
            \\  float c = cos(a), s = sin(a);
            \\  return float3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
            \\}
            \\Hit mapScene(float3 p) {
            \\  Hit h; h.d = 1e9; h.col = float4(0,0,0,1); h.shape = 7.0;
            \\  [loop]
            \\  for (uint i = 0; i < (uint)meta.x; ++i) {
            \\    float3 c = inst_data0[i].xyz;
            \\    float scale = inst_data0[i].w;
            \\    float yaw = inst_data1[i].x;
            \\    float shape = inst_data1[i].y;
            \\    float3 q = rotY(p - c, yaw);
            \\    float d = 1e9;
            \\    if (shape < 0.5) {
            \\      // carry packet: core orb + orbit ring + directional fin
            \\      float core = sdSphere(q, 0.20 * scale);
            \\      float ring = sdTorus(q + float3(0.0, 0.03 * scale, 0.0), float2(0.24 * scale, 0.04 * scale));
            \\      float fin = sdBox(q - float3(0.0, 0.0, 0.22 * scale), float3(0.07, 0.03, 0.12) * scale);
            \\      d = opU(opU(core, ring), fin);
            \\    } else if (shape < 1.5) {
            \\      // borrow packet: denser knot, lower center of mass
            \\      float knot = sdBox(q, float3(0.13, 0.13, 0.13) * scale);
            \\      float side_a = sdSphere(q + float3(0.15 * scale, -0.02 * scale, 0.0), 0.09 * scale);
            \\      float side_b = sdSphere(q + float3(-0.15 * scale, -0.02 * scale, 0.0), 0.09 * scale);
            \\      float bridge = sdCapsuleY(q + float3(0.0, -0.04 * scale, 0.0), 0.08 * scale, 0.05 * scale);
            \\      d = opU(opU(knot, side_a), opU(side_b, bridge));
            \\    } else if (shape < 2.5) {
            \\      // shift packet: directional capsule with trailing torus
            \\      float body = sdCapsuleY(q, 0.22 * scale, 0.08 * scale);
            \\      float nose = sdSphere(q - float3(0.0, 0.0, 0.22 * scale), 0.10 * scale);
            \\      float wake = sdTorus(q + float3(0.0, 0.0, 0.24 * scale), float2(0.12 * scale, 0.03 * scale));
            \\      d = opU(opU(body, nose), wake);
            \\    } else if (shape < 3.5) {
            \\      // source digit column: pedestal + stem + cap
            \\      float pedestal = sdBox(q + float3(0.0, 0.18 * scale, 0.0), float3(0.20, 0.07, 0.20) * scale);
            \\      float stem = sdBox(q - float3(0.0, 0.02 * scale, 0.0), float3(0.11, 0.22, 0.11) * scale);
            \\      float cap = sdTorus(q - float3(0.0, 0.30 * scale, 0.0), float2(0.14 * scale, 0.03 * scale));
            \\      d = opU(opU(pedestal, stem), cap);
            \\    } else if (shape < 4.5) {
            \\      // result digit column: broader settled shape + crown pearl
            \\      float body = sdBox(q, float3(0.20, 0.18, 0.20) * scale);
            \\      float crown = sdSphere(q - float3(0.0, 0.26 * scale, 0.0), 0.09 * scale);
            \\      float collar = sdTorus(q - float3(0.0, 0.15 * scale, 0.0), float2(0.18 * scale, 0.025 * scale));
            \\      d = opU(opU(body, crown), collar);
            \\    } else if (shape < 5.5) {
            \\      // partial row marker: ribbon with rounded end-caps
            \\      float ribbon = sdBox(q, float3(0.34, 0.03, 0.08) * scale);
            \\      float cap_a = sdSphere(q + float3(0.34 * scale, 0.0, 0.0), 0.055 * scale);
            \\      float cap_b = sdSphere(q - float3(0.34 * scale, 0.0, 0.0), 0.055 * scale);
            \\      d = opU(opU(ribbon, cap_a), cap_b);
            \\    } else {
            \\      // active marker: compact beacon
            \\      float stem = sdCapsuleY(q + float3(0.0, 0.05 * scale, 0.0), 0.11 * scale, 0.045 * scale);
            \\      float head = sdSphere(q - float3(0.0, 0.12 * scale, 0.0), 0.08 * scale);
            \\      d = opU(stem, head);
            \\    }
            \\    if (d < h.d) { h.d = d; h.col = inst_col[i]; h.shape = shape; }
            \\  }
            \\  float ground = p.y + 0.72;
            \\  if (ground < h.d) {
            \\    h.d = ground;
            \\    h.col = float4(0.16, 0.15, 0.14, 1.0);
            \\    h.shape = 7.0;
            \\  }
            \\  return h;
            \\}
            \\float3 estimateNormal(float3 p) {
            \\  const float e = 0.0012;
            \\  float dx = mapScene(p + float3(e,0,0)).d - mapScene(p - float3(e,0,0)).d;
            \\  float dy = mapScene(p + float3(0,e,0)).d - mapScene(p - float3(0,e,0)).d;
            \\  float dz = mapScene(p + float3(0,0,e)).d - mapScene(p - float3(0,0,e)).d;
            \\  return normalize(float3(dx,dy,dz));
            \\}
            \\float calcAO(float3 p, float3 n) {
            \\  float occ = 0.0;
            \\  float sca = 1.0;
            \\  [unroll]
            \\  for (int i = 1; i <= 4; ++i) {
            \\    float h = 0.03 * i;
            \\    float d = mapScene(p + n * h).d;
            \\    occ += (h - d) * sca;
            \\    sca *= 0.65;
            \\  }
            \\  return saturate(1.0 - occ * 2.0);
            \\}
            \\float softShadow(float3 ro, float3 rd, float mint, float maxt, float k) {
            \\  float res = 1.0;
            \\  float t = mint;
            \\  [loop]
            \\  for (int i = 0; i < 32; ++i) {
            \\    float h = mapScene(ro + rd * t).d;
            \\    if (h < 0.001) return 0.0;
            \\    res = min(res, k * h / t);
            \\    t += clamp(h, 0.01, 0.25);
            \\    if (t > maxt) break;
            \\  }
            \\  return saturate(res);
            \\}
            \\float4 main(PSIn i) : SV_TARGET {
            \\  float2 uv = (i.pos.xy / screen.xy) * 2.0 - 1.0;
            \\  uv.x *= cam.w;
            \\  float yaw = cam.x;
            \\  float pitch = cam.y;
            \\  float cy = cos(yaw), sy = sin(yaw), cp = cos(pitch), sp = sin(pitch);
            \\  float3 fwd = normalize(float3(cp * sy, sp, cp * cy));
            \\  float3 right = normalize(cross(float3(0,1,0), fwd));
            \\  float3 up = normalize(cross(fwd, right));
            \\  float scene_extent = max(screen.z, 0.5);
            \\  float3 ro = -fwd * (scene_extent * (1.2 + (1.0 - cam.z) * 0.6));
            \\  float3 rd = normalize(fwd + uv.x * right + uv.y * up);
            \\  float debug_view = meta.y;
            \\  float t = 0.0;
            \\  Hit h;
            \\  [loop]
            \\  for (int s = 0; s < 96; ++s) {
            \\    float3 p = ro + rd * t;
            \\    h = mapScene(p);
            \\    if (h.d < 0.001) {
            \\      if (debug_view > 0.5 && debug_view < 1.5) {
            \\        float dep = saturate(t / (scene_extent * 3.5 + 0.001));
            \\        return float4(dep, dep, dep, 1.0);
            \\      }
            \\      if (debug_view > 1.5) {
            \\        return float4(roleIdColor(h.shape), 1.0);
            \\      }
            \\      float3 n = estimateNormal(p);
            \\      float3 ldir = normalize(light_dir.xyz);
            \\      float diff = max(dot(n, ldir), 0.0);
            \\      float sh = softShadow(p + n * 0.003, ldir, 0.02, 8.0, 8.0);
            \\      float ao = calcAO(p, n);
            \\      float rim = pow(1.0 - max(dot(n, -rd), 0.0), 2.0);
            \\      float3 bounce = float3(0.08, 0.07, 0.06) * max(0.0, -n.y) * 0.5;
            \\      float3 lit = h.col.rgb * (0.10 + diff * sh * 0.95) * ao + rim * 0.12 + bounce;
            \\      return float4(saturate(lit), 1.0);
            \\    }
            \\    t += h.d;
            \\    if (t > scene_extent * 10.0 + 20.0) break;
            \\  }
            \\  if (debug_view > 0.5 && debug_view < 1.5) {
            \\    return float4(1.0, 1.0, 1.0, 1.0);
            \\  }
            \\  if (debug_view > 1.5) {
            \\    return float4(0.0, 0.0, 0.0, 1.0);
            \\  }
            \\  float v = 0.4 + 0.6 * (1.0 - uv.y * 0.5);
            \\  return float4(0.04 * v, 0.05 * v, 0.08 * v, 1.0);
            \\}
        ;

        const vs_blob = try compileShader(vs_src, "main\x00", "vs_4_0\x00");
        defer _ = vs_blob.lpVtbl.Release(vs_blob);
        const ps_blob = try compileShader(ps_src, "main\x00", "ps_4_0\x00");
        defer _ = ps_blob.lpVtbl.Release(ps_blob);

        var vs: ?*c.ID3D11VertexShader = null;
        var ps: ?*c.ID3D11PixelShader = null;

        const hr_vs = device.lpVtbl.*.CreateVertexShader.?(
            device,
            vs_blob.lpVtbl.GetBufferPointer(vs_blob),
            vs_blob.lpVtbl.GetBufferSize(vs_blob),
            null,
            &vs,
        );
        if (hr_vs != c.S_OK or vs == null) return error.D3D11CreateVertexShaderFailed;

        const hr_ps = device.lpVtbl.*.CreatePixelShader.?(
            device,
            ps_blob.lpVtbl.GetBufferPointer(ps_blob),
            ps_blob.lpVtbl.GetBufferSize(ps_blob),
            null,
            &ps,
        );
        if (hr_ps != c.S_OK or ps == null) {
            _ = vs.?.lpVtbl.*.Release.?(vs.?);
            return error.D3D11CreatePixelShaderFailed;
        }

        var elems = [_]d3d11_manual.D3D11_INPUT_ELEMENT_DESC{
            .{
                .SemanticName = ptrAs([*c]const u8, "POSITION\x00".ptr),
                .SemanticIndex = 0,
                .Format = c.DXGI_FORMAT_R32G32B32_FLOAT,
                .InputSlot = 0,
                .AlignedByteOffset = 0,
                .InputSlotClass = d3d11_manual.D3D11_INPUT_PER_VERTEX_DATA,
                .InstanceDataStepRate = 0,
            },
            .{
                .SemanticName = ptrAs([*c]const u8, "COLOR\x00".ptr),
                .SemanticIndex = 0,
                .Format = c.DXGI_FORMAT_R32G32B32A32_FLOAT,
                .InputSlot = 0,
                .AlignedByteOffset = 12,
                .InputSlotClass = d3d11_manual.D3D11_INPUT_PER_VERTEX_DATA,
                .InstanceDataStepRate = 0,
            },
        };

        var layout: ?*c.ID3D11InputLayout = null;
        const hr_layout = device.lpVtbl.*.CreateInputLayout.?(
            device,
            @as([*c]const c.D3D11_INPUT_ELEMENT_DESC, @ptrCast(&elems)),
            elems.len,
            vs_blob.lpVtbl.GetBufferPointer(vs_blob),
            vs_blob.lpVtbl.GetBufferSize(vs_blob),
            &layout,
        );
        if (hr_layout != c.S_OK or layout == null) {
            _ = ps.?.lpVtbl.*.Release.?(ps.?);
            _ = vs.?.lpVtbl.*.Release.?(vs.?);
            return error.D3D11CreateInputLayoutFailed;
        }

        var vb_desc: d3d11_manual.D3D11_BUFFER_DESC = std.mem.zeroes(d3d11_manual.D3D11_BUFFER_DESC);
        vb_desc.ByteWidth = MaxDynamicVertices * @sizeOf(Vertex);
        vb_desc.Usage = d3d11_manual.D3D11_USAGE_DYNAMIC;
        vb_desc.BindFlags = d3d11_manual.D3D11_BIND_VERTEX_BUFFER;
        vb_desc.CPUAccessFlags = d3d11_manual.D3D11_CPU_ACCESS_WRITE;

        var vb: ?*c.ID3D11Buffer = null;
        const hr_vb = device.lpVtbl.*.CreateBuffer.?(
            device,
            @as(*const c.D3D11_BUFFER_DESC, @ptrCast(&vb_desc)),
            null,
            &vb,
        );
        if (hr_vb != c.S_OK or vb == null) {
            _ = layout.?.lpVtbl.*.Release.?(layout.?);
            _ = ps.?.lpVtbl.*.Release.?(ps.?);
            _ = vs.?.lpVtbl.*.Release.?(vs.?);
            return error.D3D11CreateVertexBufferFailed;
        }

        var cb_desc: d3d11_manual.D3D11_BUFFER_DESC = std.mem.zeroes(d3d11_manual.D3D11_BUFFER_DESC);
        cb_desc.ByteWidth = @sizeOf(SceneCB);
        cb_desc.Usage = d3d11_manual.D3D11_USAGE_DYNAMIC;
        cb_desc.BindFlags = d3d11_manual.D3D11_BIND_CONSTANT_BUFFER;
        cb_desc.CPUAccessFlags = d3d11_manual.D3D11_CPU_ACCESS_WRITE;
        var scene_cb: ?*c.ID3D11Buffer = null;
        const hr_cb = device.lpVtbl.*.CreateBuffer.?(device, @as(*const c.D3D11_BUFFER_DESC, @ptrCast(&cb_desc)), null, &scene_cb);
        if (hr_cb != c.S_OK or scene_cb == null) {
            _ = vb.?.lpVtbl.*.Release.?(vb.?);
            _ = layout.?.lpVtbl.*.Release.?(layout.?);
            _ = ps.?.lpVtbl.*.Release.?(ps.?);
            _ = vs.?.lpVtbl.*.Release.?(vs.?);
            return error.D3D11CreateConstantBufferFailed;
        }

        return .{
            .vertex_shader = vs.?,
            .pixel_shader = ps.?,
            .input_layout = layout.?,
            .vertex_buffer = vb.?,
            .scene_cb = scene_cb.?,
        };
    }

    fn createCheckerTexture(device: *c.ID3D11Device, tex_w: u32, tex_h: u32) !Checker {
        @setRuntimeSafety(false);
        const pixel_count: usize = @as(usize, tex_w) * @as(usize, tex_h);
        const pixels = try std.heap.page_allocator.alloc(u32, pixel_count);
        defer std.heap.page_allocator.free(pixels);

        for (0..tex_h) |y| {
            for (0..tex_w) |x| {
                const check = ((x / 8) + (y / 8)) % 2 == 0;
                // RGBA8 two-tone palette: warm orange and cyan-blue.
                const color: u32 = if (check) 0xFF1E96FF else 0xFFFFA31A;
                pixels[y * tex_w + x] = color;
            }
        }

        var tex_desc: d3d11_manual.D3D11_TEXTURE2D_DESC = std.mem.zeroes(d3d11_manual.D3D11_TEXTURE2D_DESC);
        tex_desc.Width = tex_w;
        tex_desc.Height = tex_h;
        tex_desc.MipLevels = 1;
        tex_desc.ArraySize = 1;
        tex_desc.Format = c.DXGI_FORMAT_R8G8B8A8_UNORM;
        tex_desc.SampleDesc.Count = 1;
        tex_desc.Usage = d3d11_manual.D3D11_USAGE_DEFAULT;
        tex_desc.BindFlags = d3d11_manual.D3D11_BIND_SHADER_RESOURCE;

        var init_data: d3d11_manual.D3D11_SUBRESOURCE_DATA = std.mem.zeroes(d3d11_manual.D3D11_SUBRESOURCE_DATA);
        init_data.pSysMem = ptrAs(*const anyopaque, pixels.ptr);
        init_data.SysMemPitch = tex_w * 4;

        var texture: ?*c.ID3D11Texture2D = null;
        const hr_tex = device.lpVtbl.*.CreateTexture2D.?(
            device,
            @as(*const c.D3D11_TEXTURE2D_DESC, @ptrCast(&tex_desc)),
            @as(*const c.D3D11_SUBRESOURCE_DATA, @ptrCast(&init_data)),
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

    fn createBackBufferAndRTV(device: *c.ID3D11Device, swap_chain: *dxgi_if_manual.IDXGISwapChain) !BackBufferBundle {
        @setRuntimeSafety(false);
        var back_buffer_raw: ?*anyopaque = null;
        const hr_buf = swap_chain.lpVtbl.GetBuffer(
            swap_chain,
            0,
            &com_iids.IID_ID3D11Texture2D,
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
            .partial_row_marker => 0.060,
            .active_marker => 0.050,
        };
    }

    fn shapeIdForRole(role: render_plan.DrawRole) f32 {
        return switch (role) {
            .carry_packet => 0.0,
            .borrow_packet => 1.0,
            .shift_packet => 2.0,
            .source_digit => 3.0,
            .result_digit => 4.0,
            .partial_row_marker => 5.0,
            .active_marker => 6.0,
        };
    }

    fn fillSceneCB(plan: render_plan.RenderPlan, width: u32, height: u32, view: RenderView) SceneCB {
        var cb = std.mem.zeroes(SceneCB);

        const yaw = plan.camera.yaw_deg * std.math.pi / 180.0;
        const pitch = plan.camera.pitch_deg * std.math.pi / 180.0;
        const aspect = @as(f32, @floatFromInt(width)) / @max(1.0, @as(f32, @floatFromInt(height)));
        cb.cam = .{ yaw, pitch, plan.camera.perspective, aspect };
        cb.light = .{ 0.45, 0.85, -0.25, 0.0 };
        cb.screen = .{ @as(f32, @floatFromInt(width)), @as(f32, @floatFromInt(height)), 1.0, 0.0 };

        const count: usize = @min(plan.points.len, MaxRaymarchInstances);
        cb.meta[0] = @as(f32, @floatFromInt(count));
        cb.meta[1] = @as(f32, @floatFromInt(@intFromEnum(view)));

        var cx: f32 = 0.0;
        var cy: f32 = 0.0;
        var cz: f32 = 0.0;
        if (count > 0) {
            for (plan.points[0..count]) |p| {
                cx += p.x;
                cy += p.y;
                cz += p.z;
            }
            const inv = 1.0 / @as(f32, @floatFromInt(count));
            cx *= inv;
            cy *= inv;
            cz *= inv;
        }

        var extent: f32 = 1.0;
        if (count > 0) {
            extent = 0.0;
            for (plan.points[0..count]) |p| {
                const dx = p.x - cx;
                const dy = p.y - cy;
                const dz = p.z - cz;
                const r = @sqrt(dx * dx + dy * dy + dz * dz) + p.scale * 0.25;
                extent = @max(extent, r);
            }
            extent = @max(extent, 0.6);
        }
        cb.screen[2] = extent;

        for (plan.points[0..count], 0..) |p, i| {
            cb.inst_data0[i] = .{ p.x - cx, p.y - cy, p.z - cz, p.scale };
            cb.inst_data1[i] = .{ p.yaw_deg * std.math.pi / 180.0, shapeIdForRole(p.role), 0.0, 0.0 };
            cb.inst_col[i] = .{ p.r, p.g, p.b, p.a };
        }
        return cb;
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

    fn appendTriangle(
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
        const x0 = cx;
        const y0 = cy + half_size;
        const x1 = cx - half_size;
        const y1 = cy - half_size;
        const x2 = cx + half_size;
        const y2 = cy - half_size;
        verts[base.* + 0] = .{ .x = x0, .y = y0, .z = z, .r = r, .g = g, .b = b, .a = a };
        verts[base.* + 1] = .{ .x = x1, .y = y1, .z = z, .r = r, .g = g, .b = b, .a = a };
        verts[base.* + 2] = .{ .x = x2, .y = y2, .z = z, .r = r, .g = g, .b = b, .a = a };
        base.* += 3;
    }

    fn appendFullscreenTriangleNdc(verts: []Vertex, base: *usize) void {
        verts[base.* + 0] = .{ .x = -1.0, .y = -1.0, .z = 0.0, .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };
        // Keep clockwise winding (D3D11 default front-face) so it is not culled.
        verts[base.* + 1] = .{ .x = -1.0, .y = 3.0, .z = 0.0, .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };
        verts[base.* + 2] = .{ .x = 3.0, .y = -1.0, .z = 0.0, .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };
        base.* += 3;
    }

    const Projected = struct {
        x: f32,
        y: f32,
        z: f32,
    };

    fn projectPoint(world_x: f32, world_y: f32, world_z: f32, yaw_deg: f32, pitch_deg: f32, perspective: f32) Projected {
        const yaw = yaw_deg * std.math.pi / 180.0;
        const pitch = pitch_deg * std.math.pi / 180.0;
        const yaw_c = @cos(yaw);
        const yaw_s = @sin(yaw);
        const pitch_c = @cos(pitch);
        const pitch_s = @sin(pitch);

        const xz_x = world_x * yaw_c - world_z * yaw_s;
        const xz_z = world_x * yaw_s + world_z * yaw_c;
        const yz_y = world_y * pitch_c - xz_z * pitch_s;
        const yz_z = world_y * pitch_s + xz_z * pitch_c;
        const persp = 1.0 / (1.0 + @max(0.0, yz_z) * perspective);
        return .{
            .x = xz_x * persp,
            .y = yz_y * persp,
            .z = clamp01(world_z * 0.8 + yz_z * 0.2),
        };
    }

    fn buildPlanVertices(
        self: *WindowsRenderer,
        allocator: std.mem.Allocator,
        width: u32,
        height: u32,
        plan: render_plan.RenderPlan,
        legend_text: []const u8,
    ) ![]Vertex {
        _ = self;
        _ = width;
        _ = height;

        if (plan.points.len == 0 and legend_text.len == 0) return allocator.alloc(Vertex, 0);
        const legend_budget: usize = legend_text.len * 15 * 6;
        var geom_budget: usize = 0;
        for (plan.points) |p| {
            geom_budget += switch (p.role) {
                .carry_packet, .borrow_packet, .shift_packet, .partial_row_marker => 3,
                else => 6,
            };
        }
        const needed: usize = geom_budget + legend_budget + 3;
        if (needed > MaxDynamicVertices) return error.RenderPlanTooLarge;

        const yaw_deg = plan.camera.yaw_deg;
        const pitch_deg = plan.camera.pitch_deg;
        const perspective = plan.camera.perspective;

        var min_x: f32 = -1.0;
        var max_x: f32 = 1.0;
        var min_y: f32 = -1.0;
        var max_y: f32 = 1.0;
        if (plan.points.len > 0) {
            const p0 = projectPoint(plan.points[0].x, plan.points[0].y, plan.points[0].z, yaw_deg, pitch_deg, perspective);
            min_x = p0.x;
            max_x = p0.x;
            min_y = p0.y;
            max_y = p0.y;
            for (plan.points[1..]) |p| {
                const pp = projectPoint(p.x, p.y, p.z, yaw_deg, pitch_deg, perspective);
                min_x = @min(min_x, pp.x);
                max_x = @max(max_x, pp.x);
                min_y = @min(min_y, pp.y);
                max_y = @max(max_y, pp.y);
            }
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
            const pp = projectPoint(p.x, p.y, p.z, yaw_deg, pitch_deg, perspective);
            const nx = ((pp.x - min_x) / span_x) * 1.8 - 0.9;
            const ny = ((pp.y - min_y) / span_y) * 1.8 - 0.9;
            const nz = clamp01(pp.z);
            const hs = roleSize(p.role) * @max(0.6, @min(1.8, p.scale));
            const r = clamp01(p.r);
            const g = clamp01(p.g);
            const b = clamp01(p.b);
            const a = clamp01(p.a);
            switch (p.role) {
                .carry_packet, .borrow_packet, .shift_packet, .partial_row_marker => {
                    const yaw = p.yaw_deg * std.math.pi / 180.0;
                    const rx = nx + @cos(yaw) * hs * 0.15;
                    const ry = ny + @sin(yaw) * hs * 0.15;
                    appendTriangle(vertices, &n, rx, ry, nz, hs, r, g, b, a);
                },
                else => appendQuad(vertices, &n, nx, ny, nz, hs, r, g, b, a),
            }
        }
        appendLegendText(vertices, &n, legend_text);
        appendFullscreenTriangleNdc(vertices, &n);

        return vertices[0..n];
    }

    pub fn render(self: *WindowsRenderer, width: u32, height: u32, plan: render_plan.RenderPlan, legend_text: []const u8, view: RenderView) void {
        @setRuntimeSafety(false);
        var rtvs = [_]?*c.ID3D11RenderTargetView{self.rtv};
        self.context.lpVtbl.*.OMSetRenderTargets.?(self.context, 1, &rtvs, null);

        var vp: d3d11_manual.D3D11_VIEWPORT = std.mem.zeroes(d3d11_manual.D3D11_VIEWPORT);
        vp.Width = @floatFromInt(width);
        vp.Height = @floatFromInt(height);
        vp.MinDepth = 0.0;
        vp.MaxDepth = 1.0;
        self.context.lpVtbl.*.RSSetViewports.?(self.context, 1, @as([*c]const c.D3D11_VIEWPORT, @ptrCast(&vp)));

        self.context.lpVtbl.*.CopyResource.?(
            self.context,
            ptrAs(*c.ID3D11Resource, self.back_buffer),
            ptrAs(*c.ID3D11Resource, self.checker_texture),
        );

        const stride = [_]c.UINT{@sizeOf(f32) * 7};
        const offset = [_]c.UINT{0};
        const vb = [_]?*c.ID3D11Buffer{self.vertex_buffer};
        self.context.lpVtbl.*.IASetInputLayout.?(self.context, self.input_layout);
        self.context.lpVtbl.*.IASetPrimitiveTopology.?(self.context, d3d11_manual.D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        self.context.lpVtbl.*.IASetVertexBuffers.?(self.context, 0, 1, &vb, &stride, &offset);
        self.context.lpVtbl.*.VSSetShader.?(self.context, self.vertex_shader, null, 0);
        self.context.lpVtbl.*.PSSetShader.?(self.context, self.pixel_shader, null, 0);
        const cbs = [_]?*c.ID3D11Buffer{self.scene_cb};
        self.context.lpVtbl.*.PSSetConstantBuffers.?(self.context, 0, 1, &cbs);

        const cb_data = fillSceneCB(plan, width, height, view);
        var mapped_cb: d3d11_manual.D3D11_MAPPED_SUBRESOURCE = std.mem.zeroes(d3d11_manual.D3D11_MAPPED_SUBRESOURCE);
        const hr_cb = self.context.lpVtbl.*.Map.?(
            self.context,
            ptrAs(*c.ID3D11Resource, self.scene_cb),
            0,
            d3d11_manual.D3D11_MAP_WRITE_DISCARD,
            0,
            @as(*c.D3D11_MAPPED_SUBRESOURCE, @ptrCast(&mapped_cb)),
        );
        if (hr_cb == c.S_OK and mapped_cb.pData != null) {
            const src = std.mem.asBytes(&cb_data);
            const dst = ptrAs([*]u8, mapped_cb.pData.?)[0..src.len];
            @memcpy(dst, src);
            self.context.lpVtbl.*.Unmap.?(self.context, ptrAs(*c.ID3D11Resource, self.scene_cb), 0);
        } else {
            log.err("d3d11 map scene constants failed hr=0x{x}", .{@as(u32, @bitCast(@as(i32, hr_cb)))});
        }

        var vertex_count: u32 = 0;
        const verts = self.buildPlanVertices(std.heap.page_allocator, width, height, plan, legend_text) catch |err| {
            log.err("render plan build failed: {}", .{err});
            _ = self.swap_chain.lpVtbl.Present(self.swap_chain, 1, 0);
            return;
        };
        defer std.heap.page_allocator.free(verts);
        vertex_count = @as(u32, @intCast(verts.len));

        if (vertex_count > 0) {
            var mapped: d3d11_manual.D3D11_MAPPED_SUBRESOURCE = std.mem.zeroes(d3d11_manual.D3D11_MAPPED_SUBRESOURCE);
            const hr_map = self.context.lpVtbl.*.Map.?(
                self.context,
                ptrAs(*c.ID3D11Resource, self.vertex_buffer),
                0,
                d3d11_manual.D3D11_MAP_WRITE_DISCARD,
                0,
                @as(*c.D3D11_MAPPED_SUBRESOURCE, @ptrCast(&mapped)),
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
        _ = self.swap_chain.lpVtbl.Present(self.swap_chain, 1, 0);
    }

    pub fn resize(self: *WindowsRenderer, width: u32, height: u32) !void {
        @setRuntimeSafety(false);
        if (width == 0 or height == 0) return;

        _ = self.rtv.lpVtbl.*.Release.?(self.rtv);
        _ = self.back_buffer.lpVtbl.*.Release.?(self.back_buffer);
        const hr = self.swap_chain.lpVtbl.ResizeBuffers(self.swap_chain, 0, width, height, c.DXGI_FORMAT_UNKNOWN, 0);
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
        _ = self.scene_cb.lpVtbl.*.Release.?(self.scene_cb);
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
        _ = self.swap_chain.lpVtbl.Release(self.swap_chain);
    }

    pub fn captureScreenshot(self: *WindowsRenderer, path: []const u8, width: u32, height: u32) !void {
        @setRuntimeSafety(false);
        var desc: d3d11_manual.D3D11_TEXTURE2D_DESC = std.mem.zeroes(d3d11_manual.D3D11_TEXTURE2D_DESC);
        desc.Width = width;
        desc.Height = height;
        desc.MipLevels = 1;
        desc.ArraySize = 1;
        desc.Format = c.DXGI_FORMAT_R8G8B8A8_UNORM;
        desc.SampleDesc.Count = 1;
        desc.Usage = d3d11_manual.D3D11_USAGE_STAGING;
        desc.CPUAccessFlags = d3d11_manual.D3D11_CPU_ACCESS_READ;

        var staging: ?*c.ID3D11Texture2D = null;
        const hr_tex = self.device.lpVtbl.*.CreateTexture2D.?(
            self.device,
            @as(*const c.D3D11_TEXTURE2D_DESC, @ptrCast(&desc)),
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

        var mapped: d3d11_manual.D3D11_MAPPED_SUBRESOURCE = std.mem.zeroes(d3d11_manual.D3D11_MAPPED_SUBRESOURCE);
        const hr_map = self.context.lpVtbl.*.Map.?(
            self.context,
            ptrAs(*c.ID3D11Resource, staging.?),
            0,
            d3d11_manual.D3D11_MAP_READ,
            0,
            @as(*c.D3D11_MAPPED_SUBRESOURCE, @ptrCast(&mapped)),
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
