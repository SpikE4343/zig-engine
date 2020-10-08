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

const Mesh = @import("mesh.zig").Mesh;
const pixelbuffer = @import("pixel_buffer.zig");
const PixelBuffer = pixelbuffer.PixelBuffer;
const PixelRenderer = pixelbuffer.PixelRenderer;

pub const material = @import("material.zig");
pub const Material = material.Material;

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

    pub fn topLeftHandLimit(self:*Bounds) void {
        self.min.sub(Vec4f.half());
        self.min.ceil();

        self.max.sub(Vec4f.half());
        self.max.ceil();
    }
};

var colorBuffer: PixelBuffer(Color) = undefined;
var depthBuffer: PixelBuffer(f32) = undefined;

var profile: ?*Profile = undefined;
var allocator: *std.mem.Allocator = undefined;
var colorRenderer:PixelRenderer(Color) = undefined;

pub fn drawLine(xFrom: i32, yFrom: i32, xTo: i32, yTo: i32, color: Color) void {
  colorRenderer.drawLine(xFrom, yFrom, xTo, yTo, color);
}

pub fn bufferStart() *u8 {
    return &colorBuffer.bufferStart().color[0];
}

pub fn bufferLineSize() usize {
    return colorBuffer.bufferLineSize();
}

pub fn init(renderWidth: u16, renderHeight: u16, alloc: *std.mem.Allocator, profileContext:?*Profile) !void {
    profile = profileContext;
    allocator = alloc;
    colorBuffer = try PixelBuffer(Color).init(renderWidth, renderHeight, allocator);
    depthBuffer = try PixelBuffer(f32).init(renderWidth, renderHeight, allocator);
    colorRenderer = PixelRenderer(Color).init(&colorBuffer);
}

pub fn drawMesh(m: *const Mat44f, v: *const Mat44f, p: *const Mat44f, mesh: *Mesh, shader: *Material) void {
    var sp = profile.?.beginSample("render.mesh.draw");
    defer profile.?.endSample(sp);

    var mv = m.*;
    mv.mul(v.*);

    var mvp = p.*;
    mvp.mul(v.*);
    mvp.mul(m.*);

    const ids = mesh.indexBuffer.len;
    const numTris = ids / 3;

    var t: u16 = 0;
    while (t < ids) {
        drawTri(m, v, p, &mv, &mvp, t, mesh, shader);
        t += 3;
    }
}

pub fn drawPointMesh(mvp: *const Mat44f, mesh: *Mesh, shader:*Material) void {
    const ids = mesh.vertexBuffer.len;

    for (mesh.vertexBuffer) |vertex, i| {
        drawPoint(mvp, vertex, mesh.colorBuffer[i]);
    }
}

//
pub fn drawPoint(mvp: *const Mat44f, point: Vec4f, color: Vec4f) void {
    const px = applyVertexShader(mvp, 0, point);
    const pc = color;

    const c = Color.init(@floatToInt(u8, pc.x * 255), @floatToInt(u8, pc.y * 255), @floatToInt(u8, pc.z * 255), @floatToInt(u8, pc.w * 255));

    if( px.x >=0 and px.x <= 1000 and px.y >=0 and px.y <= 1000)
        writePixel(@floatToInt(i32, px.x), @floatToInt(i32, px.y), c);
}

///
pub fn drawWorldLine(mvp: *const Mat44f, start: Vec4f, end: Vec4f, color: Vec4f) void {
    const spx = applyVertexShader(mvp, 0, start);
    const epx = applyVertexShader(mvp, 0, end);
    const pc = color;

    const c = Color.init(@floatToInt(u8, pc.x * 255), @floatToInt(u8, pc.y * 255), @floatToInt(u8, pc.z * 255), @floatToInt(u8, pc.w * 255));

    if( spx.x >=0 and spx.x <= 1000 and spx.y >=0 and spx.y <= 1000 and
        epx.x >=0 and epx.x <= 1000 and epx.y >=0 and epx.y <= 1000)
        drawLine(
            @floatToInt(i32, spx.x), @floatToInt(i32, spx.y), 
            @floatToInt(i32, epx.x), @floatToInt(i32, epx.y), 
            c);
}


