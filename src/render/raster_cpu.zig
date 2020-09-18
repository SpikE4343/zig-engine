// compile in ubuntu:
// $ zig build-exe paint.zig --library SDL2 --library SDL2main --library c -isystem "/usr/include" --library-path "/usr/lib/x86_64-linux-gnu"

const std = @import("std");
const warn = std.debug.warn;
const fmt = std.fmt;
const assert = @import("std").debug.assert;
const math = std.math;

const Vec4f = @import("../core/vector.zig").Vec4f;
const Mat44f = @import("../core/matrix.zig").Mat44f;

const Profile = @import("../core/profiler.zig").Profile;

/// RGBA 32 bit color value
pub const Color = struct {
    color: [4]u8 = [4]u8{ 0, 0, 0, 0 },

    pub fn r(self: Color) u8 {
        return self.color[0];
    }
    pub fn g(self: Color) u8 {
        return self.color[1];
    }
    pub fn b(self: Color) u8 {
        return self.color[2];
    }
    pub fn a(self: Color) u8 {
        return self.color[3];
    }
    pub fn setR(self: *Color, val: u8) void {
        self.color[0] = val;
    }
    pub fn setG(self: *Color, val: u8) void {
        self.color[1] = val;
    }
    pub fn setB(self: *Color, val: u8) void {
        self.color[2] = val;
    }
    pub fn setA(self: *Color, val: u8) void {
        self.color[3] = val;
    }

    pub fn white() Color {
        var color = Color{ .color = [4]u8{ 255, 255, 255, 255 } };
        return color;
    }

    pub fn black() Color {
        var color = Color{ .color = [4]u8{ 0, 0, 0, 255 } };
        return color;
    }

    pub fn init(cr: u8, cg: u8, cb: u8, ca: u8) Color {
        return Color{ .color = [4]u8{ cr, cg, cb, ca } };
    }

    pub fn fromNormal(cr: f32, cg:f32, cb:f32, ca:f32) Color {
      return init( 
        @floatToInt(u8, cr*255),
        @floatToInt(u8, cg*255),
        @floatToInt(u8, cb*255),
        @floatToInt(u8, ca*255)
      );
    }
};

const Vec2 = struct {
    x: f64,
    y: f64,
};

pub fn dot(a: Vec2, b: Vec2) f64 {
    return a.x * b.x + a.y * b.y;
}

pub fn norm(a: Vec2) Vec2 {
    const len = @sqrt(dot(a, a));
    return Vec2{
        .x = a.x / len,
        .y = a.y / len,
    };
}

pub fn scale(a: Vec2, b: f64) Vec2 {
    return Vec2{
        .x = a.x * b,
        .y = a.y * b,
    };
}

pub const Mesh = struct {
    vertexBuffer: []Vec4f,
    indexBuffer: []u16,
    colorBuffer: []Vec4f,

    pub fn init(verts: []Vec4f, indicies: []u16, colors: []Vec4f) Mesh {
        return Mesh{
            .vertexBuffer = verts,
            .indexBuffer = indicies,
            .colorBuffer = colors,
        };
    }
};

