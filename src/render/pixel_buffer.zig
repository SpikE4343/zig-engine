
const std = @import("std");
const warn = std.debug.warn;
const fmt = std.fmt;
const assert = @import("std").debug.assert;
const math = std.math;

const Vec4f = @import("../core/vector.zig").Vec4f;
const Mat44f = @import("../core/matrix.zig").Mat44f;
const Profile = @import("../core/profiler.zig").Profile;

const Allocator = std.mem.Allocator;


pub fn PixelBuffer( comptime PixelType : type) type
{
  return struct {
    const SelfType = @This();  
    buffer: std.ArrayList(PixelType),
    w: i32,
    h: i32,

    pub fn init(nW: i32, nH: i32, allocator: *Allocator) !SelfType {
        var self = SelfType {
          .w = nW,
          .h = nH,
          .buffer = std.ArrayList(PixelType).init(allocator),
        };

        try self.resize(nW, nH);

        return self;
    }

    pub fn deinit(self: *SelfType) void {
      self.*.buffer.deinit();
    }

    pub fn clear(self: *SelfType, p: PixelType) void {
      std.mem.set(PixelType, self.*.buffer.items[0..], p);
    }

    pub inline fn write(self: *SelfType, x: i32, y: i32, value: PixelType) void {
      self.*.buffer.items[@intCast(usize, x + self.*.w * y)] = value;
    }

    pub inline fn read(self: *SelfType, x: i32, y:i32) PixelType {
      return self.*.buffer.items[@intCast(usize, x + self.*.w * y)];
    }

    pub inline fn setLessThan(self:*SelfType, x: i32, y: i32, value:PixelType) u1 {
      const index = @intCast(usize, x + self.*.w * y);

      //TODO: attempt atomic for thread safety
      if( value < self.*.buffer.items[index] )
      {
        self.*.buffer.items[index] = value;
        return 1;
      }

      return 0;
      //return if( @atomicRmw(PixelType, &self.*.buffer.items[index], .Min, value, .SeqCst ) == self.*.buffer[index] ) 0 else 1;
    }

    pub fn resize(self: *SelfType, nW: i32, nH: i32) !void {
      self.*.w = nW;
      self.*.h = nH;
      try self.*.buffer.resize(@intCast(usize, nH * nW * @sizeOf(PixelType)));
    }

    pub inline fn bufferStart(self: *SelfType) *PixelType {
        return &self.*.buffer.items[0];
    }

    pub inline fn bufferLineSize(self: *SelfType) usize {
        return @intCast(usize,self.w) * @sizeOf(PixelType);
    }
};
}

const Vec2 = struct {
    x: f32,
    y: f32,
};

pub fn dot(a: Vec2, b: Vec2) f32 {
    return a.x * b.x + a.y * b.y;
}

pub fn norm(a: Vec2) Vec2 {
    const len = @sqrt(dot(a, a));
    return Vec2{
        .x = a.x / len,
        .y = a.y / len,
    };
}

pub fn scale(a: Vec2, b: f32) Vec2 {
    return Vec2{
        .x = a.x * b,
        .y = a.y * b,
    };
}


