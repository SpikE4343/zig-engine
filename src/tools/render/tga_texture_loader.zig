const std = @import("std");
const warn = std.debug.warn;
const fmt = std.fmt;
const assert = @import("std").debug.assert;
const math = std.math;
const io = std.io;
const Allocator = std.mem.Allocator;
const Texture = @import("../../render/texture.zig").Texture;
const TextureFormat = @import("../../render/texture.zig").Format;

///https://en.wikipedia.org/wiki/Truevision_TGA
// Image type (field 3)

// is enumerated in the lower three bits, with the fourth bit as a flag for RLE. Some possible values are:

// 0 no image data is present
// 1 uncompressed color-mapped image
// 2 uncompressed true-color image
// 3 uncompressed black-and-white (grayscale) image
// 9 run-length encoded color-mapped image
// 10 run-length encoded true-color image
// 11 run-length encoded black-and-white (grayscale) image
// Image type 1 and 9: Depending on the Pixel Depth value, image data representation is an 8, 15, or 16 bit index into a color map that defines the color of the pixel. Image type 2 and 10: The image data is a direct representation of the pixel color. For a Pixel Depth of 15 and 16 bit, each pixel is stored with 5 bits per color. If the pixel depth is 16 bits, the topmost bit is reserved for transparency. For a pixel depth of 24 bits, each pixel is stored with 8 bits per color. A 32-bit pixel depth defines an additional 8-bit alpha channel. Image type 3 and 11: The image data is a direct representation of grayscale data. The pixel depth is 8 bits for images of this type.


const TGA_HEADER = packed struct
{
  IdSize:u8,
  MapType:u8,
  ImageType:u8,
  PaletteStart:u16,
  PaletteSize:u16,
  PaletteEntryDepth:u8,
  X:u16,
  Y:u16,
  Width:u16,
  Height:u16,
  ColorDepth:u8,
  Descriptor:u8,

  pub fn bufferSize(self:@This()) usize {
    return self.pixelWidth() * @intCast(usize, self.Width) * @intCast(usize, self.Height);
  }

  pub fn pixelWidth(self:@This()) u8 {
    return self.ColorDepth >> 3;
  }
} ;

pub const Error = error{InvalidImageFormat};

pub fn importTGAFile(allocator: *Allocator, file_path: []const u8) !Texture
{
  const cwd = std.fs.cwd();

  var resolvedPath = try std.fs.path.resolve(allocator, &[_][]const u8{file_path});
  defer allocator.free(resolvedPath);

  std.debug.warn("path: {}", .{resolvedPath});

  var file = try cwd.openFile(resolvedPath, .{});
  defer file.close();

  var stream_source = io.StreamSource{ .file = file };
  var in = stream_source.inStream();

  const header = try in.readStruct(TGA_HEADER);

  const format:TextureFormat = switch(header.ImageType){
    2 => .RGB8,
    3 => .GRAY8,
    else => return error.InvalidImageFormat,
  };

  const bufferSize = header.bufferSize();

  var data = try allocator.alloc(u8, bufferSize);
  
  const read = try in.readAll(data);


  return Texture.init(format, header.Width, header.Height, header.pixelWidth(), data);
  }