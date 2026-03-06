const std = @import("std");
const win = @import("win_types.zig");

pub const HWND = win.HWND;
pub const HINSTANCE = win.HINSTANCE;
pub const HICON = win.HICON;
pub const HCURSOR = win.HCURSOR;
pub const HBRUSH = win.HBRUSH;
pub const HMENU = win.HMENU;
pub const HMODULE = win.HMODULE;
pub const HDC = win.HDC;
pub const LPCWSTR = win.LPCWSTR;
pub const LPVOID = win.LPVOID;
pub const WPARAM = win.WPARAM;
pub const LPARAM = win.LPARAM;
pub const LRESULT = win.LRESULT;
pub const UINT = win.UINT;
pub const DWORD = win.DWORD;
pub const ATOM = win.ATOM;
pub const BOOL = win.BOOL;
pub const HRESULT = win.HRESULT;

pub const S_OK: HRESULT = 0;

pub const CS_HREDRAW: UINT = 0x0002;
pub const CS_VREDRAW: UINT = 0x0001;

pub const WS_OVERLAPPEDWINDOW: DWORD = 0x00CF0000;
pub const WS_POPUP: DWORD = 0x80000000;
pub const WS_VISIBLE: DWORD = 0x10000000;

pub const CW_USEDEFAULT: i32 = -2147483648;

pub const SW_SHOW: i32 = 5;

pub const WM_DESTROY: UINT = 0x0002;
pub const WM_SIZE: UINT = 0x0005;
pub const WM_KEYDOWN: UINT = 0x0100;
pub const WM_QUIT: UINT = 0x0012;
pub const VK_ESCAPE: WPARAM = 0x1B;

pub const PM_REMOVE: UINT = 0x0001;

pub const RECT = extern struct {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
};

pub const MSG = extern struct {
    hwnd: HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: extern struct {
        x: i32,
        y: i32,
    },
    lPrivate: DWORD,
};

pub const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT;

pub const WNDCLASSEXW = extern struct {
    cbSize: UINT,
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: HINSTANCE,
    hIcon: HICON,
    hCursor: HCURSOR,
    hbrBackground: HBRUSH,
    lpszMenuName: ?LPCWSTR,
    lpszClassName: LPCWSTR,
    hIconSm: HICON,
};

extern "kernel32" fn GetModuleHandleW(lpModuleName: ?LPCWSTR) callconv(.winapi) HMODULE;
extern "user32" fn RegisterClassExW(lpWndClass: *const WNDCLASSEXW) callconv(.winapi) ATOM;
extern "user32" fn CreateWindowExW(
    dwExStyle: DWORD,
    lpClassName: LPCWSTR,
    lpWindowName: LPCWSTR,
    dwStyle: DWORD,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: HWND,
    hMenu: HMENU,
    hInstance: HINSTANCE,
    lpParam: LPVOID,
) callconv(.winapi) HWND;
extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: i32) callconv(.winapi) BOOL;
extern "user32" fn UpdateWindow(hWnd: HWND) callconv(.winapi) BOOL;
extern "user32" fn DefWindowProcW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(.winapi) void;
extern "user32" fn PeekMessageW(lpMsg: *MSG, hWnd: HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(.winapi) BOOL;
extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) BOOL;
extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.winapi) LRESULT;
extern "user32" fn AdjustWindowRect(lpRect: *RECT, dwStyle: DWORD, bMenu: BOOL) callconv(.winapi) BOOL;
extern "user32" fn DestroyWindow(hWnd: HWND) callconv(.winapi) BOOL;
extern "user32" fn GetDC(hWnd: HWND) callconv(.winapi) HDC;
extern "user32" fn ReleaseDC(hWnd: HWND, hDC: HDC) callconv(.winapi) i32;
extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) BOOL;
extern "user32" fn FillRect(hDC: HDC, lprc: *const RECT, hbr: HBRUSH) callconv(.winapi) i32;
extern "user32" fn LoadCursorW(hInstance: HINSTANCE, lpCursorName: ?*const anyopaque) callconv(.winapi) HCURSOR;
extern "user32" fn DrawIconEx(hdc: HDC, xLeft: i32, yTop: i32, hIcon: HCURSOR, cxWidth: i32, cyWidth: i32, istepIfAniCur: UINT, hbrFlickerFreeDraw: HBRUSH, diFlags: UINT) callconv(.winapi) BOOL;
extern "user32" fn SetCursor(hCursor: HCURSOR) callconv(.winapi) HCURSOR;
extern "user32" fn SetWindowTextW(hWnd: HWND, lpString: LPCWSTR) callconv(.winapi) BOOL;
extern "user32" fn GetSystemMetrics(nIndex: i32) callconv(.winapi) i32;
extern "gdi32" fn CreateSolidBrush(color: DWORD) callconv(.winapi) HBRUSH;
extern "gdi32" fn DeleteObject(ho: ?*anyopaque) callconv(.winapi) BOOL;
extern "gdi32" fn SetBkMode(hdc: HDC, mode: i32) callconv(.winapi) i32;
extern "gdi32" fn GdiFlush() callconv(.winapi) BOOL;

