
const std = @import("std");
const warn = std.debug.warn;
const fmt = std.fmt;
const assert = @import("std").debug.assert;
const math = std.math;
const io = std.io;

const Vec4f = @import("../core/vector.zig").Vec4f;
const Mat44f = @import("../core/matrix.zig").Mat44f;
const Profile = @import("../core/profiler.zig").Profile;
const Texture = @import("texture.zig").Texture;

pub const VertexShaderFunc = fn(mvp: *const Mat44f, index: u16, v: Vec4f, material:*Material) Vec4f;
pub const ProjectionShaderFunc = fn(p: *const Mat44f, v: Vec4f, viewport:Vec4f, material:*Material) Vec4f;
pub const PixelShaderFunc = fn(
  mvp: *const Mat44f, 
  pixel: Vec4f, 
  color: Vec4f, 
  normal:Vec4f,
  uv:Vec4f, 
  material:*Material) Vec4f;

pub const Material = struct {
  depthTest:u1,
  lightDirection:Vec4f,
  lightColor:Vec4f,
  lightIntensity:f32, 

  texture:Texture,

  vertexShader: VertexShaderFunc,
  pixelShader: PixelShaderFunc,
  projectionShader: ProjectionShaderFunc,
};
