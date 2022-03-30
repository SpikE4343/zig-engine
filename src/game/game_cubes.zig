// platform imports
const std = @import("std");
const fmt = std.fmt;
const warn = std.debug.print;
const assert = std.debug.assert;

// engine imports
const engine = @import("../engine.zig");
const tools = @import("../tools.zig");
const input = engine.input;

pub const trace = @import("../tracy.zig").trace;

const matfuncs = engine.render.material;

var modelMat = engine.Mat44f.identity();
var viewMat = engine.Mat44f.identity();
var mesh: engine.Mesh = undefined;
var projMat: engine.Mat44f = undefined;

var meshAllocator = std.heap.page_allocator;
var textureAllocator = std.heap.page_allocator;
var meshMaterial: engine.render.Material = undefined;

var render3d:bool = true;
var renderSingleFrame:bool = false;

pub fn init() !void {
    projMat = engine.Mat44f.createPerspective(50, @intToFloat(f32, engine.systemConfig.renderWidth) / @intToFloat(f32, engine.systemConfig.renderHeight), 0.1, 1000);

    //cubeMesh = try tools.MeshObjLoader.importObjFile(meshAllocator, "../../assets/cube.obj");
    //mesh = try tools.MeshObjLoader.importObjFile(meshAllocator, "../../assets/bed.obj");
    mesh = try tools.MeshObjLoader.importObjFile(&meshAllocator, "../../assets/suzanne.obj");
    // var  texture = try tools.TgaTexLoader.importTGAFile(textureAllocator, "../../assets/black_rock.tga");
    var texture = try tools.TgaTexLoader.importTGAFile(&textureAllocator, "../../assets/grass.tga");

    meshMaterial = engine.render.Material{
        .depthTest = 1,
        .lightDirection = engine.Vec4f.init(-0.913913, 0.389759, -0.113369, 1).normalized3(),
        .lightColor = engine.Vec4f.one(),
        .lightIntensity = 1,
        .vertexShader = applyVertexShader,
        .projectionShader = projectVertex,
        .pixelShader = applyPixelShader,
        .texture = texture,
    };

    var fontTex = try tools.TgaTexLoader.importTGAFile(&textureAllocator, "../../assets/mbf_small_7x7.tga");

    font = engine.render.Font{
        .glyphWidth = 7,
        .glyphHeight = 7,
        .texture = fontTex,
    };

    viewMat.translate(engine.Vec4f.init(0, 0, -4.0, 0));
}

pub fn shutdown() !void {
    textureAllocator.deinit();
    meshAllocator.deinit();
}

const moveSpeed = 0.1;

var mousePos = engine.Vec4f.zero();
var cameraPos = engine.Vec4f.zero();
var cameraRot = engine.Mat44f.identity();

var exposure_bias: f32 = 2.0;
var font: engine.render.Font = undefined;
var singleFrameKeyDown:bool = false;

