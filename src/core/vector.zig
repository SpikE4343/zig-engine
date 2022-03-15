const std = @import("std");
const math = std.math;
const interp = @import("interp.zig");

pub const Vec4f = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub inline fn init(x: f32, y: f32, z: f32, w: f32) Vec4f {
        return Vec4f{
            .x = x,
            .y = y,
            .z = z,
            .w = w,
        };
    }

    pub fn zero() Vec4f {
        return Vec4f.init(0, 0, 0, 0);
    }

    pub fn one() Vec4f {
        return Vec4f.init(1, 1, 1, 1);
    }

    pub fn half() Vec4f {
        return Vec4f.init(0.5, 0.5, 0.5, 0.5);
    }

    pub fn forward() Vec4f {
        return Vec4f.init(0, 0, 1, 1);
    }

    pub fn up() Vec4f {
        return Vec4f.init(0, 1, 0, 1);
    }

    pub fn right() Vec4f {
        return Vec4f.init(1, 0, 0, 1);
    }

    pub inline fn set(self: *Vec4f, other: Vec4f) void {
        self.x = other.x;
        self.y = other.y;
        self.z = other.z;
        self.w = other.w;
    }

    pub inline fn add(self: *Vec4f, other: Vec4f) void {
        self.x += other.x;
        self.y += other.y;
        self.z += other.z;
        self.w += other.w;
    }

    pub inline fn addScalar(self: *Vec4f, scalar: f32) void {
        self.x += scalar;
        self.y += scalar;
        self.z += scalar;
        self.w += scalar;
    }

    pub inline fn addScalarDup(self: Vec4f, scalar: f32) Vec4f {
        var out = self;
        out.addScalar(scalar);
        return out;
    }

    pub inline fn addDup(self: Vec4f, other: Vec4f) Vec4f {
        return Vec4f.init(self.x + other.x, self.y + other.y, self.z + other.z, self.w + other.w);
    }

    pub inline fn mul(self: *Vec4f, other: Vec4f) void {
        self.x *= other.x;
        self.y *= other.y;
        self.z *= other.z;
        self.w *= other.w;
    }

    pub inline fn mulDup(self: Vec4f, other: Vec4f) Vec4f {
        return Vec4f.init(self.x * other.x, self.y * other.y, self.z * other.z, self.w * other.w);
    }

    pub inline fn scale(self: *Vec4f, scalar: f32) void {
        self.x *= scalar;
        self.y *= scalar;
        self.z *= scalar;
        self.w *= scalar;
    }

    pub inline fn scaleDup(self: Vec4f, scalar: f32) Vec4f {
        var out = self;
        out.scale(scalar);
        return out;
    }

    pub inline fn div(self: *Vec4f, scalar: f32) void {
        self.x /= scalar;
        self.y /= scalar;
        self.z /= scalar;
        self.w /= scalar;
    }

    pub inline fn div3(self: *Vec4f, scalar: f32) void {
        self.x /= scalar;
        self.y /= scalar;
        self.z /= scalar;
    }

    pub inline fn divDup(self: Vec4f, scalar: f32) Vec4f {
        var out = self;
        out.div(scalar);
        return out;
    }

    pub inline fn divVec(self: *Vec4f, other: Vec4f) void {
        self.x /= other.x;
        self.y /= other.y;
        self.z /= other.z;
        self.w /= other.w;
    }

    pub inline fn divVecDup(self: Vec4f, other: Vec4f) Vec4f {
        var out = self;
        out.divVec(other);
        return out;
    }

    pub inline fn dot3(self: Vec4f, other: Vec4f) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub inline fn dot(self: Vec4f, other: Vec4f) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z + self.w * other.w;
    }

    pub inline fn cross3(self: Vec4f, other: Vec4f) Vec4f {
        return Vec4f.init(self.y * other.z - self.z * other.y, self.z * other.x - self.x * other.z, self.x * other.y - self.y * other.x, 1);
    }

    pub inline fn sub(self: *Vec4f, other: Vec4f) void {
        self.x -= other.x;
        self.y -= other.y;
        self.z -= other.z;
        self.w -= other.w;
    }

    pub inline fn subDup(self: Vec4f, other: Vec4f) Vec4f {
        var out = self;
        out.sub(other);
        return out;
    }

    pub inline fn subScalar(self: *Vec4f, scalar: f32) void {
        self.x -= scalar;
        self.y -= scalar;
        self.z -= scalar;
        self.w -= scalar;
    }

    /// Returns vector length
    pub inline fn length(self: Vec4f) f32 {
        return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w);
    }

    /// return length of vector squared. Avoids `math.sqrt`
    pub inline fn lengthSqr(self: Vec4f) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w;
    }

    /// make `length` of vector 1.0 while maintaining direction
    pub inline fn normalize(self: *Vec4f) void {
        self.div(self.length());
    }

    /// constant version of normalize that returns a new `Vec4f` with length of 1.0
    pub inline fn normalized(self: Vec4f) Vec4f {
        const len = self.length();
        return Vec4f.init(self.x / len, self.y / len, self.z / len, self.w / len);
    }

    pub inline fn length3(self: Vec4f) f32 {
        return math.sqrt(self.length3Sqr());
    }

    /// return length of vector squared. Avoids `math.sqrt`
    pub inline fn length3Sqr(self: Vec4f) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    /// make `length` of vector 1.0 while maintaining direction
    pub inline fn normalize3(self: *Vec4f) void {
        self.div3(math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z));
    }

    /// constant version of normalize that returns a new `Vec4f` with length of 1.0
    pub inline fn normalized3(self: Vec4f) Vec4f {
        const len = self.length3();
        return Vec4f.init(self.x / len, self.y / len, self.z / len, self.w);
    }

    pub inline fn clamp01(self: *Vec4f) void {
        self.clamp(0.0, 1.0);
    }

    pub inline fn clamp(self: *Vec4f, min: f32, max: f32) void {
        self.x = math.clamp(self.x, min, max);
        self.y = math.clamp(self.y, min, max);
        self.z = math.clamp(self.z, min, max);
        self.w = math.clamp(self.w, min, max);
    }

    pub inline fn ceil(self: *Vec4f) void {
        self.x = math.ceil(self.x);
        self.y = math.ceil(self.y);
        self.z = math.ceil(self.z);
        self.w = math.ceil(self.w);
    }

    pub fn print(self: Vec4f) void {
        std.debug.print(" [{}, {}, {}, {} | {} | {} ]", .{ self.x, self.y, self.z, self.w, self.length(), self.length3() });
    }

    pub fn println(self: Vec4f) void {
        std.debug.print(" [{}, {}, {}, {} | {} | {} ]\n", .{ self.x, self.y, self.z, self.w, self.length(), self.length3() });
    }

    pub fn eq(self: Vec4f, other: Vec4f, _epsilon: f32) bool {
        return (math.fabs(self.x - other.x) < _epsilon) and
            (math.fabs(self.y - other.y) < _epsilon) and
            (math.fabs(self.z - other.z) < _epsilon) and
            (math.fabs(self.w - other.w) < _epsilon);
    }

    pub fn eq3(self: Vec4f, other: Vec4f, _epsilon: f32) bool {
        return (math.fabs(self.x - other.x) < _epsilon) and
            (math.fabs(self.y - other.y) < _epsilon) and
            (math.fabs(self.z - other.z) < _epsilon);
    }

    pub fn triArea(a: Vec4f, b: Vec4f, c: Vec4f) f32 {
        return (c.x - a.x) * (b.y - a.y) - (c.y - a.y) * (b.x - a.x);
    }

    pub fn triCoords(v0: Vec4f, v1: Vec4f, v2: Vec4f, p: Vec4f) Vec4f {
        return Vec4f.init(triArea(v1, v2, p), triArea(v2, v0, p), triArea(v0, v1, p), 0);
    }

    pub fn triInterp(tri: Vec4f, v0: Vec4f, v1: Vec4f, v2: Vec4f, depth: f32, w: f32) Vec4f {
        return Vec4f.init((tri.x * v0.x + tri.y * v1.x + tri.z * v2.x) / depth, (tri.x * v0.y + tri.y * v1.y + tri.z * v2.y) / depth, (tri.x * v0.z + tri.y * v1.z + tri.z * v2.z) / depth, w);
    }

    pub fn lerpDup(from: Vec4f, to: Vec4f, d: f32) Vec4f {
        return Vec4f.init(interp.lerp(f32, from.x, to.x, d), interp.lerp(f32, from.y, to.y, d), interp.lerp(f32, from.z, to.z, d), interp.lerp(f32, from.w, to.w, d));
    }

    pub fn blerpDup(fromx: Vec4f, tox: Vec4f, fromy: Vec4f, toy: Vec4f, dx: f32, dy: f32) Vec4f {
        return lerpDup(lerpDup(fromx, tox, dx), lerpDup(fromy, toy, dx), dy);
    }

    pub fn lerp(self: *Vec4f, from: Vec4f, to: Vec4f, d: f32) void {
        self.x = interp.lerp(from.x, to.x, d);
        self.y = interp.lerp(from.y, to.y, d);
        self.z = interp.lerp(from.z, to.z, d);
        self.w = interp.lerp(from.w, to.w, d);
    }
};

