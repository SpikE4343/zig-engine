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
var mesh = createCube();
var projMat:engine.Mat44f = undefined; 


pub fn init() !void {
    projMat = engine.Mat44f.createPerspective(
        65, 
        @intToFloat(f32, engine.systemConfig.renderWidth) / @intToFloat(f32, engine.systemConfig.renderHeight), 
        0.1, 
        2000
        );

    lastMousePos.x = @intToFloat(f32, engine.input.getMouseX());
    lastMousePos.y = @intToFloat(f32, engine.input.getMouseY());
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

var cameraPos = engine.Vec4f.zero();
var cameraRot = engine.Vec4f.zero();
var lastMousePos = engine.Vec4f.zero();

pub fn update() bool 
{   
    if (input.isKeyDown(input.KeyCode.ESCAPE))
        return false;

    var mvp = engine.Mat44f.identity();
    var mv = engine.Mat44f.identity();
    var viewMat = engine.Mat44f.identity();

    const depth = (input.keyStateFloat(input.KeyCode.W) - input.keyStateFloat(input.KeyCode.S)) * moveSpeed;
    const horizontal = (input.keyStateFloat(input.KeyCode.A) - input.keyStateFloat(input.KeyCode.D)) * moveSpeed;
    const vertical = (input.keyStateFloat(input.KeyCode.DOWN) - input.keyStateFloat(input.KeyCode.UP)) * moveSpeed;
    
    const currentMouse = engine.Vec4f.init(
        @intToFloat(f32, input.getMouseX()), 
        @intToFloat(f32, input.getMouseY()), 
        0, 0);

    var deltaMouse = currentMouse;
    deltaMouse.sub(lastMousePos);
    lastMousePos = currentMouse;

    _= engine.sys.showMouseCursor(~input.getMouseRight());
    engine.sys.setRelativeMouseMode(input.getMouseRight());
    engine.sys.setCaptureMouse(input.getMouseRight());


    if( input.getMouseRight() == 1)
    {
      cameraRot.y += 0.01 * deltaMouse.x;
      cameraRot.x += 0.01 * deltaMouse.y;
    }

  
    viewMat.mul33(engine.Mat44f.rotY(cameraRot.y));
    viewMat.mul33(engine.Mat44f.rotX(cameraRot.x));

    var forward = viewMat.mul33_vec4(engine.Vec4f.forward());
    forward.scale(depth);
    cameraPos.add(forward);

    //forward.print();
    //cameraPos.print();
    viewMat.translate(cameraPos);
    
    mv.copy(viewMat);
    mv.mul(modelMat);

    mvp.copy(projMat);
    mvp.mul(mv);

    {
        // var srenderDraw = engine.Sampler.begin(&engine.profiler,"draw.mesh");
        // defer srenderDraw.end();

        engine.render.drawMesh(&mv, &mvp, &mesh);
    }

    return true;
}