pub fn update() bool {
    // const tracy = trace(@src());
    // defer tracy.end();

    if (input.isKeyDown(input.KeyCode.ESCAPE))
        return false;

    var currentMouse = engine.Vec4f.init(((@intToFloat(f32, input.getMouseX()) / @intToFloat(f32, engine.systemConfig.windowWidth)) - 0.5) * 2.0, ((@intToFloat(f32, input.getMouseY()) / @intToFloat(f32, engine.systemConfig.windowHeight)) - 0.5) * 2.0, 0, 0);

    const mouseDelta = currentMouse.subDup(mousePos);

    const depth = (input.keyStateFloat(input.KeyCode.W) - input.keyStateFloat(input.KeyCode.S)) * moveSpeed;
    const horizontal = (input.keyStateFloat(input.KeyCode.A) - input.keyStateFloat(input.KeyCode.D)) * moveSpeed;
    const vertical = (input.keyStateFloat(input.KeyCode.DOWN) - input.keyStateFloat(input.KeyCode.UP)) * moveSpeed;

    // const rot = (input.keyStateFloat(input.KeyCode.Q) - input.keyStateFloat(input.KeyCode.E)) * moveSpeed;

    const rightButton = @intToFloat(f32, input.getMouseRight());

    const yaw = mouseDelta.x;
    const pitch = mouseDelta.y;

    currentMouse.z = yaw;
    currentMouse.w = pitch;

    const exposure = (input.keyStateFloat(input.KeyCode.U) - input.keyStateFloat(input.KeyCode.J)) * moveSpeed;
    const bright = input.keyStateFloat(input.KeyCode.I) - input.keyStateFloat(input.KeyCode.K) * 0.1;
    meshMaterial.lightIntensity = std.math.max(meshMaterial.lightIntensity + bright, 0.0);
    exposure_bias = std.math.max(exposure_bias + exposure, 0.0);

    mousePos = currentMouse;
    var trans = engine.Mat44f.identity();

    //trans.mul33(viewMat);
    trans.translate(engine.Vec4f.init(horizontal, vertical, depth, 0));
    trans.mul(engine.Mat44f.rotX(rightButton * pitch));
    trans.mul(engine.Mat44f.rotY(rightButton * yaw));
    trans.mul(viewMat);

    viewMat = trans;

    // var rotmat = engine.Mat44f.rotY(0.01 / 60.0);

    // rotmat.mul(modelMat);

    // modelMat = rotmat;

    _ = engine.sys.showMouseCursor(~input.getMouseRight());
    _ = engine.sys.setRelativeMouseMode(input.getMouseRight());

    // var srenderDraw = engine.Sampler.begin(&engine.profiler,"draw.mesh");
    // defer srenderDraw.end();



    if(!input.isKeyDown(input.KeyCode.SPACE))
    {
        // if(renderSingleFrame)
        //     render3d = false;

        // const renderStart = frameTimer.read();
        // renderTimer.reset();
        engine.render.drawMesh(&modelMat, &viewMat, &projMat, &mesh, &meshMaterial);
        engine.render.drawString(&font, "Hello World!", 10, 10, engine.Vec4f.one());
    }

    return true;
}

fn projectVertex(p: *const engine.Mat44f, v: engine.Vec4f, viewport: engine.Vec4f, material: *engine.render.Material) engine.Vec4f {
    var out = p.mul33_vec4(v);
    const half = viewport.scaleDup(0.5);
    _ = material;

    // center in viewport
    out.x = half.x * out.x + half.x;
    out.y = half.y * -out.y + half.y;
    return out;
}

fn applyVertexShader(mvp: *const engine.Mat44f, index: u16, vertex: engine.Vec4f, material: *engine.render.Material) engine.Vec4f {
    const out = mvp.mul_vec4(vertex);
    _ = material;
    _ = index;
    return out;
}

pub inline fn uncharted2_tonemap_partial(x: engine.Vec4f) engine.Vec4f {
    const A = 0.15;
    const B = 0.50;
    const C = 0.10;
    const D = 0.20;
    const E = 0.02;
    const F = 0.30;

    const EdivF = E / F;
    const DmulE = D * E;
    const DmulF = D * F;
    const CmulB = C * B;

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

pub inline fn uncharted2_filmic(v: engine.Vec4f) engine.Vec4f {
    //const exposure_bias = 2.0;
    const curr = uncharted2_tonemap_partial(v.scaleDup(exposure_bias));

    const W = engine.Vec4f.init(11.2, 11.2, 11.2, 0);
    const white_scale = engine.Vec4f.one().divVecDup(uncharted2_tonemap_partial(W));
    return curr.mulDup(white_scale);
}

pub inline fn reinhard(c: engine.Vec4f) engine.Vec4f {
    return c.divVecDup(engine.Vec4f.one().addDup(c));
    //return v / (1.0f + v);
}

///
fn applyPixelShader(mvp: *const engine.Mat44f, pixel: engine.Vec4f, color: engine.Vec4f, normal: engine.Vec4f, uv: engine.Vec4f, material: *engine.render.Material) engine.Vec4f {
    // var c = color.addDup(
    //   engine.Vec4f.init(
    //     (std.math.sin(uv.x*uv.y*1000)+1/2),
    //     (std.math.cos(uv.y*1000)+1/2),
    //     0,1)
    //   );

    _ = color;
    _ = pixel;
    _ = mvp;
    //var c = material.texture.sample(uv.x, uv.y);
    var c = material.texture.sampleBilinear(uv.x, uv.y);

    const l = std.math.max(normal.dot3(material.lightDirection) * material.lightIntensity, 0.4);

    c.scale(l);

    return uncharted2_filmic(c);
    //kreturn reinhard(c);
    //return c.scaleDup(l);
}
