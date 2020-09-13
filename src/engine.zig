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

const windowWidth: u16 = 800;
const windowHeight: u16 = 600;

const renderWidth: u16 = 320;
const renderHeight: u16 = 240;


const w=0.1;
const o=1.0;
var cubeVerts = [_]Vec4f{
  Vec4f.init(w, w*o, -w, 0.0), // 0
  Vec4f.init(w, -w*o, -w, 0.0), // 1
  Vec4f.init(w, w*o, w, 0.0), // 2
  Vec4f.init(w, -w*o, w, 0.0), // 3

  Vec4f.init(-w, w*o, -w, 0.0), // 4
  Vec4f.init(-w, -w*o, -w, 0.0), // 5
  Vec4f.init(-w, w*o, w, 0.0), // 6
  Vec4f.init(-w, -w*o, w, 0.0), // 7
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
  return render.Mesh.init(
    cubeVerts[0..],
    cubeTris[0..],
    cubeColors[0..]
  );
}

pub fn main() !void {
    try sys.init(windowWidth, windowHeight, renderWidth, renderHeight);
    defer sys.shutdown();

    try render.init(renderWidth, renderHeight);
    defer render.shutdown();

    const bufferLineSize = render.bufferLineSize();

    var quit = false;
    var mesh = createCube();
    var projMat = Mat44f.createPerspective(65, renderWidth/renderHeight, 0.1, 2000);
    var modelMat =Mat44f.identity();
    var viewMat = Mat44f.identity();
    var mvp = Mat44f.identity();

    
    viewMat.translate(Vec4f.init(0,0,-2,0));



    while (!quit) {
        quit = !sys.beginUpdate();
        const b = render.beginFrame();

        //viewMat.translate(Vec4f.init(0,0,0,0));

        mvp.init(viewMat.mm);
        mvp.mul(modelMat);
        mvp.mul(projMat);

        
        
        // TODO: do game stuff

        render.writePixel(100,100, render.Color.init(255, 128, 64, 255));

        render.drawPointMesh(&mvp, &mesh);

        render.endFrame();

        sys.updateRenderTexture(b, bufferLineSize);
        sys.endUpdate();
    }
}
