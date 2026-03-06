const builtin = @import("builtin");
const std = @import("std");

const d3d11_manual = @import("../platform/win32/d3d11_manual.zig");
const d3d11_if = @import("../platform/win32/d3d11_interfaces_manual.zig");
const dxgi_manual = @import("../platform/win32/dxgi_manual.zig");
const win = @import("../platform/win32/win_types.zig");

fn expectAbi(comptime got: usize, comptime expected: usize, comptime what: []const u8) void {
    if (got != expected) {
        @compileError(std.fmt.comptimePrint("ABI mismatch for {s}: got {d}, expected {d}", .{ what, got, expected }));
    }
}

test "win32 manual ABI guards" {
    if (builtin.os.tag != .windows or builtin.cpu.arch != .x86_64) return;

    // DXGI descriptor layout guards.
    expectAbi(@sizeOf(dxgi_manual.DXGI_RATIONAL), 8, "DXGI_RATIONAL.size");
    expectAbi(@alignOf(dxgi_manual.DXGI_RATIONAL), 4, "DXGI_RATIONAL.align");
    expectAbi(@offsetOf(dxgi_manual.DXGI_RATIONAL, "Denominator"), 4, "DXGI_RATIONAL.Denominator");

    expectAbi(@sizeOf(dxgi_manual.DXGI_MODE_DESC), 28, "DXGI_MODE_DESC.size");
    expectAbi(@alignOf(dxgi_manual.DXGI_MODE_DESC), 4, "DXGI_MODE_DESC.align");
    expectAbi(@offsetOf(dxgi_manual.DXGI_MODE_DESC, "Format"), 16, "DXGI_MODE_DESC.Format");
    expectAbi(@offsetOf(dxgi_manual.DXGI_MODE_DESC, "Scaling"), 24, "DXGI_MODE_DESC.Scaling");

    expectAbi(@sizeOf(dxgi_manual.DXGI_SAMPLE_DESC), 8, "DXGI_SAMPLE_DESC.size");
    expectAbi(@alignOf(dxgi_manual.DXGI_SAMPLE_DESC), 4, "DXGI_SAMPLE_DESC.align");

    expectAbi(@sizeOf(dxgi_manual.DXGI_SWAP_CHAIN_DESC), 72, "DXGI_SWAP_CHAIN_DESC.size");
    expectAbi(@alignOf(dxgi_manual.DXGI_SWAP_CHAIN_DESC), 8, "DXGI_SWAP_CHAIN_DESC.align");
    expectAbi(@offsetOf(dxgi_manual.DXGI_SWAP_CHAIN_DESC, "OutputWindow"), 48, "DXGI_SWAP_CHAIN_DESC.OutputWindow");
    expectAbi(@offsetOf(dxgi_manual.DXGI_SWAP_CHAIN_DESC, "Flags"), 64, "DXGI_SWAP_CHAIN_DESC.Flags");

    // D3D11 descriptor layout guards.
    expectAbi(@sizeOf(d3d11_manual.D3D11_TEXTURE2D_DESC), 44, "D3D11_TEXTURE2D_DESC.size");
    expectAbi(@alignOf(d3d11_manual.D3D11_TEXTURE2D_DESC), 4, "D3D11_TEXTURE2D_DESC.align");
    expectAbi(@offsetOf(d3d11_manual.D3D11_TEXTURE2D_DESC, "SampleDesc"), 20, "D3D11_TEXTURE2D_DESC.SampleDesc");
    expectAbi(@offsetOf(d3d11_manual.D3D11_TEXTURE2D_DESC, "BindFlags"), 32, "D3D11_TEXTURE2D_DESC.BindFlags");

    expectAbi(@sizeOf(d3d11_manual.D3D11_SUBRESOURCE_DATA), 16, "D3D11_SUBRESOURCE_DATA.size");
    expectAbi(@alignOf(d3d11_manual.D3D11_SUBRESOURCE_DATA), @alignOf(*const anyopaque), "D3D11_SUBRESOURCE_DATA.align");
    expectAbi(@offsetOf(d3d11_manual.D3D11_SUBRESOURCE_DATA, "SysMemPitch"), 8, "D3D11_SUBRESOURCE_DATA.SysMemPitch");

    expectAbi(@sizeOf(d3d11_manual.D3D11_BUFFER_DESC), 24, "D3D11_BUFFER_DESC.size");
    expectAbi(@alignOf(d3d11_manual.D3D11_BUFFER_DESC), 4, "D3D11_BUFFER_DESC.align");
    expectAbi(@offsetOf(d3d11_manual.D3D11_BUFFER_DESC, "StructureByteStride"), 20, "D3D11_BUFFER_DESC.StructureByteStride");

    expectAbi(@sizeOf(d3d11_manual.D3D11_MAPPED_SUBRESOURCE), 16, "D3D11_MAPPED_SUBRESOURCE.size");
    expectAbi(@alignOf(d3d11_manual.D3D11_MAPPED_SUBRESOURCE), @alignOf(?*anyopaque), "D3D11_MAPPED_SUBRESOURCE.align");
    expectAbi(@offsetOf(d3d11_manual.D3D11_MAPPED_SUBRESOURCE, "RowPitch"), 8, "D3D11_MAPPED_SUBRESOURCE.RowPitch");

    expectAbi(@sizeOf(d3d11_manual.D3D11_INPUT_ELEMENT_DESC), 32, "D3D11_INPUT_ELEMENT_DESC.size");
    expectAbi(@alignOf(d3d11_manual.D3D11_INPUT_ELEMENT_DESC), @alignOf([*c]const u8), "D3D11_INPUT_ELEMENT_DESC.align");
    expectAbi(@offsetOf(d3d11_manual.D3D11_INPUT_ELEMENT_DESC, "Format"), 12, "D3D11_INPUT_ELEMENT_DESC.Format");
    expectAbi(@offsetOf(d3d11_manual.D3D11_INPUT_ELEMENT_DESC, "InstanceDataStepRate"), 28, "D3D11_INPUT_ELEMENT_DESC.InstanceDataStepRate");

    expectAbi(@sizeOf(d3d11_manual.D3D11_VIEWPORT), 24, "D3D11_VIEWPORT.size");
    expectAbi(@alignOf(d3d11_manual.D3D11_VIEWPORT), 4, "D3D11_VIEWPORT.align");

    // Manual COM interface layout guards.
    expectAbi(@sizeOf(d3d11_if.ID3D11Device), 8, "ID3D11Device.size");
    expectAbi(@alignOf(d3d11_if.ID3D11Device), 8, "ID3D11Device.align");
    expectAbi(@offsetOf(d3d11_if.ID3D11Device, "lpVtbl"), 0, "ID3D11Device.lpVtbl");
    expectAbi(@offsetOf(d3d11_if.ID3D11Device.VTable, "CreateBuffer"), 3 * @sizeOf(?*const anyopaque), "ID3D11Device.VTable.CreateBuffer");
    expectAbi(@offsetOf(d3d11_if.ID3D11Device.VTable, "CreateTexture2D"), 5 * @sizeOf(?*const anyopaque), "ID3D11Device.VTable.CreateTexture2D");
    expectAbi(@offsetOf(d3d11_if.ID3D11Device.VTable, "CreateShaderResourceView"), 7 * @sizeOf(?*const anyopaque), "ID3D11Device.VTable.CreateShaderResourceView");
    expectAbi(@offsetOf(d3d11_if.ID3D11Device.VTable, "CreateRenderTargetView"), 9 * @sizeOf(?*const anyopaque), "ID3D11Device.VTable.CreateRenderTargetView");
    expectAbi(@offsetOf(d3d11_if.ID3D11Device.VTable, "CreateInputLayout"), 11 * @sizeOf(?*const anyopaque), "ID3D11Device.VTable.CreateInputLayout");
    expectAbi(@offsetOf(d3d11_if.ID3D11Device.VTable, "CreateVertexShader"), 12 * @sizeOf(?*const anyopaque), "ID3D11Device.VTable.CreateVertexShader");
    expectAbi(@offsetOf(d3d11_if.ID3D11Device.VTable, "CreatePixelShader"), 15 * @sizeOf(?*const anyopaque), "ID3D11Device.VTable.CreatePixelShader");

    expectAbi(@sizeOf(d3d11_if.ID3D11DeviceContext), 8, "ID3D11DeviceContext.size");
    expectAbi(@alignOf(d3d11_if.ID3D11DeviceContext), 8, "ID3D11DeviceContext.align");
    expectAbi(@offsetOf(d3d11_if.ID3D11DeviceContext, "lpVtbl"), 0, "ID3D11DeviceContext.lpVtbl");
    expectAbi(@offsetOf(d3d11_if.ID3D11DeviceContext.VTable, "Draw"), 13 * @sizeOf(?*const anyopaque), "ID3D11DeviceContext.VTable.Draw");
    expectAbi(@offsetOf(d3d11_if.ID3D11DeviceContext.VTable, "Map"), 14 * @sizeOf(?*const anyopaque), "ID3D11DeviceContext.VTable.Map");
    expectAbi(@offsetOf(d3d11_if.ID3D11DeviceContext.VTable, "Unmap"), 15 * @sizeOf(?*const anyopaque), "ID3D11DeviceContext.VTable.Unmap");
    expectAbi(@offsetOf(d3d11_if.ID3D11DeviceContext.VTable, "IASetInputLayout"), 17 * @sizeOf(?*const anyopaque), "ID3D11DeviceContext.VTable.IASetInputLayout");
    expectAbi(@offsetOf(d3d11_if.ID3D11DeviceContext.VTable, "IASetVertexBuffers"), 18 * @sizeOf(?*const anyopaque), "ID3D11DeviceContext.VTable.IASetVertexBuffers");
    expectAbi(@offsetOf(d3d11_if.ID3D11DeviceContext.VTable, "IASetPrimitiveTopology"), 24 * @sizeOf(?*const anyopaque), "ID3D11DeviceContext.VTable.IASetPrimitiveTopology");
    expectAbi(@offsetOf(d3d11_if.ID3D11DeviceContext.VTable, "OMSetRenderTargets"), 33 * @sizeOf(?*const anyopaque), "ID3D11DeviceContext.VTable.OMSetRenderTargets");
    expectAbi(@offsetOf(d3d11_if.ID3D11DeviceContext.VTable, "RSSetViewports"), 44 * @sizeOf(?*const anyopaque), "ID3D11DeviceContext.VTable.RSSetViewports");
    expectAbi(@offsetOf(d3d11_if.ID3D11DeviceContext.VTable, "CopyResource"), 47 * @sizeOf(?*const anyopaque), "ID3D11DeviceContext.VTable.CopyResource");

    // Sanity that base scalar aliases stay consistent.
    expectAbi(@sizeOf(win.HRESULT), 4, "HRESULT.size");
    expectAbi(@sizeOf(win.BOOL), 4, "BOOL.size");
    expectAbi(@sizeOf(win.UINT), 4, "UINT.size");
}