pub fn PixelRenderer( comptime PixelType: type) type {
  return struct {
    const SelfType = @This();
    buffer : *PixelBuffer(PixelType),

    pub fn init(buf:*PixelBuffer(PixelType)) SelfType {
      return SelfType {
        .buffer = buf
      };
    }

    pub fn drawThickLine(self:*SelfType, xFrom: c_int, yFrom: c_int, xTo: c_int, yTo: c_int, value: PixelType, thickness: f32) void {
        const thickness2 = thickness * thickness;
        var x0: c_int = undefined;
        var x1: c_int = undefined;
        var y0: c_int = undefined;
        var y1: c_int = undefined;
        if (xFrom < xTo) {
            x0 = xFrom;
            x1 = xTo;
        } else {
            x0 = xTo;
            x1 = xFrom;
        }
        if (yFrom < yTo) {
            y0 = yFrom;
            y1 = yTo;
        } else {
            y0 = yTo;
            y1 = yFrom;
        }

        if (x0 == x1 and y0 == y1) {
            return;
        }

        const intThickness = @floatToInt(c_int, @ceil(thickness));
        const X0 = x0 - intThickness;
        const Y0 = y0 - intThickness;
        const X1 = x1 + intThickness;
        const Y1 = y1 + intThickness;

        const v01 = Vec2{
            .x = @intToFloat(f32, xTo - xFrom),
            .y = @intToFloat(f32, yTo - yFrom),
        };

        var iy: c_int = Y0;
        while (iy <= Y1) {
            const y: f32 = @intToFloat(f32, iy);
            var ix: c_int = X0;
            while (ix <= X1) {
                const x: f32 = @intToFloat(f32, ix);
                const v = Vec2{
                    .x = x - @intToFloat(f32, xFrom),
                    .y = y - @intToFloat(f32, yFrom),
                };
                const h1 = dot(v, v);
                const c1 = dot(norm(v01), v) * dot(norm(v01), v);
                const distToLine2: f32 = h1 - c1;
                assert(distToLine2 > -0.001);
                if (distToLine2 < thickness2) {
                    self.buffer.write(ix, iy, value);
                }
                ix += 1;
            }
            iy += 1;
        }
    }

    pub fn drawLine(self:*SelfType, xFrom: i32, yFrom: i32, xTo: i32, yTo: i32, value: PixelType) void {
        if (xFrom == xTo and yFrom == yTo) {
            self.buffer.write(xFrom, yFrom, value);
        }
        var x0: i32 = undefined;
        var x1: i32 = undefined;
        var y0: i32 = undefined;
        var y1: i32 = undefined;
        var invX: bool = undefined;
        var invY: bool = undefined;
        if (xFrom < xTo) {
            x0 = xFrom;
            x1 = xTo;
            invX = false;
        } else {
            x0 = xTo;
            x1 = xFrom;
            invX = true;
        }
        if (yFrom < yTo) {
            y0 = yFrom;
            y1 = yTo;
            invY = false;
        } else {
            y0 = yTo;
            y1 = yFrom;
            invY = true;
        }
        if (x1 - x0 < y1 - y0) {
            var y: i32 = y0;
            while (y <= y1) {
                const inc = @divFloor((x1 - x0 + 1) * (y - y0), y1 - y0 + 1);
                const x = block: {
                    if (invX == invY) {
                        break :block x0 + inc;
                    } else {
                        break :block x1 - inc;
                    }
                };
                self.buffer.write(x, y, value);
                y += 1;
            }
        } else {
            var x: i32 = x0;
            while (x <= x1) {
                const inc = @divFloor((y1 - y0 + 1) * (x - x0), x1 - x0 + 1);
                const y = block: {
                    if (invX == invY) {
                        break :block y0 + inc;
                    } else {
                        break :block y1 - inc;
                    }
                };
                self.buffer.write(x, y, value);
                x += 1;
            }
        }
    }
  };
}




test "Pixel Buffer" {
  var allocator = std.heap.page_allocator;
  var buf = try PixelBuffer(f32).init(10, 10, allocator);

  const data = 1.0;

  buf.write(0,0, data);

  const value = buf.read(0,0);

  assert(value == data);
}


fn assert_value(buf: *PixelBuffer(Vec2), x:i32, y:i32, expected:Vec2) void {
  const value = buf.read(5,5);
  assert(value.x == expected.x and value.y == expected.y);
}

test "Pixel Line Renderer" {
  var allocator = std.heap.page_allocator;
  var buf = try PixelBuffer(Vec2).init(10, 10, allocator);
  defer buf.deinit();

  var renderer = PixelRenderer(Vec2).init(&buf);

  const expected = Vec2 { .x=0.5, .y=0.2};
  renderer.drawLine(0,0, 9, 9, expected);

  assert_value(&buf, 0,0, expected);
  assert_value(&buf, 9,9, expected);

  assert_value(&buf, 5,5, expected);  
}