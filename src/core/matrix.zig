const std = @import("std");
const math = std.math;
const vector = @import("vector.zig");
const Vec4f = vector.Vec4f;
const assert_f32_equal = vector.assert_f32_equal;

const PI = 3.1415926535897932384626433832795;
const DEG2RAD = PI / 180.0;

pub const Mat44f = struct {
    mm: [4]Vec4f,

    pub inline fn init(self: *Mat44f, values: [4]Vec4f) void {
        self.mm = values;
    }

    pub inline fn identity() Mat44f {
        return Mat44f{
            .mm = [4]Vec4f{
                Vec4f.init(1, 0, 0, 0),
                Vec4f.init(0, 1, 0, 0),
                Vec4f.init(0, 0, 1, 0),
                Vec4f.init(0, 0, 0, 1),
            },
        };
    }

    pub inline fn mul_vec4(self: Mat44f, vec: Vec4f) Vec4f {
        return Vec4f.init(
            self.mm[0].dot(vec), 
            self.mm[1].dot(vec), 
            self.mm[2].dot(vec), 
            self.mm[3].dot(vec)
            );
    }

    pub inline fn col(self: Mat44f, index: u2) Vec4f {
        switch (index) {
            0 => return Vec4f.init(self.mm[0].x, self.mm[1].x, self.mm[2].x, self.mm[3].x),
            1 => return Vec4f.init(self.mm[0].y, self.mm[1].y, self.mm[2].y, self.mm[3].y),
            2 => return Vec4f.init(self.mm[0].z, self.mm[1].z, self.mm[2].z, self.mm[3].z),
            3 => return Vec4f.init(self.mm[0].w, self.mm[1].w, self.mm[2].w, self.mm[3].w),
            //else => @compileError("Invalid mat44 column index {}",.{index}),
        }
        unreachable;
    }

    pub inline fn mul(self: *Mat44f, other: Mat44f) void {
        for(self.mm) | row, i| {
            self.mm[i].x = row.dot(other.col(0));
            self.mm[i].y = row.dot(other.col(1));
            self.mm[i].z = row.dot(other.col(2));
            self.mm[i].w = row.dot(other.col(3));
        }
    }

    pub inline fn mul33(self: *Mat44f, v: Vec4f) Vec4f {
        const invW = 1.0; // / self.mm[3].dot(v);
        return Vec4f.init(self.mm[0].dot(v) * invW, self.mm[1].dot(v) * invW, self.mm[2].dot(v) * invW, 0);
    }

    pub fn createPerspective(fovy: f32, aspect: f32, nearZ: f32, farZ: f32) Mat44f {
        const tangent = math.tan(fovy / 2 * DEG2RAD); // tangent of half fovY
        const height = nearZ * tangent; // half height of near plane
        const width = height * aspect; // half width of near plane

        const left = -width;
        const right = width;
        const bottom = -height;
        const top = height;

        const deltaX = right - left;
        const deltaY = top - bottom;
        const deltaZ = farZ - nearZ;

        // if ((nearZ <= 0.0f) || (farZ <= 0.0f) || (deltaX <= 0.0f) || (deltaY <= 0.0f) || (deltaZ <= 0.0f))
        //   return;
        return Mat44f{
            .mm = [4]Vec4f{
                Vec4f.init((2.0 * nearZ) / deltaX, 0.0, (right + left) / deltaX, 0.0),
                Vec4f.init(0.0, (2.0 * nearZ) / deltaY, (top + bottom) / deltaY, 0.0),
                Vec4f.init(0.0, 0.0, -(farZ + nearZ) / deltaZ, (-2.0 * nearZ * farZ) / deltaZ),
                Vec4f.init(0.0, 0.0, -1.0, 0.0),
            },
        };
    }

    pub fn translate(self: *Mat44f, vec: Vec4f) void {
        const tmp = Mat44f{
            .mm = [4]Vec4f{
                Vec4f.init(1, 0, 0, vec.x),
                Vec4f.init(0, 1, 0, vec.y),
                Vec4f.init(0, 0, 1, vec.z),
                Vec4f.init(0, 0, 0, 1),
            },
        };

        self.mul(tmp);
    }

    pub fn print(self:*Mat44f) void {
        std.debug.warn("[\n",.{});
        self.mm[0].print();
        self.mm[1].print();
        self.mm[2].print();
        self.mm[3].print();
        std.debug.warn("]\n",.{});
    }
};

test "Mat44f.mul" {
    const lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    const v = lhs;
    //const mat = Mat44f.init([0.0]f32 ** (4*4));

    assert_f32_equal(lhs.x, 1.0);
    assert_f32_equal(lhs.y, 2.0);
    assert_f32_equal(lhs.z, 3.0);
    assert_f32_equal(lhs.w, 1.0);
}

test "Mat44f.translate" {
    const lhs = Vec4f.init(0.0, 0.0, 1.0, 1.0);
    var model = Mat44f.identity();

    model.print();
    model.translate(lhs);
    model.print();

    const origin = model.mul_vec4(Vec4f.zero());

    //const mat = Mat44f.init([0.0]f32 ** (4*4));

    assert_f32_equal(lhs.x, origin.x);
    assert_f32_equal(lhs.y, origin.y);
    std.debug.warn("\n{} ? {}\n", .{lhs.z, origin.z});
    assert_f32_equal(lhs.z, origin.z);
    assert_f32_equal(lhs.w, origin.w);
}
