const builtin = @import("builtin");

// Phase 1 migration boundary:
// Keep all D3D/Win32 C header imports behind one module so renderer code can
// transition to pure Zig bindings incrementally.
pub const c = if (builtin.os.tag == .windows) @cImport({
    @cInclude("windows.h");
    @cInclude("d3d11.h");
    @cInclude("dxgi.h");
    @cInclude("dxgi1_2.h");
    @cInclude("d3dcompiler.h");
}) else struct {};