const SM_CXSCREEN: i32 = 0;
const SM_CYSCREEN: i32 = 1;

const IDC_CROSS_INT: usize = 32515;
const DI_NORMAL: UINT = 0x0003;
const TRANSPARENT: i32 = 1;

pub const Window = struct {
    hwnd: HWND,
    width: u32,
    height: u32,
};

pub const ResizeEvent = struct {
    width: u32,
    height: u32,
};

var g_pending_resize: ?ResizeEvent = null;

fn toWideZ(allocator: std.mem.Allocator, s: []const u8) ![:0]u16 {
    return std.unicode.utf8ToUtf16LeAllocZ(allocator, s);
}

fn wndProc(hwnd: HWND, msg: UINT, wparam: WPARAM, lparam: LPARAM) callconv(.winapi) LRESULT {
    switch (msg) {
        WM_DESTROY => {
            PostQuitMessage(0);
            return 0;
        },
        WM_SIZE => {
            const v: usize = @as(usize, @bitCast(lparam));
            const w: u32 = @as(u32, @truncate(v & 0xFFFF));
            const h: u32 = @as(u32, @truncate((v >> 16) & 0xFFFF));
            g_pending_resize = .{ .width = w, .height = h };
            return 0;
        },
        WM_KEYDOWN => {
            if (wparam == VK_ESCAPE) {
                PostQuitMessage(0);
                return 0;
            }
            return DefWindowProcW(hwnd, msg, wparam, lparam);
        },
        else => return DefWindowProcW(hwnd, msg, wparam, lparam),
    }
}

