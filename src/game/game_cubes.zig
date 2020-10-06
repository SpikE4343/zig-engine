// platform imports
const std = @import("std");
const fmt = std.fmt;
const warn = std.debug.warn;
const assert = std.debug.assert;

// engine imports
const engine = @import("../engine.zig");
const tools = @import("../tools.zig");
const input = engine.input;

var modelMat = engine.Mat44f.identity();
var viewMat = engine.Mat44f.identity();
var mesh:engine.Mesh = undefined; 
var projMat:engine.Mat44f = undefined; 

var meshAllocator = std.heap.page_allocator;

const lightDir = Vec4f.init(-0.913913,0.389759,-0.113369, 1).normalized3();

pub fn init() !void {
    projMat = engine.Mat44f.createPerspective(
        50, 
        @intToFloat(f32, engine.systemConfig.renderWidth) / @intToFloat(f32, engine.systemConfig.renderHeight), 
        0.1, 
        1000
        );

    //mesh = try tools.MeshObjLoader.importObjFile(meshAllocator, "../../assets/cube.obj");
    //mesh = try tools.MeshObjLoader.importObjFile(meshAllocator, "../../assets/bed.obj");
    mesh = try tools.MeshObjLoader.importObjFile(meshAllocator, "../../assets/suzanne.obj");

    viewMat.translate(engine.Vec4f.init(0, 0, -4.0, 0));
}

pub fn shutdown() !void {
    
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

var mousePos = engine.Vec4f.zero();
var cameraPos = engine.Vec4f.zero();
var cameraRot = engine.Mat44f.identity();



pub fn update() bool 
{   
    if (input.isKeyDown(input.KeyCode.ESCAPE))
        return false;

    var currentMouse = engine.Vec4f.init(
      ((@intToFloat(f32,input.getMouseX()) / @intToFloat(f32, engine.systemConfig.windowWidth ) ) - 0.5) * 2.0, 
      ((@intToFloat(f32,input.getMouseY()) / @intToFloat(f32, engine.systemConfig.windowHeight) ) - 0.5) * 2.0, 
       0 , 0 );

    const mouseDelta = currentMouse.subDup(mousePos);

    const depth = (input.keyStateFloat(input.KeyCode.W) - input.keyStateFloat(input.KeyCode.S)) * moveSpeed;
    const horizontal = (input.keyStateFloat(input.KeyCode.A) - input.keyStateFloat(input.KeyCode.D)) * moveSpeed;
    const vertical = (input.keyStateFloat(input.KeyCode.DOWN) - input.keyStateFloat(input.KeyCode.UP)) * moveSpeed;

    const rot = (input.keyStateFloat(input.KeyCode.Q) - input.keyStateFloat(input.KeyCode.E)) * moveSpeed;

    const rightButton = @intToFloat(f32, input.getMouseRight());

    const yaw = mouseDelta.x;
    const pitch = mouseDelta.y;

    currentMouse.z = yaw;
    currentMouse.w = pitch;
    
    // mousePos.println();
    // currentMouse.println();
    // mouseDelta.println();
  

    mousePos = currentMouse;
    //var forward = viewMat.col(2);

    //viewMat.print();
    //const forward = viewMat.mul33_vec4(engine.Vec4f.forward()).normalized3();
    // forward.print();
    var trans = engine.Mat44f.identity();
    
    //trans.mul33(viewMat);
    trans.translate(engine.Vec4f.init(horizontal, vertical, depth, 0));
    //viewMat.translate(forward.scaleDup(1));
    //viewMat.print();

    trans.mul(engine.Mat44f.rotX(rightButton * pitch));
    trans.mul(engine.Mat44f.rotY(rightButton * yaw));
    
    trans.mul(viewMat);
    
    
    //viewMat.print();
    
    viewMat = trans;
  
    

    _=engine.sys.showMouseCursor(~input.getMouseRight());
    //_=engine.sys.setCaptureMouse(input.getMouseRight());
    _=engine.sys.setRelativeMouseMode(input.getMouseRight());

    //modelMat.mul(Mat44f.rotX(0.01));
    //modelMat.mul(engine.Mat44f.rotY(rot));
    //modelMat.mul(Mat44f.rotZ(0.001));

    

    {
        // var srenderDraw = engine.Sampler.begin(&engine.profiler,"draw.mesh");
        // defer srenderDraw.end();

        // const renderStart = frameTimer.read();
        // renderTimer.reset();
        engine.render.drawMesh(&modelMat, &viewMat, &projMat, &mesh);
        
    }

    return true;
}