// TODO: allocate from heap
const PixelBuffers = struct {
    const pixelsCapacity = 800 * 600;
    buffers: [2][pixelsCapacity]Color,
    frontIndex: usize,
    w: usize,
    h: usize,

    pub fn init(self: *PixelBuffers, nW: usize, nH: usize) void {
        self.*.frontIndex = 1;
        self.*.w = nW;
        self.*.h = nH;
        var y: usize = 0;
        while (y < nH) {
            var x: usize = 0;
            while (x < nW) {
                self.*.buffers[0][x + nW * y] = Color.black();
                self.*.buffers[1][x + nW * y] = Color.black();
                x += 1;
            }
            y += 1;
        }
    }

    pub fn clearFront(self: *PixelBuffers, c: Color) void {
        var y: usize = 0;
        while (y < self.h) {
            var x: usize = 0;
            while (x < self.w) {
                self.*.buffers[self.*.frontIndex][x + self.w * y] = c;
                x += 1;
            }
            y += 1;
        }
    }

    pub inline fn write(self: *PixelBuffers, x: c_int, y: c_int, color: Color) void {
        if (x >= 0 and y >= 0 and x < @intCast(c_int, self.w) and y < @intCast(c_int, self.h)) {
            const ux = @intCast(usize, x);
            const uy = @intCast(usize, y);
            self.*.buffers[self.frontIndex][ux + self.*.w * uy] = color;
        }
    }

    pub fn drawThickLine(self: *PixelBuffers, xFrom: c_int, yFrom: c_int, xTo: c_int, yTo: c_int, color: Color, thickness: f64) void {
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
            .x = @intToFloat(f64, xTo - xFrom),
            .y = @intToFloat(f64, yTo - yFrom),
        };

        var iy: c_int = Y0;
        while (iy <= Y1) {
            const y: f64 = @intToFloat(f64, iy);
            var ix: c_int = X0;
            while (ix <= X1) {
                const x: f64 = @intToFloat(f64, ix);
                const v = Vec2{
                    .x = x - @intToFloat(f64, xFrom),
                    .y = y - @intToFloat(f64, yFrom),
                };
                const h1 = dot(v, v);
                const c1 = dot(norm(v01), v) * dot(norm(v01), v);
                const distToLine2: f64 = h1 - c1;
                assert(distToLine2 > -0.001);
                if (distToLine2 < thickness2) {
                    self.write(ix, iy, color);
                }
                ix += 1;
            }
            iy += 1;
        }
    }

    pub fn drawLine(self: *PixelBuffers, xFrom: c_int, yFrom: c_int, xTo: c_int, yTo: c_int, color: Color) void {
        if (xFrom == xTo and yFrom == yTo) {
            self.write(xFrom, yFrom, color);
        }
        var x0: c_int = undefined;
        var x1: c_int = undefined;
        var y0: c_int = undefined;
        var y1: c_int = undefined;
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
            var y: c_int = y0;
            while (y <= y1) {
                const inc = @divFloor((x1 - x0 + 1) * (y - y0), y1 - y0 + 1);
                const x = block: {
                    if (invX == invY) {
                        break :block x0 + inc;
                    } else {
                        break :block x1 - inc;
                    }
                };
                write(self, x, y, color);
                y += 1;
            }
        } else {
            var x: c_int = x0;
            while (x <= x1) {
                const inc = @divFloor((y1 - y0 + 1) * (x - x0), x1 - x0 + 1);
                const y = block: {
                    if (invX == invY) {
                        break :block y0 + inc;
                    } else {
                        break :block y1 - inc;
                    }
                };
                write(self, x, y, color);
                x += 1;
            }
        }
    }

    pub fn resize(self: *PixelBuffers, nW: usize, nH: usize) void {
        const front = self.*.frontIndex;
        const back = front ^ 1;
        var y: usize = 0;
        while (y < nH) {
            var x: usize = 0;
            while (x < nW) {
                self.*.buffers[back][x + nW * y] = Color.white();
                x += 1;
            }
            y += 1;
        }

        y = 0;
        while (y < std.math.min(self.*.h, nH)) {
            var x: usize = 0;
            while (x < std.math.min(self.*.w, nW)) {
                self.*.buffers[back][x + nW * y] = self.*.buffers[front][x + self.*.w * y];
                x += 1;
            }
            y += 1;
        }

        self.*.w = nW;
        self.*.h = nH;

        self.swapBuffers();
    }

    fn swapBuffers(self: *PixelBuffers) void {
        self.*.frontIndex = self.*.frontIndex ^ 1;
    }

    pub inline fn bufferStart(self: *PixelBuffers) *u8 {
        return &self.*.buffers[self.frontIndex][0].color[0];
    }

    pub inline fn bufferLineSize(self: *PixelBuffers) usize {
        return self.w * @sizeOf(u32);
    }
};