pub fn create(allocator: std.mem.Allocator, title: []const u8, width: u32, height: u32, fullscreen: bool) !Window {
    const class_name = try toWideZ(allocator, "MatterToCountWindowClass");
    defer allocator.free(class_name);

    const window_title = try toWideZ(allocator, title);
    defer allocator.free(window_title);

    const instance = GetModuleHandleW(null);
    if (instance == null) return error.Win32ModuleHandleFailed;

    var wc = WNDCLASSEXW{
        .cbSize = @sizeOf(WNDCLASSEXW),
        .style = CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = wndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = instance,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = class_name.ptr,
        .hIconSm = null,
    };

    if (RegisterClassExW(&wc) == 0) return error.Win32RegisterClassFailed;

    var style: DWORD = WS_OVERLAPPEDWINDOW | WS_VISIBLE;
    var win_x: i32 = CW_USEDEFAULT;
    var win_y: i32 = CW_USEDEFAULT;
    var win_w: i32 = @as(i32, @intCast(width));
    var win_h: i32 = @as(i32, @intCast(height));

    if (fullscreen) {
        style = WS_POPUP | WS_VISIBLE;
        win_x = 0;
        win_y = 0;
        win_w = GetSystemMetrics(SM_CXSCREEN);
        win_h = GetSystemMetrics(SM_CYSCREEN);
        if (win_w <= 0 or win_h <= 0) return error.Win32CreateWindowFailed;
    } else {
        var rect = RECT{ .left = 0, .top = 0, .right = win_w, .bottom = win_h };
        if (AdjustWindowRect(&rect, WS_OVERLAPPEDWINDOW, 0) == 0) return error.Win32AdjustRectFailed;
        win_w = rect.right - rect.left;
        win_h = rect.bottom - rect.top;
    }

    const hwnd = CreateWindowExW(
        0,
        class_name.ptr,
        window_title.ptr,
        style,
        win_x,
        win_y,
        win_w,
        win_h,
        null,
        null,
        instance,
        null,
    );
    if (hwnd == null) return error.Win32CreateWindowFailed;

    _ = ShowWindow(hwnd, SW_SHOW);
    _ = UpdateWindow(hwnd);
    drawLoadingScreen(allocator, .{
        .hwnd = hwnd,
        .width = @as(u32, @intCast(win_w)),
        .height = @as(u32, @intCast(win_h)),
    }, "LOADING RENDERER...") catch {};

    return .{ .hwnd = hwnd, .width = @as(u32, @intCast(win_w)), .height = @as(u32, @intCast(win_h)) };
}

pub fn destroy(window: Window) void {
    _ = DestroyWindow(window.hwnd);
}

pub fn pumpMessages() bool {
    var msg: MSG = std.mem.zeroes(MSG);
    while (PeekMessageW(&msg, null, 0, 0, PM_REMOVE) != 0) {
        if (msg.message == WM_QUIT) return false;
        _ = TranslateMessage(&msg);
        _ = DispatchMessageW(&msg);
    }
    return true;
}

pub fn takePendingResize() ?ResizeEvent {
    const ev = g_pending_resize;
    g_pending_resize = null;
    return ev;
}

pub fn drawStandardCrossCursor(window: Window, x: i32, y: i32, size: i32) !void {
    const dc = GetDC(window.hwnd);
    if (dc == null) return error.Win32GetDCFailed;
    defer _ = ReleaseDC(window.hwnd, dc);

    const cursor_name: ?*const anyopaque = @ptrFromInt(IDC_CROSS_INT);
    const cursor = LoadCursorW(null, cursor_name);
    if (cursor == null) return error.Win32LoadCursorFailed;

    if (DrawIconEx(dc, x, y, cursor, size, size, 0, null, DI_NORMAL) == 0) {
        return error.Win32DrawIconFailed;
    }
}

pub fn setStandardCrossCursor() !void {
    const cursor_name: ?*const anyopaque = @ptrFromInt(IDC_CROSS_INT);
    const cursor = LoadCursorW(null, cursor_name);
    if (cursor == null) return error.Win32LoadCursorFailed;
    _ = SetCursor(cursor);
}

pub fn setWindowTitle(allocator: std.mem.Allocator, window: Window, title: []const u8) !void {
    const title_w = try toWideZ(allocator, title);
    defer allocator.free(title_w);
    if (SetWindowTextW(window.hwnd, title_w.ptr) == 0) return error.Win32SetWindowTextFailed;
}

