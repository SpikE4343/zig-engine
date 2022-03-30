// compile in ubuntu:
// $ zig build-exe paint.zig --library SDL2 --library SDL2main --library c -isystem "/usr/include" --library-path "/usr/lib/x86_64-linux-gnu"

const std = @import("std");
const warn = std.debug.print;
const fmt = std.fmt;
const assert = @import("std").debug.assert;
const math = std.math;

const Vec4f = @import("../core/vector.zig").Vec4f;
const Mat44f = @import("../core/matrix.zig").Mat44f;

const Profile = @import("../core/profiler.zig").Profile;
pub const Font = @import("font.zig").Font;

const Mesh = @import("mesh.zig").Mesh;
const pixelbuffer = @import("pixel_buffer.zig");
const PixelBuffer = pixelbuffer.PixelBuffer;
const PixelRenderer = pixelbuffer.PixelRenderer;

const jobs = @import("../core/job.zig");
const Job = jobs.Job;
const JobWorker = jobs.Worker;
const JobQueue = jobs.Queue;
const JobRunner = jobs.Runner;
const JobPool = jobs.Pool;

pub const material = @import("material.zig");
pub const Material = material.Material;

const tracy = @import("../tracy.zig");
const trace = tracy.trace;

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

    pub fn fromNormal(cr: f32, cg: f32, cb: f32, ca: f32) Color {
        return Color.init(@floatToInt(u8, cr * 255), @floatToInt(u8, cg * 255), @floatToInt(u8, cb * 255), @floatToInt(u8, ca * 255));
    }

    pub fn fromNormalVec4f(vec:Vec4f) Color {
        return Color.fromNormal( vec.x, vec.y, vec.z, vec.w);
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

    pub fn topLeftHandLimit(self: *Bounds) void {
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
var colorRenderer: PixelRenderer(Color) = undefined;

pub const Stats = struct {
    const Self = @This();
    

    totalMeshes: u32=0,
    totalTris: u32=0,
    totalPixels: u32=0,

    renderedMeshes: u32=0,
    renderedTris: u32=0,
    renderedPixels: u32=0,

    trisTooSmall:u32=0,
    trisTooNear:u32=0,
    trisBackfacing:u32=0,
    jobWaitCount:u32=0,
    jobCount:u32=0,

    pub fn init() Self {
        return Self {
            .totalMeshes = 0,
            .totalTris = 0,
            .totalPixels = 0,
            .renderedMeshes = 0,
            .renderedTris = 0,
            .renderedPixels = 0,
            .trisTooSmall = 0,
            .trisTooNear = 0,
            .trisBackfacing = 0,
            .jobWaitCount = 0,
            .jobCount=0,
        };
    }

    pub fn reset(self: *Self) void {
        const ti = @typeInfo(Self);
        inline for (ti.Struct.fields) |field| {
            @field(self, field.name) = field.default_value orelse 0;
        } 
    }

    pub fn trace(self:Stats) void {
        const ti = @typeInfo(Stats);
        inline for (ti.Struct.fields) |field| {
            tracy.plotValue(field.name.ptr, @field(self, field.name));
        }     
    }

    pub fn print(self: *Self) void {
        std.debug.print(" [ m({}, {}|{d:.2}%), t({}, {}|{d:.2}%, <{d}, |<{d}, bf{d}), p({}, {}|{d:.2}%) ]\n", .{
            self.renderedMeshes,
            self.totalMeshes,
            @intToFloat(f32, self.renderedMeshes) / @intToFloat(f32, self.totalMeshes) * 100.0,

            self.renderedTris,
            self.totalTris,
            @intToFloat(f32, self.renderedTris) / @intToFloat(f32, self.totalTris) * 100.0,
            self.trisTooSmall,
            self.trisTooNear,
            self.trisBackfacing,

            self.renderedPixels,
            self.totalPixels,
            @intToFloat(f32, self.renderedPixels) / @intToFloat(f32, self.totalPixels) * 100.0,
        });
    }
};

pub const MeshRenderData = struct {
    model: *const Mat44f,
    view: *const Mat44f,
    proj: *const Mat44f,
    mv: Mat44f,
    vp:Mat44f,
    mvp: Mat44f,
    offset: u16,
    mesh: *Mesh,
    shader: *Material,
};

pub const TriRenderData = struct {
    pub const Visible = 1 << 0;
    pub const TooSmall = 1 << 1;

    id:u32,
    offset: u16,

    meshData:MeshRenderData,

    indicies:[3]u16,
    
    color:[3]Vec4f,
    uv:[3]Vec4f,
    normals:[3]Vec4f,
    worldNormals:[3]Vec4f,

    rawVertex:[3]Vec4f,

    // transformed and projected verticies
    screenVertex:[3]Vec4f, // Projection * Model * View
    cameraVertex:[3]Vec4f, // Model * View
    worldVertex:[3]Vec4f, // Model

    normal: Vec4f,
    edges: [3]Vec4f,
    screenArea: f32,
    flags: u32,
    backfacing: bool,

    screenBounds:Bounds,
};

const TriSpanData = struct {
    triData: *TriRenderData,
};

pub fn RenderJob(comptime TDataType: type, execFunc: fn (data: *TDataType) void) type {
    const RenderExecuteFunc = @TypeOf(execFunc);
    return struct {
        const Self = @This();
        const func:RenderExecuteFunc=execFunc;

        job: Job,
        complete: bool = false,
        data: TDataType,

        pub fn init() Self {
            return Self{
               .job = Job{
                    .executeFn = execute,
                    .abortFn = abort,
                    .next = null,
                },
                .data = undefined,
                .complete = false,
            };
        }

        fn execute(job: *Job) Job.Error!Job.Result {
            const self = job.implementor(Self, "job");

            Self.func(&self.data);
            self.complete = true;
            //std.debug.warn("\t job: {}:{} execution!\n", .{self.id, self.complete});
            return Job.Result.Complete;
        }

        fn abort(job: *Job) Job.Error!void {
            _ = job.implementor(Self, "job");
        }
    };
}

const MeshRenderJob = RenderJob(MeshRenderData, drawMeshJob);
const TriRenderJob  = RenderJob(TriRenderData,  drawTriJob);
const SpanRenderJob = RenderJob(TriSpanData,    drawTriSpanJob);


var meshJobs: JobPool(MeshRenderJob) = undefined;
var triJobs: JobPool(TriRenderJob) = undefined;
var spanJobs: JobPool(SpanRenderJob) = undefined;

var renderQueue = JobRunner.init();
var renderWorkers: jobs.WorkerPool = undefined;
var stats = Stats.init();
var viewport = Vec4f.zero();
var renderBounds:Bounds = undefined;

pub fn frameStats() Stats {
    return stats;
}

pub fn drawLine(xFrom: i32, yFrom: i32, xTo: i32, yTo: i32, color: Color) void {
    const zone = trace(@src());
    defer zone.end();
    colorRenderer.drawLine(xFrom, yFrom, xTo, yTo, color);
}

pub fn bufferStart() *u8 {
    return &colorBuffer.bufferStart().color[0];
}

pub fn bufferLineSize() usize {
    return colorBuffer.bufferLineSize();
}

pub fn getViewport() Vec4f {
    return viewport;
}

pub fn init(renderWidth: u16, renderHeight: u16, alloc: *std.mem.Allocator, profileContext: ?*Profile) !void {
    profile = profileContext;
    allocator = alloc;

    colorBuffer = try PixelBuffer(Color).init(renderWidth, renderHeight, allocator);
    depthBuffer = try PixelBuffer(f32).init(renderWidth, renderHeight, allocator);
    colorRenderer = PixelRenderer(Color).init(&colorBuffer);

    renderBounds = Bounds.init(Vec4f.zero(), viewport);
    viewport = Vec4f.init(@intToFloat(f32, colorBuffer.w), @intToFloat(f32, colorBuffer.h), 0, 0);

    meshJobs = try JobPool(MeshRenderJob).init(alloc.*, 16);
    triJobs = try JobPool(TriRenderJob).init(alloc.*, 4 * 1024);
    spanJobs = try JobPool(SpanRenderJob).init(alloc.*, 1024);

    renderWorkers = try jobs.WorkerPool.init(&renderQueue, alloc, @intCast(u8, try std.Thread.getCpuCount()) >> 1);
    try renderWorkers.start();

}

pub fn drawMesh(m: *const Mat44f, v: *const Mat44f, p: *const Mat44f, mesh: *Mesh, shader: *Material) void {
    const zone = trace(@src());
    defer zone.end();

    var job = meshJobs.getItem();

    job.* = MeshRenderJob.init();

    job.data.mesh = mesh;
    job.data.model = m;
    job.data.view = v;
    job.data.proj = p;
    job.data.shader = shader;

    // Model * View
    var mv = m.*;
    mv.mul(v.*);
    job.data.mv = mv;

    // View * projection
    var vp = p.*;
    vp.mul(v.*);

    // Projection * Model * View
    var mvp = p.*;
    mvp.mul(v.*);
    mvp.mul(m.*);
    job.data.mvp = mvp;

    renderQueue.pending.push(&job.job);
}

fn drawMeshJob(meshJob:*MeshRenderData) void {
    const zone = trace(@src());
    defer zone.end();

    var t: u16 = 0;
    const ids = meshJob.mesh.indexBuffer.len;

    _ = @atomicRmw(u32, &stats.totalMeshes, .Add, 1, .SeqCst);

    while (t < ids/3) {
        const zone1 = trace(@src());
        defer zone1.end();

        var job = triJobs.getItem();
        job.* = TriRenderJob.init();
        job.data.id = @truncate(u16, t);
        job.data.offset = t*3;
        job.data.meshData = meshJob.*;
        job.complete = false;
        renderQueue.pending.push(&job.job);
        t+=1;
    }

    _ = @atomicRmw(u32, &stats.renderedMeshes, .Add, 1, .SeqCst);
}

fn getTriangleNormal(points:[3]Vec4f) Vec4f {
    var e0 = points[1];
    var e1 = points[2];

    e0.sub(points[0]);
    e1.sub(points[0]);

    return e0.cross3(e1).normalized3();
}

fn drawTriJob(triJob: *TriRenderData) void {
    const zone = trace(@src());
    defer zone.end();

    var tri=triJob;
    const data = tri.meshData;
    const mesh = data.mesh;
    const shader = data.shader;
    // var sortedByY:[3]u8 = .{};

    _ = @atomicRmw(u32, &stats.totalTris, .Add, 1, .SeqCst);

    comptime var p = 0;
    inline while(p < 3)
    {
        var offset = tri.offset + p;
        assert(offset < mesh.indexBuffer.len);
        tri.indicies[p] = mesh.indexBuffer[offset];
        tri.rawVertex[p] = mesh.vertexBuffer[tri.indicies[p]];
        
        tri.cameraVertex[p] = data.mv.mul33_vec4(tri.rawVertex[p]);
        tri.screenVertex[p] = shader.projectionShader(
            data.proj, 
            shader.vertexShader(&data.mv, offset, tri.rawVertex[p], shader), 
            viewport, 
            shader
            );

        tri.normals[p] = mesh.vertexNormalBuffer[mesh.indexNormalBuffer[offset]];
        tri.worldNormals[p] = data.model.mul33_vec4(tri.normals[p]);
        tri.uv[p] = Vec4f.init(
            mesh.textureCoordBuffer[mesh.indexUVBuffer[(offset)] * 2 + 0], 
            mesh.textureCoordBuffer[mesh.indexUVBuffer[(offset)] * 2 + 1], 
            0, 0);

        tri.worldVertex[p] = data.model.mul_vec4(tri.rawVertex[p]);

        const indexScalar = @intToFloat(f32, offset) / @intToFloat(f32, mesh.indexBuffer.len);
        tri.color[p] = Vec4f.init(0.4, 0.7, 0.5, 1.0).scale3Dup(indexScalar);//mesh.colorBuffer[tri.indicies[p]];

        p+=1;
    }
    
    tri.normal = getTriangleNormal(tri.cameraVertex);
    tri.backfacing = tri.cameraVertex[0].normalized3().dot3(tri.normal) > 0.0000000000001;
    tri.screenArea = Vec4f.triArea(tri.screenVertex[0], tri.screenVertex[1], tri.screenVertex[2]);
    tri.screenBounds = Bounds.init(tri.screenVertex[0], tri.screenVertex[0]);

    if(tri.backfacing)
    {
        _ = @atomicRmw(u32, &stats.trisBackfacing, .Add, 1, .SeqCst);
        return;
    }

    p=0;
    inline while(p < 3)
    {
        tri.screenBounds.add(tri.screenVertex[p]);
        p+=1;
    }

    tri.screenBounds.limit(renderBounds);
    tri.screenBounds.topLeftHandLimit();
    
    
    // Too small to see
    if (tri.screenArea <= 0)
    {
        _ = @atomicRmw(u32, &stats.trisTooSmall, .Add, 1, .SeqCst);
        return;
    }

    for( tri.screenVertex ) |v| {
        if( v.z <= 0.1)
        {
            _ = @atomicRmw(u32, &stats.trisTooNear, .Add, 1, .SeqCst); 
            return;
        }
    }

    
    
    drawLine(
        @floatToInt(i32, tri.screenVertex[0].x), 
        @floatToInt(i32, tri.screenVertex[0].y), 
        @floatToInt(i32, tri.screenVertex[1].x), 
        @floatToInt(i32, tri.screenVertex[1].y), Color.fromNormalVec4f(tri.color[0]));


    drawLine(
        @floatToInt(i32, tri.screenVertex[1].x), 
        @floatToInt(i32, tri.screenVertex[1].y), 
        @floatToInt(i32, tri.screenVertex[2].x), 
        @floatToInt(i32, tri.screenVertex[2].y), Color.fromNormalVec4f(tri.color[1]));


    drawLine(
        @floatToInt(i32, tri.screenVertex[2].x), 
        @floatToInt(i32, tri.screenVertex[2].y), 
        @floatToInt(i32, tri.screenVertex[0].x), 
        @floatToInt(i32, tri.screenVertex[0].y), Color.fromNormalVec4f(tri.color[2]));


    // math.max(math.max(v[0].y, v[1].y), v[2].y);

    _ = @atomicRmw(u32, &stats.renderedTris, .Add, 1, .SeqCst);
    
}

fn drawTriSpanJob(spanJob: *TriSpanData) void {
    _=spanJob;
}

pub fn drawMesh_old(m: *const Mat44f, v: *const Mat44f, p: *const Mat44f, mesh: *Mesh, shader: *Material) void {
    // const tracy = trace(@src());
    // defer tracy.end();
    var sp = profile.?.beginSample("render.mesh.draw");
    defer profile.?.endSample(sp);

    _ = @atomicRmw(u32, &stats.totalMeshes, .Add, 1, .SeqCst);
    _=shader;

    var mv = m.*;
    mv.mul(v.*);

    var mvp = mv.*;
    mvp.mul(p.*);
    // mvp.mul(m.*);

    const ids = mesh.indexBuffer.len;
    // const numTris = ids / 3;

    var t: u16 = 0;

    // while (t < ids) {
    //     triJobs.items[t / 3] = TriRenderJob.init(@truncate(u8, t / 3), m, v, p, &mv, &mvp, t, mesh, shader);

    //     var data = &triJobs.items[t / 3];
    //     data.complete = false;
    //     renderQueue.push(&data.job) catch continue;
    //     //drawTri(data);
    //     t += 3;
    // }

    t = 0;
    while (t < ids) {
        var wait: u64 = 0;
        var wt = profile.?.beginSample("render.mesh.wait.tri");
        defer profile.?.endSample(wt);
        var job: *TriRenderJob = &triJobs.items[t / 3];

        while (!job.complete) // and wait < 1_000_000)
        {
            std.atomic.spinLoopHint();
            // std.SpinLock.yield();
            //std.debug.warn("\t job: {}:{}:{} waiting!\n", .{job.id, job.complete, wait});
            wait += 1;
        }

        t += 3;
    }

    _ = @atomicRmw(u32, &stats.renderedMeshes, .Add, 1, .SeqCst);
}

pub fn drawPointMesh(mvp: *const Mat44f, mesh: *Mesh, shader: *Material) void {
    // const ids = mesh.vertexBuffer.len;
    _ = shader;
    for (mesh.vertexBuffer) |vertex, i| {
        drawPoint(mvp, vertex, mesh.colorBuffer[i]);
    }
}

pub fn drawString(font: *Font, str: []const u8, x: i32, y: i32, color: Vec4f) void {
    const zone = trace(@src());
    defer zone.end();
    const colorValue = Color.init(@floatToInt(u8, color.x * 255), @floatToInt(u8, color.y * 255), @floatToInt(u8, color.z * 255), @floatToInt(u8, color.w * 255));

    _ = colorValue;
    // _ = shader;

    for (str) |c, i| {
        const cx = font.characterX(c);
        const cy = font.characterY(c);

        var coy: i32 = 0;
        while (coy < font.glyphHeight) {
            defer coy += 1;

            var cox: i32 = 0;
            while (cox < font.glyphWidth - 1) {
                defer cox += 1;

                var samp = font.characterColor(cx, cy, cox, coy);
                if (samp.x <= 0.001)
                    continue;

                writePixelNormal((x + (font.glyphWidth - 1) * @intCast(i32, i)) + cox, y + coy, 1.0, samp);
            }
        }
    }
}

//
pub fn drawPoint(mvp: *const Mat44f, point: Vec4f, color: Vec4f, shader: *Material) void {
    const px = shader.vertexShader(mvp, 0, point);
    const pc = color;

    const c = Color.init(@floatToInt(u8, pc.x * 255), @floatToInt(u8, pc.y * 255), @floatToInt(u8, pc.z * 255), @floatToInt(u8, pc.w * 255));

    if (px.x >= 0 and px.x <= 1000 and px.y >= 0 and px.y <= 1000)
        writePixel(@floatToInt(i32, px.x), @floatToInt(i32, px.y), c);
}

///
pub fn drawWorldLine(mvp: *const Mat44f, start: Vec4f, end: Vec4f, color: Vec4f, shader: *Material) void {
    const spx = shader.vertexShader(mvp, 0, start);
    const epx = shader.vertexShader(mvp, 0, end);
    const pc = color;

    const c = Color.init(@floatToInt(u8, pc.x * 255), @floatToInt(u8, pc.y * 255), @floatToInt(u8, pc.z * 255), @floatToInt(u8, pc.w * 255));

    if (spx.x >= 0 and spx.x <= 1000 and spx.y >= 0 and spx.y <= 1000 and
        epx.x >= 0 and epx.x <= 1000 and epx.y >= 0 and epx.y <= 1000)
        drawLine(@floatToInt(i32, spx.x), @floatToInt(i32, spx.y), @floatToInt(i32, epx.x), @floatToInt(i32, epx.y), c);
}

/// Render triangle to frame buffer
// pub fn drawTri(d: *TriRenderJob) void {
//     // const tracy = trace(@src());
//     // defer tracy.end();
//     _ = @atomicRmw(u32, &stats.totalTris, .Add, 1, .SeqCst);

//     var vp = d.view.*;
//     vp.mul(d.proj.*);

//     const vi0 = d.mesh.indexBuffer[d.offset + 0];
//     const vi1 = d.mesh.indexBuffer[d.offset + 1];
//     const vi2 = d.mesh.indexBuffer[d.offset + 2];

//     const rv0 = d.mesh.vertexBuffer[vi0];
//     const rv1 = d.mesh.vertexBuffer[vi1];
//     const rv2 = d.mesh.vertexBuffer[vi2];

//     // cull back facing triangles
//     const mv0 = d.mv.mul33_vec4(rv0);
//     const mv1 = d.mv.mul33_vec4(rv1);
//     const mv2 = d.mv.mul33_vec4(rv2);

//     var e0 = mv1;
//     var e1 = mv2;

//     e0.sub(mv0); // cull back facing triangles
//     e1.sub(mv0);

//     const triNormal = e0.cross3(e1).normalized3();

//     const bfc = mv0.normalized3().dot3(triNormal);
//     if (bfc > 0.0000000000001)
//         return;

//     // const viewport = Vec4f.init(@intToFloat(f32, colorBuffer.w), @intToFloat(f32, colorBuffer.h), 0, 0);

//     const v0 = d.shader.projectionShader(d.proj, d.shader.vertexShader(d.mv, d.offset + 0, rv0, d.shader), viewport, d.shader);
//     const v1 = d.shader.projectionShader(d.proj, d.shader.vertexShader(d.mv, d.offset + 1, rv1, d.shader), viewport, d.shader);
//     const v2 = d.shader.projectionShader(d.proj, d.shader.vertexShader(d.mv, d.offset + 2, rv2, d.shader), viewport, d.shader);

//     const area = Vec4f.triArea(v0, v1, v2);

//     if (area <= 0)
//         return;

//     if (v0.z <= 0.1 or v1.z <= 0.1 or v2.z <= 0.1)
//         return;

//     // var sp = profile.?.beginSample("render.mesh.draw.tri");
//     // defer profile.?.endSample(sp);

    

//     const wv0 = d.model.mul_vec4(rv0);
//     const wv1 = d.model.mul_vec4(rv1);
//     const wv2 = d.model.mul_vec4(rv2);

//     const c0 = Vec4f.zero(); //rv0.scaleDup(0.5);//Vec4f.init(rv0.x,0,0,1); // mesh.vertexNormalBuffer[vi0];
//     const c1 = Vec4f.zero(); //rv1.scaleDup(0.5);//Vec4f.init(0,rv0.y,0,1); // mesh.vertexNormalBuffer[vi1];//mesh.colorBuffer[mesh.indexBuffer[offset + 1]];
//     const c2 = Vec4f.zero(); //rv2.scaleDup(0.5);//Vec4f.init(0,0,rv0.z,1); // mesh.vertexNormalBuffer[vi2];//mesh.colorBuffer[mesh.indexBuffer[offset + 2]];

//     var we0 = wv1;
//     var we1 = wv2;

//     we0.sub(wv0);
//     we1.sub(wv0);

//     const n0 = d.mesh.vertexNormalBuffer[d.mesh.indexNormalBuffer[d.offset + 0]];
//     const n1 = d.mesh.vertexNormalBuffer[d.mesh.indexNormalBuffer[d.offset + 1]];
//     const n2 = d.mesh.vertexNormalBuffer[d.mesh.indexNormalBuffer[d.offset + 2]];

//     const uv0 = Vec4f.init(d.mesh.textureCoordBuffer[d.mesh.indexUVBuffer[(d.offset + 0)] * 2 + 0], d.mesh.textureCoordBuffer[d.mesh.indexUVBuffer[(d.offset + 0)] * 2 + 1], 0, 0);
//     const uv1 = Vec4f.init(d.mesh.textureCoordBuffer[d.mesh.indexUVBuffer[(d.offset + 1)] * 2 + 0], d.mesh.textureCoordBuffer[d.mesh.indexUVBuffer[(d.offset + 1)] * 2 + 1], 0, 0);
//     const uv2 = Vec4f.init(d.mesh.textureCoordBuffer[d.mesh.indexUVBuffer[(d.offset + 2)] * 2 + 0], d.mesh.textureCoordBuffer[d.mesh.indexUVBuffer[(d.offset + 2)] * 2 + 1], 0, 0);

//     const wn0 = d.model.mul33_vec4(n0);
//     const wn1 = d.model.mul33_vec4(n1);
//     const wn2 = d.model.mul33_vec4(n2);

//     const renderBounds = Bounds.init(Vec4f.zero(), viewport);

//     var bounds = Bounds.init(v0, v0);
//     bounds.add(v0);
//     bounds.add(v1);
//     bounds.add(v2);
//     bounds.limit(renderBounds);
//     bounds.topLeftHandLimit();

//     // var subsamples: u16 =1;
//     // var stepDist: f32 = 1.0 / @intToFloat(f32, math.max(2, subsamples));

//     // iterate triangle bounding box drawing all pixels inside the triangle
//     // TODO: iterate tri edge vertically rendering scan lines to the opposite edge
//     var y = bounds.min.y;
//     var p: Vec4f = Vec4f.init(0, 0, 0, 0);
//     var pixelNormal: Vec4f = Vec4f.init(0, 0, 0, 0);
//     var fbc: Vec4f = Vec4f.init(0, 0, 0, 1);
//     var uv: Vec4f = Vec4f.init(0, 0, 0, 1);
//     var c: Color = Color.black();

//     _ = @atomicRmw(u32, &stats.renderedTris, .Add, 1, .SeqCst);

//     // Generate spans
//     while (y <= bounds.max.y) {
//         var x = bounds.min.x;
//         defer y += 1;

//         while (x <= bounds.max.x) {
//             // const pixtracy = trace(@src());
//             // defer pixtracy.end();
//             // var pprof = profile.?.beginSample("render.mesh.draw.tri.pixel");
//             // defer profile.?.endSample(pprof);
//             _ = @atomicRmw(u32, &stats.totalPixels, .Add, 1, .SeqCst);

//             defer x += 1;

//             p.x = x;
//             p.y = y;

//             var tri = Vec4f.triCoords(v0, v1, v2, p);

//             // TODO: near plane clipping
//             if (tri.x < 0 or tri.y < 0 or tri.z < 0)
//                 continue;

//             tri.div3(area);

//             // if we use perspective correct interpolation we need to
//             // multiply the result of this interpolation by z, the depth
//             // of the point on the 3D triangle that the pixel overlaps.
//             const z = (tri.x * v0.z + tri.y * v1.z + tri.z * v2.z);

//             if (d.shader.depthTest == 1 and depthBuffer.setLessThan(@floatToInt(i32, x), @floatToInt(i32, y), z) == 0)
//                 continue;

//             p.z = z;

//             // var pdprof = profile.?.beginSample("render.mesh.draw.tri.pixel.draw");
//             // defer profile.?.endSample(pdprof);

//             // interpolate vertex colors across all pixels
//             fbc = Vec4f.triInterp(tri, c0, c1, c2, 1.0, 1.0);
//             pixelNormal = Vec4f.triInterp(tri, wn0, wn1, wn2, 1.0, 1.0);
//             uv = Vec4f.triInterp(tri, uv0, uv1, uv2, 1.0, 1.0);

//             var vc = d.shader.pixelShader(d.mvp, p, fbc, pixelNormal, uv, d.shader);
//             if (vc.w <= 0.0)
//                 continue;

//             vc.clamp01();
//             vc.scale(255);

//             c.setR(@floatToInt(u8, @fabs(vc.x)));
//             c.setG(@floatToInt(u8, @fabs(vc.y)));
//             c.setB(@floatToInt(u8, @fabs(vc.z)));
//             c.setA(@floatToInt(u8, @fabs(vc.w)));

//             _ = @atomicRmw(u32, &stats.renderedPixels, .Add, 1, .SeqCst);
//             writePixel(@floatToInt(i32, x), @floatToInt(i32, y), z, c);
//         }
//     }

//     // var center = mv0.addDup(mv1);
//     // center.add(mv2);
//     // center.div(3);

//     // // drawWorldLine(mvp, de0, rv0, Vec4f.init(0,1,0,1));
//     // // drawWorldLine(mvp, rv0, de1, Vec4f.init(0,0,1,0));

//     // //drawWorldLine()
//     // drawWorldLine(proj, center, center.addDup(triNormal), Vec4f.init(0,0,1,1));

//     // drawWorldLine(mvp, rv0, rv0.addDup(n0), Vec4f.init(1,0,0,1));

//     // drawWorldLine(mvp, rv1, rv1.addDup(n1), Vec4f.init(0,1,0,1));

//     // drawWorldLine(mvp, rv2, rv2.addDup(n2), Vec4f.init(0,0,1,1));
// }



pub fn drawProgress(x: i16, y: i16, max_width: f32, value: f32, max_value: f32) void {
    const cs = std.math.clamp(value, 0.0, max_value) / max_value;
    // const cs2 = cs*cs;
    drawLine(x, y, @floatToInt(c_int, cs * max_width), y, Color.fromNormal(cs, (1 - cs), 0.2, 1));
}

pub fn writePixelNormal(x: i32, y: i32, z: f32, c: Vec4f) void {
    colorBuffer.write(x, y, Color.fromNormal(c.x, c.y, c.z, c.w));
    depthBuffer.write(x, y, z);
}

pub fn writePixel(x: i32, y: i32, z: f32, c: Color) void {
    colorBuffer.write(x, y, c);
    depthBuffer.write(x, y, z);
}

pub fn beginFrame(profiler: ?*Profile) *u8 {
    const zone = trace(@src());
    defer zone.end();

    profile = profiler;
    var pprof = profile.?.beginSample("render.beginFrame");
    defer profile.?.endSample(pprof);

    stats.reset();

    colorBuffer.clear(Color.init(50, 50, 120, 255));
    depthBuffer.clear(std.math.inf(f32));

    triJobs.reset();
    meshJobs.reset();
    spanJobs.reset();
    
    return &colorBuffer.bufferStart().color[0];
}

pub fn endFrame() void {
    //pixels.swapBuffers();
    {
        const zone = trace(@src());
        defer zone.end();

        stats.jobWaitCount = 0;
        stats.jobWaitCount = 0;

        // if(renderQueue.count() <= 0)
        {
            while( stats.totalMeshes <= 0 )
            {
                stats.jobCount+=1;
                std.atomic.spinLoopHint();
            }
        }

        while( renderQueue.count() > 0 )
        {
            stats.jobWaitCount += 1;
            std.atomic.spinLoopHint();
        }

        assert(stats.jobWaitCount > 0);
        assert(stats.totalMeshes == stats.renderedMeshes);
    }

    stats.trace();

}

pub fn shutdown() void {
    colorBuffer.deinit();
    depthBuffer.deinit();
    meshJobs.deinit();
    triJobs.deinit();
    spanJobs.deinit();
}