const Bounds = struct {
    min: Vec4f,
    max: Vec4f,

    pub fn init(min: Vec4f, max: Vec4f) Bounds {
        return Bounds{
            .min = min,
            .max = max,
        };
    }

    pub fn add(self: *Bounds, point: Vec4f) void {
        if (point.x < self.min.x)
            self.min.x = point.x;

        if (point.y < self.min.y)
            self.min.y = point.y;

        if (point.z < self.min.z)
            self.min.z = point.z;

        if (point.w < self.min.w)
            self.min.w = point.w;

        if (point.x > self.max.x)
            self.max.x = point.x;

        if (point.y > self.max.y)
            self.max.y = point.y;

        if (point.z > self.max.z)
            self.max.z = point.z;

        if (point.w > self.max.w)
            self.max.w = point.w;
    }

    pub fn limit(self: *Bounds, l: Bounds) void {
        if (self.min.x < l.min.x)
            self.min.x = l.min.x;

        if (self.min.y < l.min.y)
            self.min.y = l.min.y;

        if (self.min.z < l.min.z)
            self.min.z = l.min.z;

        if (self.min.w < l.min.w)
            self.min.w = l.min.w;

        if (self.max.x > l.max.x)
            self.max.x = l.max.x;

        if (self.max.y > l.max.y)
            self.max.y = l.max.y;

        if (self.max.z > l.max.z)
            self.max.z = l.max.z;

        if (self.max.w > l.max.w)
            self.max.w = l.max.w;
    }
};

var pixels: PixelBuffers = undefined;
var profile: ?*Profile = undefined;

pub fn drawLine(xFrom: c_int, yFrom: c_int, xTo: c_int, yTo: c_int, color: Color) void {
  pixels.drawLine(xFrom, yFrom, xTo, yTo, color);
}

pub fn bufferStart() *u8 {
    return pixels.bufferStart();
}

pub fn bufferLineSize() usize {
    return pixels.bufferLineSize();
}

pub fn init(renderWidth: u16, renderHeight: u16, profileContext:?*Profile) !void {
    profile = profileContext;
    pixels.init(renderWidth, renderHeight);
}

pub fn drawMesh(mvp: *const Mat44f, mesh: *Mesh) void {
    // var sp = profile.?.beginSample("drawMesh");
    // defer profile.?.endSample(sp);

    const ids = mesh.indexBuffer.len;
    const numTris = ids / 3;

    var t: u16 = 0;
    while (t < ids) {
        drawTri(mvp, t, mesh);
        t += 3;
    }
}

pub fn drawPointMesh(mvp: *const Mat44f, mesh: *Mesh) void {
    const ids = mesh.vertexBuffer.len;

    for (mesh.vertexBuffer) |vertex, i| {
        drawPoint(mvp, vertex, mesh.colorBuffer[i]);
    }
}

pub fn triEdge(a: Vec4f, b: Vec4f, c: Vec4f) f32 {
    return (c.x - a.x) * (b.y - a.y) - (c.y - a.y) * (b.x - a.x);
}

pub fn applyVertexShader(mvp: *const Mat44f, index: u16, v: Vec4f) Vec4f {
    var out = mvp.mul33(v);
    const hW = @intToFloat(f32, pixels.w) / 2;
    const hH = @intToFloat(f32, pixels.h) / 2;

    // center in viewport
    out.x = hW * out.x + hW;
    out.y = hH * -out.y + hH;
    return out;
}

///
pub fn applyPixelShader(mvp: *const Mat44f, pixel: Vec4f, color: Vec4f) Vec4f {
    return color;
}

pub fn drawPoint(mvp: *const Mat44f, point: Vec4f, color: Vec4f) void {
    const px = applyVertexShader(mvp, 0, point);
    const pc = applyPixelShader(mvp, px, color);

    const c = Color.init(@floatToInt(u8, pc.x * 255), @floatToInt(u8, pc.y * 255), @floatToInt(u8, pc.z * 255), @floatToInt(u8, pc.w * 255));

    writePixel(@floatToInt(i16, px.x), @floatToInt(i16, px.y), c);
}

