const builtin = @import("builtin");
const d3d11_manual = @import("d3d11_manual.zig");
const win = @import("win_types.zig");

pub const IUnknownVTable = extern struct {
    QueryInterface: ?*const fn (self: *anyopaque, riid: *const win.GUID, out: *?*anyopaque) callconv(.winapi) win.HRESULT,
    AddRef: ?*const fn (self: *anyopaque) callconv(.winapi) win.UINT,
    Release: ?*const fn (self: *anyopaque) callconv(.winapi) win.UINT,
};

fn SimpleInterface(comptime name: []const u8) type {
    _ = name;
    return if (builtin.os.tag == .windows) extern struct {
        lpVtbl: *const IUnknownVTable,
    } else struct {};
}

pub const ID3D11Resource = SimpleInterface("ID3D11Resource");
pub const ID3D11Texture2D = SimpleInterface("ID3D11Texture2D");
pub const ID3D11RenderTargetView = SimpleInterface("ID3D11RenderTargetView");
pub const ID3D11ShaderResourceView = SimpleInterface("ID3D11ShaderResourceView");
pub const ID3D11VertexShader = SimpleInterface("ID3D11VertexShader");
pub const ID3D11PixelShader = SimpleInterface("ID3D11PixelShader");
pub const ID3D11InputLayout = SimpleInterface("ID3D11InputLayout");
pub const ID3D11Buffer = SimpleInterface("ID3D11Buffer");

pub const ID3D11Device = if (builtin.os.tag == .windows) extern struct {
    lpVtbl: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: ?*const fn (self: *ID3D11Device, riid: *const win.GUID, out: *?*anyopaque) callconv(.winapi) win.HRESULT,
        AddRef: ?*const fn (self: *ID3D11Device) callconv(.winapi) win.UINT,
        Release: ?*const fn (self: *ID3D11Device) callconv(.winapi) win.UINT,

        CreateBuffer: ?*const fn (
            self: *ID3D11Device,
            desc: *const d3d11_manual.D3D11_BUFFER_DESC,
            initial_data: ?*const d3d11_manual.D3D11_SUBRESOURCE_DATA,
            buffer: *?*ID3D11Buffer,
        ) callconv(.winapi) win.HRESULT,
        CreateTexture1D: *const anyopaque,
        CreateTexture2D: ?*const fn (
            self: *ID3D11Device,
            desc: *const d3d11_manual.D3D11_TEXTURE2D_DESC,
            initial_data: ?*const d3d11_manual.D3D11_SUBRESOURCE_DATA,
            texture: *?*ID3D11Texture2D,
        ) callconv(.winapi) win.HRESULT,
        CreateTexture3D: *const anyopaque,
        CreateShaderResourceView: ?*const fn (
            self: *ID3D11Device,
            resource: *ID3D11Resource,
            desc: ?*const anyopaque,
            view: *?*ID3D11ShaderResourceView,
        ) callconv(.winapi) win.HRESULT,
        CreateUnorderedAccessView: *const anyopaque,
        CreateRenderTargetView: ?*const fn (
            self: *ID3D11Device,
            resource: *ID3D11Resource,
            desc: ?*const anyopaque,
            view: *?*ID3D11RenderTargetView,
        ) callconv(.winapi) win.HRESULT,
        CreateDepthStencilView: *const anyopaque,
        CreateInputLayout: ?*const fn (
            self: *ID3D11Device,
            input_element_descs: [*]const d3d11_manual.D3D11_INPUT_ELEMENT_DESC,
            num_elements: win.UINT,
            shader_bytecode_with_input_signature: *const anyopaque,
            bytecode_length: usize,
            input_layout: *?*ID3D11InputLayout,
        ) callconv(.winapi) win.HRESULT,
        CreateVertexShader: ?*const fn (
            self: *ID3D11Device,
            shader_bytecode: *const anyopaque,
            bytecode_length: usize,
            class_linkage: ?*anyopaque,
            vertex_shader: *?*ID3D11VertexShader,
        ) callconv(.winapi) win.HRESULT,
        CreateGeometryShader: *const anyopaque,
        CreateGeometryShaderWithStreamOutput: *const anyopaque,
        CreatePixelShader: ?*const fn (
            self: *ID3D11Device,
            shader_bytecode: *const anyopaque,
            bytecode_length: usize,
            class_linkage: ?*anyopaque,
            pixel_shader: *?*ID3D11PixelShader,
        ) callconv(.winapi) win.HRESULT,
        CreateHullShader: *const anyopaque,
        CreateDomainShader: *const anyopaque,
        CreateComputeShader: *const anyopaque,
        CreateClassLinkage: *const anyopaque,
        CreateBlendState: *const anyopaque,
        CreateDepthStencilState: *const anyopaque,
        CreateRasterizerState: *const anyopaque,
        CreateSamplerState: *const anyopaque,
        CreateQuery: *const anyopaque,
        CreatePredicate: *const anyopaque,
        CreateCounter: *const anyopaque,
        CreateDeferredContext: *const anyopaque,
        OpenSharedResource: *const anyopaque,
        CheckFormatSupport: *const anyopaque,
        CheckMultisampleQualityLevels: *const anyopaque,
        CheckCounterInfo: *const anyopaque,
        CheckCounter: *const anyopaque,
        CheckFeatureSupport: *const anyopaque,
        GetPrivateData: *const anyopaque,
        SetPrivateData: *const anyopaque,
        SetPrivateDataInterface: *const anyopaque,
        GetFeatureLevel: *const anyopaque,
        GetCreationFlags: *const anyopaque,
        GetDeviceRemovedReason: *const anyopaque,
        GetImmediateContext: *const anyopaque,
        SetExceptionMode: *const anyopaque,
        GetExceptionMode: *const anyopaque,
    };
} else struct {};