/// Render triangle to frame buffer
pub fn drawTri(
  model: *const Mat44f, 
  view: *const Mat44f, 
  proj: *const Mat44f, 
  mv: *const Mat44f, 
  mvp: *const Mat44f, 
  offset: u16, 
  mesh: *Mesh,
  shader: *Material) void {
    

    var vp = view.*;
    vp.mul(proj.*);

    const vi0 = mesh.indexBuffer[offset + 0];
    const vi1 = mesh.indexBuffer[offset + 1];
    const vi2 = mesh.indexBuffer[offset + 2];

    const rv0 = mesh.vertexBuffer[vi0];
    const rv1 = mesh.vertexBuffer[vi1];
    const rv2 = mesh.vertexBuffer[vi2];

    // cull back facing triangles
    const mv0 = mv.mul33_vec4(rv0);
    const mv1 = mv.mul33_vec4(rv1);
    const mv2 = mv.mul33_vec4(rv2);
    
    var e0 = mv1;
    var e1 = mv2;
    
    e0.sub(mv0);// cull back facing triangles
    e1.sub(mv0);

    const triNormal = e0.cross3(e1).normalized3();

    
    const bfc = mv0.normalized3().dot3(triNormal);
    if( bfc > 0.0000000000001)
        return;

    const viewport = Vec4f.init(
        @intToFloat(f32, colorBuffer.w), 
        @intToFloat(f32, colorBuffer.h), 
        0, 0);

    const v0 = shader.projectionShader(proj, shader.vertexShader(mv, offset + 0, rv0, shader), viewport, shader);
    const v1 = shader.projectionShader(proj, shader.vertexShader(mv, offset + 1, rv1, shader), viewport, shader);
    const v2 = shader.projectionShader(proj, shader.vertexShader(mv, offset + 2, rv2, shader), viewport, shader);

    
    const area = Vec4f.triArea(v0, v1, v2);

    if (area <= 0)
        return;

    // TODO: clipping
    if( v0.z <= 0.1 or v1.z <= 0.1 or v2.z <= 0.1)
        return;

    var sp = profile.?.beginSample("render.mesh.draw.tri");
    defer profile.?.endSample(sp);

    const wv0 = model.mul_vec4(rv0);
    const wv1 = model.mul_vec4(rv1);
    const wv2 = model.mul_vec4(rv2);

    const c0 = Vec4f.zero();//rv0.scaleDup(0.5);//Vec4f.init(rv0.x,0,0,1); // mesh.vertexNormalBuffer[vi0];
    const c1 = Vec4f.zero();//rv1.scaleDup(0.5);//Vec4f.init(0,rv0.y,0,1); // mesh.vertexNormalBuffer[vi1];//mesh.colorBuffer[mesh.indexBuffer[offset + 1]];
    const c2 = Vec4f.zero();//rv2.scaleDup(0.5);//Vec4f.init(0,0,rv0.z,1); // mesh.vertexNormalBuffer[vi2];//mesh.colorBuffer[mesh.indexBuffer[offset + 2]];

    var we0 = wv1;
    var we1 = wv2;
    
    we0.sub(wv0);
    we1.sub(wv0);

    const worldNormalTri = we0.cross3(we1).normalized3();

    const n0 = mesh.vertexNormalBuffer[mesh.indexNormalBuffer[offset + 0]];
    const n1 = mesh.vertexNormalBuffer[mesh.indexNormalBuffer[offset + 1]];
    const n2 = mesh.vertexNormalBuffer[mesh.indexNormalBuffer[offset + 2]];

    const uv0 = Vec4f.init(
      mesh.textureCoordBuffer[mesh.indexUVBuffer[(offset+0)]*2 + 0],
      mesh.textureCoordBuffer[mesh.indexUVBuffer[(offset+0)]*2 + 1],
      0, 0);

    const uv1 = Vec4f.init(
      mesh.textureCoordBuffer[mesh.indexUVBuffer[(offset+1)]*2 + 0],
      mesh.textureCoordBuffer[mesh.indexUVBuffer[(offset+1)]*2 + 1],
      0, 0);

    const uv2 = Vec4f.init(
      mesh.textureCoordBuffer[mesh.indexUVBuffer[(offset+2)]*2 + 0],
      mesh.textureCoordBuffer[mesh.indexUVBuffer[(offset+2)]*2 + 1],
      0, 0);

    const wn0 = model.mul33_vec4(n0);
    const wn1 = model.mul33_vec4(n1);
    const wn2 = model.mul33_vec4(n2);

    

    const renderBounds = Bounds.init(Vec4f.zero(), viewport);

    var bounds = Bounds.init(v0, v0);
    bounds.add(v0);
    bounds.add(v1);
    bounds.add(v2);
    bounds.limit(renderBounds);
    bounds.topLeftHandLimit();


    // var subsamples: u16 =1;
    // var stepDist: f32 = 1.0 / @intToFloat(f32, math.max(2, subsamples));

    // iterate triangle bounding box drawing all pixels inside the triangle
    // TODO: iterate tri edge vertically rendering scan lines to the opposite edge
    var y = bounds.min.y;
    var p: Vec4f = Vec4f.init(0, 0, 0, 0);
    var worldPixel: Vec4f = Vec4f.init(0, 0, 0, 0);
    var pixelNormal:Vec4f = Vec4f.init(0, 0, 0, 0);
    var fbc: Vec4f = Vec4f.init(0, 0, 0, 1);
    var uv: Vec4f = Vec4f.init(0, 0, 0, 1);
    var c: Color = Color.black();
    
    
    
    while (y <= bounds.max.y) 
    {
        var x = bounds.min.x;
        defer y += 1;

        while (x <= bounds.max.x) 
        {
            var pprof = profile.?.beginSample("render.mesh.draw.tri.pixel");
            defer profile.?.endSample(pprof);

            defer x += 1;

            p.x = x; 
            p.y = y; 
            
            var tri = Vec4f.triCoords(v0,v1,v2, p);

            // TODO: near plane clipping
            if (tri.x < 0 or tri.y < 0 or tri.z < 0)
                continue;
            
            tri.div3(area);

            // if we use perspective correct interpolation we need to
            // multiply the result of this interpolation by z, the depth
            // of the point on the 3D triangle that the pixel overlaps.
            const z =(tri.x * v0.z + tri.y * v1.z + tri.z * v2.z);

            if (shader.depthTest == 1 and depthBuffer.setLessThan(@floatToInt(i32, x), @floatToInt(i32, y), z) == 0)
                continue;

            p.z = z;

            var pdprof = profile.?.beginSample("render.mesh.draw.tri.pixel.draw");
            defer profile.?.endSample(pdprof);

            // interpolate vertex colors across all pixels
            fbc = Vec4f.triInterp(tri, c0, c1, c2, 1.0, 1.0);
            pixelNormal = Vec4f.triInterp(tri, wn0, wn1, wn2, 1.0, 1.0);
            uv = Vec4f.triInterp(tri, uv0, uv1, uv2, 1.0, 1.0);

            var vc = shader.pixelShader(mvp, p, fbc, pixelNormal, uv, shader);

            if(vc.w <= 0.0)
              continue;
            
            vc.clamp01();
            vc.scale(255);

            c.setR(@floatToInt(u8, @fabs(vc.x)));
            c.setG(@floatToInt(u8, @fabs(vc.y)));
            c.setB(@floatToInt(u8, @fabs(vc.z)));
            c.setA(@floatToInt(u8, @fabs(vc.w)));

            writePixel(@floatToInt(i32, x), @floatToInt(i32, y), z, c);
        }
    }

   

    // var center = mv0.addDup(mv1);
    // center.add(mv2);
    // center.div(3);

    // // drawWorldLine(mvp, de0, rv0, Vec4f.init(0,1,0,1));
    // // drawWorldLine(mvp, rv0, de1, Vec4f.init(0,0,1,0));

    // //drawWorldLine()
    // drawWorldLine(proj, center, center.addDup(triNormal), Vec4f.init(0,0,1,1));
    
    // drawWorldLine(mvp, rv0, rv0.addDup(n0), Vec4f.init(1,0,0,1));

    // drawWorldLine(mvp, rv1, rv1.addDup(n1), Vec4f.init(0,1,0,1));

    // drawWorldLine(mvp, rv2, rv2.addDup(n2), Vec4f.init(0,0,1,1));
}

pub fn drawProgress(x:i16, y:i16, max_width:f32, value:f32, max_value:f32) void {
  const cs = std.math.clamp(value, 0.0, max_value)/max_value;
  const cs2 = cs*cs;
  drawLine(
    x,y,
    @floatToInt(c_int, cs*max_width), 
    y, 
    Color.fromNormal(cs, (1-cs), 0.2, 1)
  );
}

pub fn writePixel(x: i32, y: i32, z: f32, c: Color) void {
    colorBuffer.write(x, y, c);
    depthBuffer.write(x, y, z);
}

pub fn beginFrame() *u8 {
    var pprof = profile.?.beginSample("render.beginFrame");
    defer profile.?.endSample(pprof);

    colorBuffer.clear(Color.black());
    depthBuffer.clear(std.math.inf(f32));
    return &colorBuffer.bufferStart().color[0];
}

pub fn endFrame() void {
    //pixels.swapBuffers();
}

pub fn shutdown() void {
  colorBuffer.deinit();
  depthBuffer.deinit();
}