const assert = @import("std").debug.assert;

const epsilon = 0.00001;

pub fn assert_f32_equal(actual: f32, expected: f32) void {
    assert(math.fabs(actual - expected) < epsilon);
}

test "Vec4f.add" {
    var lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    const rhs = Vec4f.init(2.0, 3.0, 4.0, 1.0);
    lhs.add(rhs);

    assert_f32_equal(lhs.x, 3.0);
    assert_f32_equal(lhs.y, 5.0);
    assert_f32_equal(lhs.z, 7.0);
    assert_f32_equal(lhs.w, 2.0);
}

test "Vec4f.set" {
    var lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    const rhs = Vec4f.init(2.0, 3.0, 4.0, 1.0);
    lhs.set(rhs);

    assert_f32_equal(lhs.x, rhs.x);
    assert_f32_equal(lhs.y, rhs.y);
    assert_f32_equal(lhs.z, rhs.z);
    assert_f32_equal(lhs.w, rhs.w);
}

test "Vec4f.normalize" {
    var lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    lhs.normalize();
    assert_f32_equal(lhs.length(), 1.0);
}

test "Vec4f.normalized" {
    const lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    const lhsLen = lhs.length();
    const normal = lhs.normalized();
    assert_f32_equal(normal.length(), 1.0);
    assert_f32_equal(lhs.length(), lhsLen);
}

test "Vec4f.lengthSqr" {
    const lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    const len = lhs.length();
    const sqr = lhs.lengthSqr();
    assert_f32_equal(sqr, len * len);
}
