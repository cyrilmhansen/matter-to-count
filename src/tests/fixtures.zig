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

pub const add_base60_single_carry = Fixture{
    .name = "add_base60_single_carry",
    .base = 60,
    .lhs = 59,
    .rhs = 1,
    .expected = 60,
};

pub const add_base60_cascade_carry = Fixture{
    .name = "add_base60_cascade_carry",
    .base = 60,
    .lhs = 3599,
    .rhs = 2,
    .expected = 3601,
};

pub const add_hex_single_carry = Fixture{
    .name = "add_hex_single_carry",
    .base = 16,
    .lhs = 0x1f,
    .rhs = 0x1,
    .expected = 0x20,
};

pub const add_binary_cascade_carry = Fixture{
    .name = "add_binary_cascade_carry",
    .base = 2,
    .lhs = 0b111,
    .rhs = 0b1,
    .expected = 0b1000,
};

pub const add_octal_single_carry = Fixture{
    .name = "add_octal_single_carry",
    .base = 8,
    .lhs = 0o77,
    .rhs = 0o1,
    .expected = 0o100,
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

pub const sub_base60_borrow_chain = Fixture{
    .name = "sub_base60_borrow_chain",
    .base = 60,
    .lhs = 3600,
    .rhs = 1,
    .expected = 3599,
};

pub const shift_decimal_left_once = Fixture{
    .name = "shift_decimal_left_once",
    .base = 10,
    .lhs = 27,
    .rhs = 0,
    .expected = 270,
};

pub const shift_base60_left_once = Fixture{
    .name = "shift_base60_left_once",
    .base = 60,
    .lhs = 61,
    .rhs = 0,
    .expected = 3660,
};

pub const shift_binary_left_once = Fixture{
    .name = "shift_binary_left_once",
    .base = 2,
    .lhs = 0b1011,
    .rhs = 0,
    .expected = 0b10110,
};

pub const mul_base60_basic = Fixture{
    .name = "mul_base60_basic",
    .base = 60,
    .lhs = 61,
    .rhs = 62,
    .expected = 3782,
};

pub const mul_base60_carry = Fixture{
    .name = "mul_base60_carry",
    .base = 60,
    .lhs = 119,
    .rhs = 59,
    .expected = 7021,
};

pub const mul_base16_basic = Fixture{
    .name = "mul_base16_basic",
    .base = 16,
    .lhs = 0x1f,
    .rhs = 0x2,
    .expected = 0x3e,
};

pub const mul_base2_basic = Fixture{
    .name = "mul_base2_basic",
    .base = 2,
    .lhs = 0b1011,
    .rhs = 0b11,
    .expected = 0b100001,
};

pub const mul_base8_basic = Fixture{
    .name = "mul_base8_basic",
    .base = 8,
    .lhs = 0o17,
    .rhs = 0o3,
    .expected = 0o55,
};
