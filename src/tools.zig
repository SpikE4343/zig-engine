// platform imports
const std = @import("std");
const fmt = std.fmt;
const warn = std.debug.warn;
const assert = std.debug.assert;
const Timer = std.time.Timer;

pub const MeshObjLoader = @import("tools/render/obj_mesh_loader.zig");

pub const TgaTexLoader = @import("tools/render/tga_texture_loader.zig");

pub var stdout = std.io.getStdOut();