fn glyph5x7(ch: u8) [7]u8 {
    const c = if (ch >= 'a' and ch <= 'z') ch - 32 else ch;
    return switch (c) {
        'A' => .{ 0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11 },
        'D' => .{ 0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E },
        'E' => .{ 0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F },
        'G' => .{ 0x0E, 0x11, 0x10, 0x13, 0x11, 0x11, 0x0E },
        'I' => .{ 0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x1F },
        'L' => .{ 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F },
        'N' => .{ 0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x11 },
        'O' => .{ 0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E },
        'R' => .{ 0x1E, 0x11, 0x11, 0x1E, 0x12, 0x11, 0x11 },
        'W' => .{ 0x11, 0x11, 0x11, 0x15, 0x15, 0x15, 0x0A },
        '.' => .{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x06 },
        ' ' => .{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
        else => .{ 0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F }, // fallback '?'
    };
}

fn drawBlockText(dc: HDC, text_rect: RECT, text: []const u8, text_color: DWORD) !void {
    if (text.len == 0) return;
    const text_w_px = text_rect.right - text_rect.left;
    const text_h_px = text_rect.bottom - text_rect.top;
    if (text_w_px <= 0 or text_h_px <= 0) return;

    const glyph_w: i32 = 5;
    const glyph_h: i32 = 7;
    const char_units_w: i32 = glyph_w + 1; // 1 pixel spacing

    const width_scale = @divTrunc(text_w_px, @as(i32, @intCast(text.len)) * char_units_w - 1);
    const height_scale = @divTrunc(text_h_px, glyph_h);
    var scale = @min(width_scale, height_scale);
    if (scale < 2) scale = 2;

    const full_w = @as(i32, @intCast(text.len)) * char_units_w * scale - scale;
    const full_h = glyph_h * scale;
    const start_x = text_rect.left + @divTrunc(text_w_px - full_w, 2);
    const start_y = text_rect.top + @divTrunc(text_h_px - full_h, 2);

    const brush = CreateSolidBrush(text_color);
    if (brush == null) return error.Win32CreateBrushFailed;
    defer _ = DeleteObject(@ptrCast(brush));

    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const glyph = glyph5x7(text[i]);
        var row: i32 = 0;
        while (row < glyph_h) : (row += 1) {
            var col: i32 = 0;
            while (col < glyph_w) : (col += 1) {
                const bit = @as(u8, 1) << @as(u3, @intCast(glyph_w - 1 - col));
                if ((glyph[@as(usize, @intCast(row))] & bit) != 0) {
                    const x0 = start_x + @as(i32, @intCast(i)) * char_units_w * scale + col * scale;
                    const y0 = start_y + row * scale;
                    const px = RECT{ .left = x0, .top = y0, .right = x0 + scale, .bottom = y0 + scale };
                    _ = FillRect(dc, &px, brush);
                }
            }
        }
    }
}

pub fn drawLoadingScreen(allocator: std.mem.Allocator, window: Window, text: []const u8) !void {
    _ = allocator;
    const dc = GetDC(window.hwnd);
    if (dc == null) return error.Win32GetDCFailed;
    defer _ = ReleaseDC(window.hwnd, dc);

    var rect: RECT = undefined;
    if (GetClientRect(window.hwnd, &rect) == 0) return error.Win32GetClientRectFailed;

    const bg_color: DWORD = 0x0012141A;
    const text_color: DWORD = 0x00D0E3FF;
    const brush = CreateSolidBrush(bg_color);
    if (brush == null) return error.Win32CreateBrushFailed;
    defer _ = DeleteObject(@ptrCast(brush));

    _ = FillRect(dc, &rect, brush);
    _ = SetBkMode(dc, TRANSPARENT);

    const client_w = rect.right - rect.left;
    const client_h = rect.bottom - rect.top;
    const box_w = @divTrunc(client_w, 2);
    const box_h = @divTrunc(client_h, 2);
    const text_rect = RECT{
        .left = rect.left + @divTrunc(client_w - box_w, 2),
        .top = rect.top + @divTrunc(client_h - box_h, 2),
        .right = rect.left + @divTrunc(client_w - box_w, 2) + box_w,
        .bottom = rect.top + @divTrunc(client_h - box_h, 2) + box_h,
    };

    try drawBlockText(dc, text_rect, text, text_color);
    _ = GdiFlush();
}