/// Render triangle to frame buffer
pub fn drawTri(mvp: *const Mat44f, offset: u16, mesh: *Mesh) void {
    // var sp = profile.?.beginSample("drawTri");
    // defer profile.?.endSample(sp);

    const rv0 = mesh.vertexBuffer[mesh.indexBuffer[offset + 0]];
    const rv1 = mesh.vertexBuffer[mesh.indexBuffer[offset + 1]];
    const rv2 = mesh.vertexBuffer[mesh.indexBuffer[offset + 2]];

    const v0 = applyVertexShader(mvp, offset + 0, rv0);
    const v1 = applyVertexShader(mvp, offset + 1, rv1);
    const v2 = applyVertexShader(mvp, offset + 2, rv2);

    const c0 = mesh.colorBuffer[mesh.indexBuffer[offset + 0]];
    const c1 = mesh.colorBuffer[mesh.indexBuffer[offset + 1]];
    const c2 = mesh.colorBuffer[mesh.indexBuffer[offset + 2]];

    const area = triEdge(v0, v1, v2);

    if (area <= 0)
        return;

    const renderBounds = Bounds.init(
      Vec4f.init(0, 0, 0, 0), 
      Vec4f.init(
        @intToFloat(f32, pixels.w), 
        @intToFloat(f32, pixels.h), 
        0, 0)
      );

    var bounds = Bounds.init(v0, v0);
    bounds.add(v0);
    bounds.add(v1);
    bounds.add(v2);
    bounds.limit(renderBounds);

    var subsamples: u16 =1;
    var stepDist: f32 = 1.0 / @intToFloat(f32, subsamples * subsamples);

    // iterate triangle bounding box drawing all pixels inside the triangle
    // TODO: iterate tri edge vertically rendering scan lines to the opposite edge
    var y = bounds.min.y;
    var p: Vec4f = Vec4f.init(0, 0, 0, 0);
    var fbc: Vec4f = Vec4f.init(0, 0, 0, 0);
    var c: Color = Color.black();

    while (y <= bounds.max.y) {
        var x = bounds.min.x;
        defer y += 1;

        while (x <= bounds.max.x) {
            defer x += 1;

            var sx: f32 = 0;
            var sy: f32 = 0;
            var vc: Vec4f = Vec4f.init(0, 0, 0, 0);

            p.x = x; // sub sampling
            p.y = y; // sub sampling

            while (@floatToInt(u32, sy) < subsamples) {
                defer sy += 1;

                while (@floatToInt(u32, sx) < subsamples) {
                    defer sx += 1;

                    

                    p.x = x + stepDist * (sx + 1); // sub sampling
                    p.y = y + stepDist * (sy + 1); // sub sampling

                    var w0 = triEdge(v1, v2, p);
                    var w1 = triEdge(v2, v0, p);
                    var w2 = triEdge(v0, v1, p);

                    // TODO: near plane clipping

                    if (w0 < 0 or w1 < 0 or w2 < 0)
                        continue;

                    // var spp = profile.?.beginSample("samplePixel");
                    // defer profile.?.endSample(spp);
                 
                    w0 /= area;
                    w1 /= area;
                    w2 /= area;

                    // if we use perspective correct interpolation we need to
                    // multiply the result of this interpolation by z, the depth
                    // of the point on the 3D triangle that the pixel overlaps.
                    const z = 1 / (w0 * v0.z + w1 * v1.z + w2 * v2.z);

                    // interpolate vertex colors across all pixels
                    fbc.x = (w0 * c0.x + w1 * c1.x + w2 * c2.x) * z;
                    fbc.y = (w0 * c0.y + w1 * c1.y + w2 * c2.y) * z;
                    fbc.z = (w0 * c0.z + w1 * c1.z + w2 * c2.z) * z;
                    fbc.w = 1.0;

                    vc.add(applyPixelShader(mvp, p, fbc));
                }
            }

            if(vc.w <= 0.0)
              continue;
            
            vc.normalize();
            vc.scale(255);

            c.setR(@floatToInt(u8, @fabs(vc.x)));
            c.setG(@floatToInt(u8, @fabs(vc.y)));
            c.setB(@floatToInt(u8, @fabs(vc.z)));
            c.setA(@floatToInt(u8, @fabs(vc.w)));

            writePixel(@floatToInt(i16, x), @floatToInt(i16, y), c);
        }
    }
}

pub fn writePixel(x: i16, y: i16, c: Color) void {
    pixels.write(x, y, c);
}

pub fn beginFrame() *u8 {
    pixels.clearFront(Color.black());
    return pixels.bufferStart();
}

pub fn endFrame() void {
    pixels.swapBuffers();
}

pub fn shutdown() void {}
