const std = @import("std");
const render_plan = @import("../render_plan.zig");

pub const Vertex = extern struct { x: f32, y: f32, z: f32, r: f32, g: f32, b: f32, a: f32 };

pub const MaxDynamicVertices: u32 = 8192;
const LegendZ: f32 = 0.95;
const LegendCellW: f32 = 0.010;
const LegendCellH: f32 = 0.018;
const LegendGap: f32 = 0.003;
const LegendCharSpacing: f32 = 0.010;

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
        .operand_primary_digit, .operand_secondary_digit, .result_digit => 0.070,
        .carry_packet, .borrow_packet, .shift_packet => 0.090,
        .partial_row_marker, .base_bundle_token => 0.060,
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

pub fn buildPlanVertices(
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    plan: render_plan.RenderPlan,
    legend_text: []const u8,
) ![]Vertex {
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
