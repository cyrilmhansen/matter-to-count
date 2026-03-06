const d3d_c = @import("d3d_c.zig");
const c = d3d_c.c;

// Transitional interface boundary for D3D11 COM types.
// This keeps renderer code decoupled from direct cimport symbol names and
// allows staged replacement with fully manual vtable declarations.
pub const ID3D11Device = c.ID3D11Device;
pub const ID3D11DeviceContext = c.ID3D11DeviceContext;
pub const ID3D11Texture2D = c.ID3D11Texture2D;
pub const ID3D11RenderTargetView = c.ID3D11RenderTargetView;
pub const ID3D11ShaderResourceView = c.ID3D11ShaderResourceView;
pub const ID3D11VertexShader = c.ID3D11VertexShader;
pub const ID3D11PixelShader = c.ID3D11PixelShader;
pub const ID3D11InputLayout = c.ID3D11InputLayout;
pub const ID3D11Buffer = c.ID3D11Buffer;
pub const ID3D11Resource = c.ID3D11Resource;

