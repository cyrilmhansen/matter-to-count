const std = @import("std");

pub const Dot = struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const SceneState = struct {
    dots: []Dot,
};

pub fn snapshotHash(scene: SceneState) u64 {
    var hasher = std.hash.Wyhash.init(0);
    for (scene.dots) |d| {
        hasher.update(std.mem.asBytes(&d.x));
        hasher.update(std.mem.asBytes(&d.y));
        hasher.update(std.mem.asBytes(&d.z));
    }
    return hasher.final();
}
