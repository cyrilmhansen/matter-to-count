const std = @import("std");
const com = @import("../../platform/win32/com_helpers.zig");
const win = @import("../../platform/win32/win_types.zig");
const d3d11_if = @import("../../platform/win32/d3d11_interfaces_manual.zig");
const d3d11_manual = @import("../../platform/win32/d3d11_manual.zig");
const dxgi_manual = @import("../../platform/win32/dxgi_manual.zig");

pub fn captureScreenshot(
    device: *d3d11_if.ID3D11Device,
    context: *d3d11_if.ID3D11DeviceContext,
    capture_texture: *d3d11_if.ID3D11Texture2D,
    path: []const u8,
    width: u32,
    height: u32,
) !void {
    @setRuntimeSafety(false);
    var desc: d3d11_manual.D3D11_TEXTURE2D_DESC = std.mem.zeroes(d3d11_manual.D3D11_TEXTURE2D_DESC);
    desc.Width = width;
    desc.Height = height;
    desc.MipLevels = 1;
    desc.ArraySize = 1;
    desc.Format = dxgi_manual.DXGI_FORMAT_R8G8B8A8_UNORM;
    desc.SampleDesc.Count = 1;
    desc.Usage = d3d11_manual.D3D11_USAGE_STAGING;
    desc.CPUAccessFlags = d3d11_manual.D3D11_CPU_ACCESS_READ;

    var staging: ?*d3d11_if.ID3D11Texture2D = null;
    const hr_tex = device.lpVtbl.*.CreateTexture2D.?(
        device,
        @as(*const d3d11_manual.D3D11_TEXTURE2D_DESC, @ptrCast(&desc)),
        null,
        &staging,
    );
    if (hr_tex != win.S_OK or staging == null) return error.D3D11CreateStagingTextureFailed;
    defer com.release(staging.?);

    context.lpVtbl.*.CopyResource.?(
        context,
        com.cast(*d3d11_if.ID3D11Resource, staging.?),
        com.cast(*d3d11_if.ID3D11Resource, capture_texture),
    );

    var mapped: d3d11_manual.D3D11_MAPPED_SUBRESOURCE = std.mem.zeroes(d3d11_manual.D3D11_MAPPED_SUBRESOURCE);
    const hr_map = context.lpVtbl.*.Map.?(
        context,
        com.cast(*d3d11_if.ID3D11Resource, staging.?),
        0,
        d3d11_manual.D3D11_MAP_READ,
        0,
        @as(*d3d11_manual.D3D11_MAPPED_SUBRESOURCE, @ptrCast(&mapped)),
    );
    if (hr_map != win.S_OK) return error.D3D11MapStagingFailed;
    defer context.lpVtbl.*.Unmap.?(context, com.cast(*d3d11_if.ID3D11Resource, staging.?), 0);

    var file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();
    var header_buf: [64]u8 = undefined;
    const header = try std.fmt.bufPrint(&header_buf, "P3\n{d} {d}\n255\n", .{ width, height });
    try file.writeAll(header);

    const row_pitch: usize = @intCast(mapped.RowPitch);
    const bytes: [*]const u8 = com.cast([*]const u8, mapped.pData.?);
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
