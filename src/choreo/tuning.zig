pub const ProfileTuning = struct {
    carry_base_y: f32 = 0.56,
    carry_arc_y: f32 = 0.10,
    carry_base_z: f32 = 0.14,
    carry_arc_z: f32 = 0.22,
    carry_yaw_gain: f32 = 24.0,
    carry_scale: f32 = 1.12,
    carry_rate: f32 = 1.0,

    borrow_base_y: f32 = 0.44,
    borrow_lift: f32 = 0.16,
    borrow_base_z: f32 = 0.10,
    borrow_drop_z: f32 = 0.10,
    borrow_yaw_gain: f32 = 20.0,
    borrow_scale: f32 = 1.08,
    borrow_lift_ratio: f32 = 0.35,
    borrow_piece_delay: f32 = 0.08,
    borrow_rate: f32 = 1.0,

    shift_base_y: f32 = 0.50,
    shift_base_z: f32 = 0.08,
    shift_max_yaw: f32 = 90.0,
    shift_scale: f32 = 1.04,
    shift_rate: f32 = 1.0,
};

pub const storyboard = ProfileTuning{};

pub const cinematic = ProfileTuning{
    .carry_arc_y = 0.12,
    .carry_arc_z = 0.26,
    .carry_scale = 1.16,
    .carry_rate = 1.08,
    .borrow_lift = 0.19,
    .borrow_drop_z = 0.13,
    .borrow_scale = 1.12,
    .borrow_rate = 1.05,
    .shift_max_yaw = 96.0,
    .shift_scale = 1.08,
    .shift_rate = 1.04,
};

pub const debug = ProfileTuning{
    .carry_arc_y = 0.06,
    .carry_arc_z = 0.12,
    .carry_scale = 1.06,
    .carry_rate = 1.0,
    .borrow_lift = 0.10,
    .borrow_drop_z = 0.05,
    .borrow_scale = 1.03,
    .borrow_rate = 1.0,
    .shift_max_yaw = 75.0,
    .shift_scale = 1.0,
    .shift_rate = 1.0,
};
