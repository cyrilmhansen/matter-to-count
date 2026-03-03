pub const Fixture = struct {
    name: []const u8,
    base: u8,
    lhs: u64,
    rhs: u64,
    expected: u64,
};

pub const add_decimal_single_carry = Fixture{
    .name = "add_decimal_single_carry",
    .base = 10,
    .lhs = 17,
    .rhs = 8,
    .expected = 25,
};

pub const add_decimal_cascade_carry = Fixture{
    .name = "add_decimal_cascade_carry",
    .base = 10,
    .lhs = 199,
    .rhs = 7,
    .expected = 206,
};

pub const sub_decimal_borrow_once = Fixture{
    .name = "sub_decimal_borrow_once",
    .base = 10,
    .lhs = 52,
    .rhs = 7,
    .expected = 45,
};

pub const sub_decimal_borrow_chain = Fixture{
    .name = "sub_decimal_borrow_chain",
    .base = 10,
    .lhs = 1000,
    .rhs = 1,
    .expected = 999,
};

pub const shift_decimal_left_once = Fixture{
    .name = "shift_decimal_left_once",
    .base = 10,
    .lhs = 27,
    .rhs = 0,
    .expected = 270,
};

pub const shift_binary_left_once = Fixture{
    .name = "shift_binary_left_once",
    .base = 2,
    .lhs = 0b1011,
    .rhs = 0,
    .expected = 0b10110,
};
