const builtin = @import("builtin");

pub const windows = builtin.os.tag == .windows;

pub const BOOL = i32;
pub const UINT = u32;
pub const ULONG = u32;
pub const HRESULT = i32;
pub const HWND = ?*anyopaque;

pub const GUID = extern struct {
    Data1: u32,
    Data2: u16,
    Data3: u16,
    Data4: [8]u8,
};

pub const TRUE: BOOL = 1;
pub const FALSE: BOOL = 0;
pub const S_OK: HRESULT = 0;
