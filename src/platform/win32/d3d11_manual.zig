const builtin = @import("builtin");
const d3d_c = @import("d3d_c.zig");
const dxgi_manual = @import("dxgi_manual.zig");
const c = d3d_c.c;

pub const D3D11_USAGE_DEFAULT: u32 = 0;
pub const D3D11_USAGE_DYNAMIC: u32 = 2;
pub const D3D11_USAGE_STAGING: u32 = 3;

pub const D3D11_BIND_VERTEX_BUFFER: u32 = 0x1;
pub const D3D11_BIND_CONSTANT_BUFFER: u32 = 0x4;
pub const D3D11_BIND_SHADER_RESOURCE: u32 = 0x8;

pub const D3D11_CPU_ACCESS_WRITE: u32 = 0x10000;
pub const D3D11_CPU_ACCESS_READ: u32 = 0x20000;

pub const D3D11_MAP_READ: u32 = 1;
pub const D3D11_MAP_WRITE_DISCARD: u32 = 4;
pub const D3D11_INPUT_PER_VERTEX_DATA: u32 = 0;
pub const D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST: u32 = 4;

pub const D3D11_TEXTURE2D_DESC = if (builtin.os.tag == .windows) extern struct {
    Width: c.UINT,
    Height: c.UINT,
    MipLevels: c.UINT,
    ArraySize: c.UINT,
    Format: c.DXGI_FORMAT,
    SampleDesc: dxgi_manual.DXGI_SAMPLE_DESC,
    Usage: c.UINT,
    BindFlags: c.UINT,
    CPUAccessFlags: c.UINT,
    MiscFlags: c.UINT,
} else struct {};

pub const D3D11_SUBRESOURCE_DATA = if (builtin.os.tag == .windows) extern struct {
    pSysMem: *const anyopaque,
    SysMemPitch: c.UINT,
    SysMemSlicePitch: c.UINT,
} else struct {};

pub const D3D11_BUFFER_DESC = if (builtin.os.tag == .windows) extern struct {
    ByteWidth: c.UINT,
    Usage: c.UINT,
    BindFlags: c.UINT,
    CPUAccessFlags: c.UINT,
    MiscFlags: c.UINT,
    StructureByteStride: c.UINT,
} else struct {};

pub const D3D11_MAPPED_SUBRESOURCE = if (builtin.os.tag == .windows) extern struct {
    pData: ?*anyopaque,
    RowPitch: c.UINT,
    DepthPitch: c.UINT,
} else struct {};

pub const D3D11_INPUT_ELEMENT_DESC = if (builtin.os.tag == .windows) extern struct {
    SemanticName: [*c]const u8,
    SemanticIndex: c.UINT,
    Format: c.DXGI_FORMAT,
    InputSlot: c.UINT,
    AlignedByteOffset: c.UINT,
    InputSlotClass: c.UINT,
    InstanceDataStepRate: c.UINT,
} else struct {};

pub const D3D11_VIEWPORT = if (builtin.os.tag == .windows) extern struct {
    TopLeftX: f32,
    TopLeftY: f32,
    Width: f32,
    Height: f32,
    MinDepth: f32,
    MaxDepth: f32,
} else struct {};
