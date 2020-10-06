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
var textureAllocator = std.heap.page_allocator;


var material = engine.render.Material{
    .lighDirection = Vec4f.init(-0.913913,0.389759,-0.113369, 1).normalized3(),
    .lightColorIntensity = Vec4f.one().scaleDup(0.5),
};

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

    var  texture = try tools.TgaTexLoader.importTGAFile(textureAllocator, "../../assets/black_rock.tga");

    viewMat.translate(engine.Vec4f.init(0, 0, -4.0, 0));
}

pub fn shutdown() !void {
    textureAllocator.deinit();
    meshAllocator.deinit();
}


fn drawProgress(x:i16, y:i16, max_screen_width:f32, value:f32, max_value:f32) void {
  const cs = std.math.clamp(value, 0.0, max_value)/max_value;
  render.drawLine(
    x,y,
    @floatToInt(c_int, cs*max_screen_width), 
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


pub fn applyVertexShader(mvp: *const Mat44f, index: u16, v: Vec4f, material:Material) Vec4f {
    var out = mvp.mul_vec4(v);
    return out;
}

pub fn projectVertex(p: *const Mat44f, v: Vec4f, viewport:Vec4f, material:Material) Vec4f {
    var out = p.mul33_vec4(v);
    const half = viewport.scaleDup(0.5);

    // center in viewport
    out.x = half.x * out.x + half.x;
    out.y = half.y * -out.y + half.y;
    return out;
}

pub inline fn uncharted2_tonemap_partial(x:Vec4f) Vec4f
{
    const A = 0.15;
    const B = 0.50;
    const C = 0.10;
    const D = 0.20;
    const E = 0.02;
    const F = 0.30;
    
    const EdivF = E/F;
    const DmulE = D*E;
    const DmulF = D*F;
    const CmulB = C*B;

    const xmulA = x.scaleDup(A);
    
    var xNumer = x.mulDup(xmulA.addScalarDup(CmulB));
    xNumer.addScalar(DmulE);


    var xDenom = x.mulDup(xmulA.addScalarDup(B));
    xDenom.addScalar(DmulF);

    xNumer.divVec(xDenom);
    xNumer.subScalar(EdivF);

    return xNumer;   
    //return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

pub inline fn uncharted2_filmic(v:Vec4f) Vec4f
{
    const exposure_bias = 2.0;
    const curr = uncharted2_tonemap_partial(v.scaleDup(exposure_bias));

    const W = Vec4f.init(11.2,11.2,11.2,0);
    const white_scale = Vec4f.one().divVecDup(uncharted2_tonemap_partial(W));
    return curr.mulDup(white_scale);
}

pub inline fn reinhard(c:Vec4f) Vec4f
{
    return c.divVecDup(Vec4f.one().addDup(c));
    //return v / (1.0f + v);
}

///
pub fn applyPixelShader(
  mvp: *const Mat44f, 
  pixel: Vec4f, 
  color: Vec4f, 
  normal:Vec4f,
  uv:Vec4f, 
  material:Material) Vec4f 
{
  var c = color.addDup(
    Vec4f.init(
      (std.math.sin(uv.x*uv.y*1000)+1/2),
      (std.math.cos(uv.y*1000)+1/2),
      0,1)
    );

    const l = std.math.max(normal.dot3(material.lightDirection)*4, 0.3);

    //return uncharted2_filmic( c.scaleDup(l) );
    return reinhard(c.scaleDup(l));
    //return c.scaleDup(l);
}
