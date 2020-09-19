const std = @import("std");
const math = std.math;

pub const Vec4f = struct {
  x: f32,
  y: f32,
  z: f32,
  w: f32,

  pub inline fn init(x:f32, y:f32, z:f32, w:f32) Vec4f 
  {
    return Vec4f
    {
      .x = x,
      .y = y,
      .z = z,
      .w = w,
    };
  }

  pub fn zero() Vec4f{
    return Vec4f.init(0,0,0,0);
  }

  pub fn one() Vec4f{
    return Vec4f.init(1,1,1,1);
  }

  pub fn half() Vec4f{
    return Vec4f.init(0.5,0.5,0.5,0.5);
  }

  pub inline fn set(self:*Vec4f, other:Vec4f) void 
  {
    self.x = other.x;
    self.y = other.y;
    self.z = other.z;
    self.w = other.w;
  }

  pub inline fn add(self:*Vec4f, other:Vec4f) void 
  {
    self.x += other.x;
    self.y += other.y;
    self.z += other.z;
    self.w += other.w;
  }

  pub inline fn scale(self:*Vec4f, scalar:f32) void 
  {
    self.x *= scalar;
    self.y *= scalar;
    self.z *= scalar;
    self.w *= scalar;
  }

  pub inline fn scaleDup(self:Vec4f, scalar:f32) Vec4f 
  {
    return Vec4f.init(
      self.x * scalar,
      self.y * scalar,
      self.z * scalar,
      self.w * scalar
    );
  }

  pub inline fn div(self:*Vec4f, scalar:f32) void 
  {
    self.x /= scalar;
    self.y /= scalar;
    self.z /= scalar;
    self.w /= scalar;
  }

  pub inline fn dot3(self:Vec4f, other:Vec4f) f32 
  {
    return self.x*other.x + self.y*other.y + self.z*other.z;
  }

  pub inline fn dot(self:Vec4f, other:Vec4f) f32 
  {
    return self.x*other.x 
         + self.y*other.y 
         + self.z*other.z 
         + self.w*other.w;
  }

  pub inline fn cross3(self:Vec4f, other:Vec4f) Vec4f {
    return Vec4f.init(
      self.y * other.y - self.z * other.y,
      self.z * other.x - self.x * other.z,
      self.x * other.y - self.y * other.x,
      0
    );
  }

  pub inline fn sub(self:*Vec4f, other:Vec4f) void {
    self.x -= other.x;
    self.y -= other.y;
    self.z -= other.z;
    self.w -= other.w;
  }

  /// Returns vector length
  pub inline fn length(self:Vec4f) f32 {
    return math.sqrt(self.lengthSqr());
  }

  /// return length of vector squared. Avoids `math.sqrt`
  pub inline fn lengthSqr(self:Vec4f) f32 {
    return self.dot(self);
  }

  /// make `length` of vector 1.0 while maintaining direction
  pub inline fn normalize(self:*Vec4f) void {
    self.div(self.length());
  }

  /// constant version of normalize that returns a new `Vec4f` with length of 1.0
  pub inline fn normalized(self:Vec4f) Vec4f {
    const len = self.length();
    return Vec4f.init(
      self.x / len,
      self.y / len,
      self.z / len,
      self.w / len
    );
  }

  pub inline fn clamp01(self:*Vec4f) void {
    self.clamp(0.0, 1.0);
  }

  pub inline fn clamp(self:*Vec4f, min:f32, max:f32) void {
    self.x = math.clamp(self.x, min, max);
    self.y = math.clamp(self.y, min, max);
    self.z = math.clamp(self.z, min, max);
    self.w = math.clamp(self.w, min, max);
  }

  pub inline fn ceil(self:*Vec4f) void {
    self.x = math.ceil(self.x);
    self.y = math.ceil(self.y);
    self.z = math.ceil(self.z);
    self.w = math.ceil(self.w);
  }

  pub fn print(self:Vec4f) void {
    std.debug.warn(" [{}, {}, {}, {} ]\n", .{self.x, self.y, self.z, self.w});      
  }
};

const assert = @import("std").debug.assert;

const epsilon = 0.00001;

pub fn assert_f32_equal(actual:f32, expected:f32) void{
  assert(math.fabs(actual - expected) < epsilon);
}

test "Vec4f.add" 
{
    var lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    const rhs = Vec4f.init(2.0, 3.0, 4.0, 1.0);
    lhs.add(rhs);

    assert_f32_equal(lhs.x, 3.0);
    assert_f32_equal(lhs.y, 5.0);
    assert_f32_equal(lhs.z, 7.0);
    assert_f32_equal(lhs.w, 2.0);
}


test "Vec4f.set" 
{
    var lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    const rhs = Vec4f.init(2.0, 3.0, 4.0, 1.0);
    lhs.set(rhs);

    assert_f32_equal(lhs.x, rhs.x);
    assert_f32_equal(lhs.y, rhs.y);
    assert_f32_equal(lhs.z, rhs.z);
    assert_f32_equal(lhs.w, rhs.w);
}

test "Vec4f.normalize" 
{
    var lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    lhs.normalize();
    assert_f32_equal(lhs.length(), 1.0);
}

test "Vec4f.normalized" 
{
    const lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    const lhsLen = lhs.length();
    const normal = lhs.normalized();
    assert_f32_equal(normal.length(), 1.0);
    assert_f32_equal(lhs.length(), lhsLen);
}

test "Vec4f.lengthSqr" 
{
    const lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    const len = lhs.length();
    const sqr = lhs.lengthSqr();
    assert_f32_equal(sqr, len * len);
}