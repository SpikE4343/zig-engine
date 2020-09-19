// platform imports
const std = @import("std");
const fmt = std.fmt;
const warn = std.debug.warn;
const assert = std.debug.assert;

// engine imports
const engine = @import("../engine.zig");
const input = engine.input;

const w = 1;
var cubeVerts = [_]engine.Vec4f{
    engine.Vec4f.init(w, w, -w, 1.0), // 0
    engine.Vec4f.init(w, -w, -w, 1.0), // 1
    engine.Vec4f.init(w, w, w, 1.0), // 2
    engine.Vec4f.init(w, -w, w, 1.0), // 3

    engine.Vec4f.init(-w, w, -w, 1.0), // 4
    engine.Vec4f.init(-w, -w, -w, 1.0), // 5
    engine.Vec4f.init(-w, w, w, 1.0), // 6
    engine.Vec4f.init(-w, -w, w, 1.0), // 7
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
var cubeColors = [_]engine.Vec4f{
    engine.Vec4f.init(0.1, 1, 0.3, 1.0), // 0
    engine.Vec4f.init(0.1, 0.3, 0.8, 1.0), // 1
    engine.Vec4f.init(0.5, 0.8, 0.2, 1.0), // 2
    engine.Vec4f.init(0.1, 0.2, 1, 1.0), // 3

    engine.Vec4f.init(1.0, 0.5, 0.33, 1.0), // 4
    engine.Vec4f.init(0.1, 0.45, 0.27, 1.0), // 5
    engine.Vec4f.init(1.0, 0.5, 1, 1.0), // 6
    engine.Vec4f.init(0.1, 1, 0.11, 1.0), // 7
};

var modelMat = engine.Mat44f.identity();
var viewMat = engine.Mat44f.identity();
var mesh = createCube();
var projMat:engine.Mat44f = undefined; 


pub fn init() !void {
    projMat = engine.Mat44f.createPerspective(
        65, 
        @intToFloat(f32, engine.systemConfig.renderWidth) / @intToFloat(f32, engine.systemConfig.renderHeight), 
        0.1, 
        2000
        );
}

pub fn shutdown() !void {
    
}

fn createCube() engine.render.Mesh {
    return engine.render.Mesh.init(cubeVerts[0..], cubeTris[0..], cubeColors[0..]);
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

pub fn update() bool 
{   
    if (input.isKeyDown(input.KeyCode.ESCAPE))
        return false;

    var mvp = engine.Mat44f.identity();
    var temp = engine.Mat44f.identity();

    const depth = (input.keyStateFloat(input.KeyCode.W) - input.keyStateFloat(input.KeyCode.S)) * moveSpeed;
    const horizontal = (input.keyStateFloat(input.KeyCode.A) - input.keyStateFloat(input.KeyCode.D)) * moveSpeed;
    const vertical = (input.keyStateFloat(input.KeyCode.DOWN) - input.keyStateFloat(input.KeyCode.UP)) * moveSpeed;

    viewMat.translate(engine.Vec4f.init(horizontal, vertical, depth, 0));

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

    {
        // var srenderDraw = engine.Sampler.begin(&engine.profiler,"draw.mesh");
        // defer srenderDraw.end();

        // const renderStart = frameTimer.read();
        // renderTimer.reset();
        engine.render.drawMesh(&mvp, &mesh);
        
    }

    return true;
}