pub const ID3D11DeviceContext = if (builtin.os.tag == .windows) extern struct {
    lpVtbl: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: ?*const fn (self: *ID3D11DeviceContext, riid: *const win.GUID, out: *?*anyopaque) callconv(.winapi) win.HRESULT,
        AddRef: ?*const fn (self: *ID3D11DeviceContext) callconv(.winapi) win.UINT,
        Release: ?*const fn (self: *ID3D11DeviceContext) callconv(.winapi) win.UINT,

        GetDevice: *const anyopaque,
        GetPrivateData: *const anyopaque,
        SetPrivateData: *const anyopaque,
        SetPrivateDataInterface: *const anyopaque,

        VSSetConstantBuffers: *const anyopaque,
        PSSetShaderResources: *const anyopaque,
        PSSetShader: ?*const fn (
            self: *ID3D11DeviceContext,
            pixel_shader: *ID3D11PixelShader,
            class_instances: ?[*]?*anyopaque,
            num_class_instances: win.UINT,
        ) callconv(.winapi) void,
        PSSetSamplers: *const anyopaque,
        VSSetShader: ?*const fn (
            self: *ID3D11DeviceContext,
            vertex_shader: *ID3D11VertexShader,
            class_instances: ?[*]?*anyopaque,
            num_class_instances: win.UINT,
        ) callconv(.winapi) void,
        DrawIndexed: *const anyopaque,
        Draw: ?*const fn (self: *ID3D11DeviceContext, vertex_count: win.UINT, start_vertex_location: win.UINT) callconv(.winapi) void,
        Map: ?*const fn (
            self: *ID3D11DeviceContext,
            resource: *ID3D11Resource,
            subresource: win.UINT,
            map_type: win.UINT,
            map_flags: win.UINT,
            mapped_resource: *d3d11_manual.D3D11_MAPPED_SUBRESOURCE,
        ) callconv(.winapi) win.HRESULT,
        Unmap: ?*const fn (self: *ID3D11DeviceContext, resource: *ID3D11Resource, subresource: win.UINT) callconv(.winapi) void,
        PSSetConstantBuffers: ?*const fn (
            self: *ID3D11DeviceContext,
            start_slot: win.UINT,
            num_buffers: win.UINT,
            constant_buffers: [*]const ?*ID3D11Buffer,
        ) callconv(.winapi) void,
        IASetInputLayout: ?*const fn (self: *ID3D11DeviceContext, input_layout: *ID3D11InputLayout) callconv(.winapi) void,
        IASetVertexBuffers: ?*const fn (
            self: *ID3D11DeviceContext,
            start_slot: win.UINT,
            num_buffers: win.UINT,
            vertex_buffers: [*]const ?*ID3D11Buffer,
            strides: [*]const win.UINT,
            offsets: [*]const win.UINT,
        ) callconv(.winapi) void,
        IASetIndexBuffer: *const anyopaque,
        DrawIndexedInstanced: *const anyopaque,
        DrawInstanced: *const anyopaque,
        GSSetConstantBuffers: *const anyopaque,
        GSSetShader: *const anyopaque,
        IASetPrimitiveTopology: ?*const fn (self: *ID3D11DeviceContext, topology: win.UINT) callconv(.winapi) void,
        VSSetShaderResources: *const anyopaque,
        VSSetSamplers: *const anyopaque,
        Begin: *const anyopaque,
        End: *const anyopaque,
        GetData: *const anyopaque,
        SetPredication: *const anyopaque,
        GSSetShaderResources: *const anyopaque,
        GSSetSamplers: *const anyopaque,
        OMSetRenderTargets: ?*const fn (
            self: *ID3D11DeviceContext,
            num_views: win.UINT,
            render_target_views: [*]const ?*ID3D11RenderTargetView,
            depth_stencil_view: ?*anyopaque,
        ) callconv(.winapi) void,
        OMSetRenderTargetsAndUnorderedAccessViews: *const anyopaque,
        OMSetBlendState: *const anyopaque,
        OMSetDepthStencilState: *const anyopaque,
        SOSetTargets: *const anyopaque,
        DrawAuto: *const anyopaque,
        DrawIndexedInstancedIndirect: *const anyopaque,
        DrawInstancedIndirect: *const anyopaque,
        Dispatch: *const anyopaque,
        DispatchIndirect: *const anyopaque,
        RSSetState: *const anyopaque,
        RSSetViewports: ?*const fn (
            self: *ID3D11DeviceContext,
            num_viewports: win.UINT,
            viewports: [*]const d3d11_manual.D3D11_VIEWPORT,
        ) callconv(.winapi) void,
        RSSetScissorRects: *const anyopaque,
        CopySubresourceRegion: *const anyopaque,
        CopyResource: ?*const fn (
            self: *ID3D11DeviceContext,
            dst_resource: *ID3D11Resource,
            src_resource: *ID3D11Resource,
        ) callconv(.winapi) void,
    };
} else struct {};
