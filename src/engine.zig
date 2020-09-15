// platform imports
const std = @import("std");
const fmt = std.fmt;
const warn = std.debug.warn;
const assert = std.debug.assert;

// engine imports
const sys = @import("system/sys_sdl.zig");
const Mat44f = @import("core/matrix.zig").Mat44f;
const Vec4f = @import("core/vector.zig").Vec4f;
const render = @import("render/raster_cpu.zig");
const input = @import("system/sys_input.zig");

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
    Vec4f.init(0.1, 0.7, 0.3, 1.0), // 0
    Vec4f.init(0.1, 0.3, 0.8, 1.0), // 1
    Vec4f.init(0.5, 0.8, 0.2, 1.0), // 2
    Vec4f.init(0.1, 0.2, 0.65, 1.0), // 3

    Vec4f.init(1.0, 0.5, 0.33, 1.0), // 4
    Vec4f.init(0.1, 0.45, 0.27, 1.0), // 5
    Vec4f.init(0.8, 0.5, 0.64, 1.0), // 6
    Vec4f.init(0.1, 0.3, 0.11, 1.0), // 7
};

fn createCube() render.Mesh {
    return render.Mesh.init(cubeVerts[0..], cubeTris[0..], cubeColors[0..]);
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
    var frameTime:i32 = 0;

    viewMat.translate(Vec4f.init(0, 0, -10, 1));

    while (!quit) {
        quit = !sys.beginUpdate();
        if (input.isKeyDown(input.KeyCode.ESCAPE))
            quit = true;

        const b = render.beginFrame();
        {
            var mvp = Mat44f.identity();
            var temp = Mat44f.identity();

            const depth = (input.keyStateFloat(input.KeyCode.W) - input.keyStateFloat(input.KeyCode.S)) * moveSpeed;

            const horizontal = (input.keyStateFloat(input.KeyCode.A) - input.keyStateFloat(input.KeyCode.D)) * moveSpeed;

            const vertical = (input.keyStateFloat(input.KeyCode.UP) - input.keyStateFloat(input.KeyCode.DOWN)) * moveSpeed;

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


            render.drawMesh(&mvp, &mesh);

            const s = @intToFloat(f32,frameTime) / @intToFloat(f32, sys.targetFrameTime());
            if(s > 0.0){
              const cs = std.math.min(s, 1.0);
              render.drawLine(
                0,2,
                @floatToInt(c_int, cs* @intToFloat(f32,renderWidth)/4), 
                2, 
                render.Color.fromNormal(cs, 1-cs, 0.2, 1)
              );
            }
        }
        render.endFrame();

        sys.updateRenderTexture(b, bufferLineSize);
        frameTime += (@intCast(i32, sys.endUpdate())-frameTime) >> 2;
    }
}
