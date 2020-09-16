// platform imports
const std = @import("std");
const fmt = std.fmt;
const warn = std.debug.warn;
const assert = std.debug.assert;
const Timer = std.time.Timer;

// engine imports
const sys = @import("system/sys_sdl.zig");
const Mat44f = @import("core/matrix.zig").Mat44f;
const Vec4f = @import("core/vector.zig").Vec4f;
const render = @import("render/raster_cpu.zig");
const input = @import("system/sys_input.zig");
const Profile = @import("core/profiler.zig").ThreadProfile;
const Sampler = @import("core/profiler.zig").Sampler;


const windowWidth: u16 = 1024;
const windowHeight: u16 = 768;

const renderWidth: u16 = 320;
const renderHeight: u16 = 240;

const w = 1;
var cubeVerts = [_]Vec4f{
    Vec4f.init(w, w, -w, 1.0), // 0
    Vec4f.init(w, -w, -w, 1.0), // 1
    Vec4f.init(w, w, w, 1.0), // 2
    Vec4f.init(w, -w, w, 1.0), // 3

    Vec4f.init(-w, w, -w, 1.0), // 4
    Vec4f.init(-w, -w, -w, 1.0), // 5
    Vec4f.init(-w, w, w, 1.0), // 6
    Vec4f.init(-w, -w, w, 1.0), // 7
};

// indicies
var cubeTris = [_]u16{
    4, 2, 0,
    2, 7, 3,
    6, 5, 7,
    1, 7, 5,
    0, 3, 1,
    4, 1, 5,
    4, 6, 2,
    2, 6, 7,
    6, 4, 5,
    1, 3, 7,
    0, 2, 3,
    4, 0, 1,
};

// colors
var cubeColors = [_]Vec4f{
    Vec4f.init(0.1, 1, 0.3, 1.0), // 0
    Vec4f.init(0.1, 0.3, 0.8, 1.0), // 1
    Vec4f.init(0.5, 0.8, 0.2, 1.0), // 2
    Vec4f.init(0.1, 0.2, 1, 1.0), // 3

    Vec4f.init(1.0, 0.5, 0.33, 1.0), // 4
    Vec4f.init(0.1, 0.45, 0.27, 1.0), // 5
    Vec4f.init(1.0, 0.5, 1, 1.0), // 6
    Vec4f.init(0.1, 1, 0.11, 1.0), // 7
};

fn createCube() render.Mesh {
    return render.Mesh.init(cubeVerts[0..], cubeTris[0..], cubeColors[0..]);
}

fn drawProgress(x:i16, y:i16, value:f32, max:f32) void {
  const cs = std.math.clamp(value, 0.0, max)/max;
  render.drawLine(
    x,y,
    @floatToInt(c_int, cs* @intToFloat(f32,renderWidth)/4), 
    y, 
    render.Color.fromNormal(cs, 1-cs, 0.2, 1)
  );
}

const moveSpeed = 0.1;

pub fn main() !void {
    try sys.init(windowWidth, windowHeight, renderWidth, renderHeight);
    defer sys.shutdown();

    try render.init(renderWidth, renderHeight);
    defer render.shutdown();

    const bufferLineSize = render.bufferLineSize();

    var quit = false;
    var mesh = createCube();
    var projMat = Mat44f.createPerspective(65, @intToFloat(f32, renderWidth) / @intToFloat(f32, renderHeight), 0.1, 2000);
    var modelMat = Mat44f.identity();
    var viewMat = Mat44f.identity();
    var frameTime:u64 = 0;

    viewMat.translate(Vec4f.init(0, 0, -10, 1));

    var frameTimer = try Timer.start();
    var renderTimer = try Timer.start();
    const targetFrameTimeNs = @intToFloat(f32, sys.targetFrameTimeMs() * 1_000_000);

    var profiler = Profile.init();

    while (!quit) {
        frameTimer.reset();
        quit = !sys.beginUpdate();
        if (input.isKeyDown(input.KeyCode.ESCAPE))
            quit = true;

        {
            var c = Sampler.begin(&profiler, "main");
            defer c.end();

            const b = render.beginFrame();
            {
                

                var mvp = Mat44f.identity();
                var temp = Mat44f.identity();
                
                {
                    var sinput = Sampler.begin(&profiler,"input");
                    defer sinput.end();

                    const depth = (input.keyStateFloat(input.KeyCode.W) - input.keyStateFloat(input.KeyCode.S)) * moveSpeed;
                    const horizontal = (input.keyStateFloat(input.KeyCode.A) - input.keyStateFloat(input.KeyCode.D)) * moveSpeed;
                    const vertical = (input.keyStateFloat(input.KeyCode.DOWN) - input.keyStateFloat(input.KeyCode.UP)) * moveSpeed;
                
                    viewMat.translate(Vec4f.init(horizontal, vertical, depth, 0));

                    //modelMat.mul(Mat44f.rotX(0.01));
                    //modelMat.mul(Mat44f.rotY(-0.02));
                    //modelMat.mul(Mat44f.rotZ(0.001));

                    temp.copy(viewMat);
                    //std.debug.warn("temp:\n", .{});
                    //temp.print();

                    temp.mul(modelMat);
                    //std.debug.warn("view*model:\n", .{});
                    //temp.print();

                    mvp.copy(projMat);
                    mvp.mul(temp);
                }

                {
                    var srender = Sampler.begin(&profiler,"draw");
                    defer srender.end();

                    const renderStart = frameTimer.read();
                    renderTimer.reset();
                    render.drawMesh(&mvp, &mesh);
                    
                }

                const renderTime = renderTimer.lap();    
                drawProgress( 0,2, @intToFloat(f32,frameTime), targetFrameTimeNs);
                drawProgress( 0,4, @intToFloat(f32,renderTime), targetFrameTimeNs);

            }
            render.endFrame();

            sys.updateRenderTexture(b, bufferLineSize);
            frameTime = frameTimer.lap();
            _=sys.endUpdate();
        }
        profiler.print();
        profiler.reset();
    }
}
