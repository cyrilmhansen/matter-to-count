const builtin = @import("builtin");

pub const windows = builtin.os.tag == .windows;

pub const BOOL = i32;
pub const UINT = u32;
pub const DWORD = u32;
pub const ULONG = u32;
pub const HRESULT = i32;
pub const HWND = ?*anyopaque;
pub const HINSTANCE = ?*anyopaque;
pub const HICON = ?*anyopaque;
pub const HCURSOR = ?*anyopaque;
pub const HBRUSH = ?*anyopaque;
pub const HMENU = ?*anyopaque;
pub const HMODULE = ?*anyopaque;
pub const HDC = ?*anyopaque;
pub const LPCWSTR = [*:0]const u16;
pub const LPVOID = ?*anyopaque;
pub const WPARAM = usize;
pub const LPARAM = isize;
pub const LRESULT = isize;
pub const ATOM = u16;

pub const GUID = extern struct {
    Data1: u32,
    Data2: u16,
    Data3: u16,
    Data4: [8]u8,
};

pub const TRUE: BOOL = 1;
pub const FALSE: BOOL = 0;
pub const S_OK: HRESULT = 0;
