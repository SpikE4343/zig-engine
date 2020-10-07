
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
  width:f32,
  height:f32,
  iwidth:i32,
  iheight:i32,
  colors: []u8,
  format: Format,
  widthBytes: u32,
  heightBytes: u32,
  pixelWidth: u32,

  pub fn init(f: Format, w:u32, h:u32, pixelBytes:u8, data:[]u8) Texture {
      return Texture{
          .format = f,
          .width = @intToFloat(f32, w),
          .height = @intToFloat(f32, h),
          .iwidth = @intCast(i32, w),
          .iheight = @intCast(i32, h), 
          .colors = data,
          .widthBytes = w*pixelBytes,
          .heightBytes = h*pixelBytes,
          .pixelWidth = pixelBytes,
      };
  }

  pub fn sample(self:Texture, x:f32, y:f32) Vec4f {
    const tx = @floatToInt(usize, x * self.width);
    const ty = @floatToInt(usize, y * self.height);
    const index = ty * self.widthBytes + tx * self.pixelWidth;

    return Vec4f.init(
      self.sampleR(index),
      self.sampleG(index),
      self.sampleB(index),
      self.sampleA(index)
    );
  }

  pub fn samplePixel(self:Texture, x:i32, y:i32) Vec4f {
    const tx = @intCast(u32, std.math.clamp(x, 0, self.iwidth));
    const ty = @intCast(u32, std.math.clamp(y, 0, self.iheight));
    const index = ty * self.widthBytes + tx * self.pixelWidth;

    return Vec4f.init(
      self.sampleR(index),
      self.sampleG(index),
      self.sampleB(index),
      self.sampleA(index)
    );
  }

  

  pub fn sampleR(self:Texture, index:usize) f32 {
    return switch(self.format){
      .GRAY8, .RGB8, .RGBA8 => @intToFloat(f32, self.colors[index])/255.0,
      //else => 0.0
    };
  }

  pub fn sampleG(self:Texture, pixel:usize) f32 {
    return switch(self.format){
      .GRAY8 => @intToFloat(f32, self.colors[pixel])/255.0,
      .RGB8, .RGBA8 => @intToFloat(f32, self.colors[pixel+1])/255.0,
      //else => 0.0
    };
  }

  pub fn sampleB(self:Texture, pixel:usize) f32 {
    return switch(self.format){
      .GRAY8 => @intToFloat(f32, self.colors[pixel])/255.0,
      .RGB8, .RGBA8 => @intToFloat(f32, self.colors[pixel+2])/255.0,
      //else => 0.0
    };
  }

  pub fn sampleA(self:Texture, pixel:usize) f32 {
    return switch(self.format){
      .RGB8, .GRAY8 => 1.0,
      .RGBA8 => @intToFloat(f32, self.colors[pixel+3])/255.0,
      //else => 0.0
    };
  }

  pub fn sampleBilinear(self:Texture, x:f32, y:f32) Vec4f {
    const tx = @floatToInt(i32, x*self.width);
    const ty = @floatToInt(i32, y*self.height);

    const dx = x*self.width - @intToFloat(f32,tx);
    const dy = y*self.height - @intToFloat(f32,ty);

    const s0 = self.samplePixel(tx,ty);
    const s1 = self.samplePixel(tx+1,ty);
    const s2 = self.samplePixel(tx,ty+1);
    const s3 = self.samplePixel(tx+1,ty+1);

    return Vec4f.blerpDup(s0, s1, s2, s3, dx, dy );
  }

  pub fn sampleBiCubic(self:Texture, x:f32, y:f32) Vec4f {
    return self.sample(x,y);
  }
};
    

