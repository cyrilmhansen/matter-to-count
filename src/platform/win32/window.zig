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
extern "user32" fn LoadCursorW(hInstance: HINSTANCE, lpCursorName: ?*const anyopaque) callconv(.winapi) HCURSOR;
extern "user32" fn DrawIconEx(hdc: HDC, xLeft: i32, yTop: i32, hIcon: HCURSOR, cxWidth: i32, cyWidth: i32, istepIfAniCur: UINT, hbrFlickerFreeDraw: HBRUSH, diFlags: UINT) callconv(.winapi) BOOL;
extern "user32" fn SetCursor(hCursor: HCURSOR) callconv(.winapi) HCURSOR;
extern "user32" fn GetSystemMetrics(nIndex: i32) callconv(.winapi) i32;

const SM_CXSCREEN: i32 = 0;
const SM_CYSCREEN: i32 = 1;

const IDC_CROSS_INT: usize = 32515;
const DI_NORMAL: UINT = 0x0003;

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
