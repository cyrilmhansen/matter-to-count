const builtin = @import("builtin");
const d3d11_if = @import("d3d11_interfaces_manual.zig");
const dxgi_manual = @import("dxgi_manual.zig");
const dxgi_if_manual = @import("dxgi_interfaces_manual.zig");
const win = @import("win_types.zig");

pub const D3D_DRIVER_TYPE = c_int;
pub const D3D_DRIVER_TYPE_HARDWARE: D3D_DRIVER_TYPE = 1;
pub const D3D_DRIVER_TYPE_WARP: D3D_DRIVER_TYPE = 5;

pub const D3D_FEATURE_LEVEL = u32;

pub const D3D11_CREATE_DEVICE_BGRA_SUPPORT: win.UINT = 0x20;
pub const D3D11_SDK_VERSION: win.UINT = 7;

extern "d3d11" fn D3D11CreateDeviceAndSwapChain(
    adapter: ?*anyopaque,
    driver_type: D3D_DRIVER_TYPE,
    software: ?*anyopaque,
    flags: win.UINT,
    feature_levels: ?[*]const D3D_FEATURE_LEVEL,
    feature_levels_count: win.UINT,
    sdk_version: win.UINT,
    swap_chain_desc: *const dxgi_manual.DXGI_SWAP_CHAIN_DESC,
    swap_chain: *?*dxgi_if_manual.IDXGISwapChain,
    device: *?*d3d11_if.ID3D11Device,
    feature_level: *D3D_FEATURE_LEVEL,
    immediate_context: *?*d3d11_if.ID3D11DeviceContext,
) callconv(.winapi) win.HRESULT;

pub fn createDeviceAndSwapChain(
    driver_type: D3D_DRIVER_TYPE,
    swap_chain_desc: *const dxgi_manual.DXGI_SWAP_CHAIN_DESC,
    swap_chain: *?*dxgi_if_manual.IDXGISwapChain,
    device: *?*d3d11_if.ID3D11Device,
    feature_level: *D3D_FEATURE_LEVEL,
    immediate_context: *?*d3d11_if.ID3D11DeviceContext,
) win.HRESULT {
    return D3D11CreateDeviceAndSwapChain(
        null,
        driver_type,
        null,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT,
        null,
        0,
        D3D11_SDK_VERSION,
        swap_chain_desc,
        swap_chain,
        device,
        feature_level,
        immediate_context,
    );
}
