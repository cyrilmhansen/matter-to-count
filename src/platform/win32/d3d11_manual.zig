const builtin = @import("builtin");
const dxgi_manual = @import("dxgi_manual.zig");
const win = @import("win_types.zig");

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
    Width: win.UINT,
    Height: win.UINT,
    MipLevels: win.UINT,
    ArraySize: win.UINT,
    Format: dxgi_manual.DXGI_FORMAT,
    SampleDesc: dxgi_manual.DXGI_SAMPLE_DESC,
    Usage: win.UINT,
    BindFlags: win.UINT,
    CPUAccessFlags: win.UINT,
    MiscFlags: win.UINT,
} else struct {};

pub const D3D11_SUBRESOURCE_DATA = if (builtin.os.tag == .windows) extern struct {
    pSysMem: *const anyopaque,
    SysMemPitch: win.UINT,
    SysMemSlicePitch: win.UINT,
} else struct {};

pub const D3D11_BUFFER_DESC = if (builtin.os.tag == .windows) extern struct {
    ByteWidth: win.UINT,
    Usage: win.UINT,
    BindFlags: win.UINT,
    CPUAccessFlags: win.UINT,
    MiscFlags: win.UINT,
    StructureByteStride: win.UINT,
} else struct {};

pub const D3D11_MAPPED_SUBRESOURCE = if (builtin.os.tag == .windows) extern struct {
    pData: ?*anyopaque,
    RowPitch: win.UINT,
    DepthPitch: win.UINT,
} else struct {};

pub const D3D11_INPUT_ELEMENT_DESC = if (builtin.os.tag == .windows) extern struct {
    SemanticName: [*c]const u8,
    SemanticIndex: win.UINT,
    Format: dxgi_manual.DXGI_FORMAT,
    InputSlot: win.UINT,
    AlignedByteOffset: win.UINT,
    InputSlotClass: win.UINT,
    InstanceDataStepRate: win.UINT,
} else struct {};

pub const D3D11_VIEWPORT = if (builtin.os.tag == .windows) extern struct {
    TopLeftX: f32,
    TopLeftY: f32,
    Width: f32,
    Height: f32,
    MinDepth: f32,
    MaxDepth: f32,
} else struct {};
