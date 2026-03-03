pub const LogicalTime = struct {
    tick: u32,
    substep: u16,
};

pub const EventKind = enum {
    digit_place,
    column_overflow,
    carry_emit,
    carry_receive,
    borrow_request,
    borrow_expand,
    digit_settle,
    result_finalize,
};

pub const Event = struct {
    time: LogicalTime,
    kind: EventKind,
    column: u16,
    value: u16,
    carry_to_column: ?u16 = null,
    borrow_from_column: ?u16 = null,
};
