
const std = @import("std");
const warn = std.debug.warn;
const fmt = std.fmt;
const assert = @import("std").debug.assert;
const math = std.math;
const io = std.io;

const Vec4f = @import("../core/vector.zig").Vec4f;
const Mat44f = @import("../core/matrix.zig").Mat44f;
const Profile = @import("../core/profiler.zig").Profile;

pub const Format = enum {
  GRAY8,
  RGB8,
  RGBA8,
};

pub const Texture = struct {
  width:u32,
  height:u32,
  colors: []u8,
  format: Format,

  pub fn init(f: Format, w:u32, h:u32, data:[]u8) Texture {
      return Texture{
          .format = f,
          .width = w,
          .height = h,
          .colors = data,
      };
  }

  pub fn sample(self:Texture, x:f32, y:f32) Vec4f {
    const tx = @floatToInt(usize, x * self.width);
    const ty = @floatToInt(usize, y * self.height);
    const index = ty * self.width + tx;

    return Vec4f.init(
      sampleR(index),
      sampleG(index),
      sampleB(index),
      sampleA(index)
    );
  }

  

  pub fn sampleR(self:Texture, index:usize) f32 {
    return switch(self.format){
      .GRAY8, .RGB8, .RGBA8 => @intToFloat(f32, self.colors[index])/255.0,
      else => 0.0
    };
  }

  pub fn sampleG(self:Texture, pixel:usize) f32 {
    return switch(self.format){
      .GRAY8 => @intToFloat(f32, self.colors[pixel])/255.0,
      .RGB8, .RGBA8 => @intToFloat(f32, self.colors[pixel+1])/255.0,
      else => 0.0
    };
  }

  pub fn sampleB(self:Texture, pixel:usize) f32 {
    return switch(self.format){
      .GRAY8 => @intToFloat(f32, self.colors[pixel])/255.0,
      .RGB8, .RGBA8 => @intToFloat(f32, self.colors[pixel+2])/255.0,
      else => 0.0
    };
  }

  pub fn sampleA(self:Texture, pixel:usize) f32 {
    return switch(self.format){
      .RGB8, .GRAY8 => 1.0,
      .RGBA8 => @intToFloat(f32, self.colors[pixel+3])/255.0,
      else => 0.0
    };
  }

  pub fn sampleBilinear(self:Texture, x:f32, y:f32) Vec4f {
    return self.sample(x,y);
  }

  pub fn sampleBiCubic(self:Texture, x:f32, y:f32) Vec4f {
    return self.sample(x,y);
  }
};
    

