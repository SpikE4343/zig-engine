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
const Profile = @import("core/profiler.zig").Profile;
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

fn init() !void {

}

fn shutdown() !void {
    
}

fn createCube() render.Mesh {
    return render.Mesh.init(cubeVerts[0..], cubeTris[0..], cubeColors[0..]);
}


const moveSpeed = 0.1;

pub fn update() !bool 
{   
    var quit = false;
    var mesh = createCube();
    var projMat = Mat44f.createPerspective(65, @intToFloat(f32, renderWidth) / @intToFloat(f32, renderHeight), 0.1, 2000);
    var modelMat = Mat44f.identity();
    var viewMat = Mat44f.identity();


    if (input.isKeyDown(input.KeyCode.ESCAPE))
        return false;

    var mvp = Mat44f.identity();
    var temp = Mat44f.identity();

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
