const std = @import("std");
const math = std.math;

const Vec4f = @import("vector.zig").Vec4f;

pub const Face = struct {
    v: [3]Vec4f,
    vn: [3]Vec4f,
    c: [3]Vec4f,
    uv: [3]Vec4f,

    pub inline fn init(
        v0: Vec4f,
        v1: Vec4f,
        v2: Vec4f,
        vn0: Vec4f,
        vn1: Vec4f,
        vn2: Vec4f,
        c0: Vec4f,
        c1: Vec4f,
        c2: Vec4f,
        uv0: Vec4f,
        uv1: Vec4f,
        uv2: Vec4f,
    ) Face {
        return Face{
            .v = [_]Vec4f{ v0, v1, v2 },
            .vn = [_]Vec4f{ vn0, vn1, vn2 },
            .c = [_]Vec4f{ c0, c1, c2 },
            .uv = [_]Vec4f{ uv0, uv1, uv2 },
        };
    }

    pub fn print(self: Vec4f) void {
        std.debug.print(" [{e}, {e}, {e}, {e} | {e} | {e} ]", .{ self.x, self.y, self.z, self.w, self.length(), self.length3() });
    }

    pub fn println(self: Vec4f) void {
        std.debug.print(" [{e}, {e}, {e}, {e} | {e} | {e} ]\n", .{ self.x, self.y, self.z, self.w, self.length(), self.length3() });
    }

    pub fn interpPoint(self: *Face, point: Vec4f) Vec4f {
        return Vec4f.init((tri.x * v0.x + tri.y * v1.x + tri.z * v2.x) / depth, (tri.x * v0.y + tri.y * v1.y + tri.z * v2.y) / depth, (tri.x * v0.z + tri.y * v1.z + tri.z * v2.z) / depth, w);
    }
};
