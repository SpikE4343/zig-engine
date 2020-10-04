// platform imports
const std = @import("std");
const fmt = std.fmt;
const warn = std.debug.warn;
const assert = std.debug.assert;
const Timer = std.time.Timer;

// engine imports
pub const sys = @import("system/sys_sdl.zig");
pub const render = @import("render/raster_cpu.zig");
pub const input = @import("system/sys_input.zig");
pub const game = @import("game/game_cubes.zig");

pub const Mat44f = @import("core/matrix.zig").Mat44f;
pub const Vec4f = @import("core/vector.zig").Vec4f;
pub const Profile = @import("core/profiler.zig").Profile;
pub const Sampler = @import("core/profiler.zig").Sampler;

pub const Mesh = @import("render/mesh.zig").Mesh;
pub const MeshObjLoader = @import("render/obj_mesh_loader.zig");

pub var stdout = std.io.getStdOut();


pub const systemConfig = sys.Config{
  .windowWidth = 1024,
  .windowHeight = 768,
  .renderWidth = 320,
  .renderHeight = 240,
  .maxFps = 60,
  .fullscreen = false,
};

// pub const systemConfig = sys.Config{
//   .windowWidth = 1920,
//   .windowHeight = 1080,
//   .renderWidth = 426,
//   .renderHeight = 240,
//   .maxFps = 60,
//   .fullscreen = true,
// };


// pub const systemConfig = sys.Config{
//   .windowWidth = 1920,
//   .windowHeight = 1080,
//   .renderWidth = 426,
//   .renderHeight = 240,
//   .maxFps = 60,
//   .fullscreen = true,
// };

pub fn main() !void {

    var profiler = Profile.init();
    profiler.nextFrame();

    try sys.init(systemConfig);
    defer sys.shutdown();

    try render.init(systemConfig.renderWidth, systemConfig.renderHeight, &profiler);
    defer render.shutdown();

    const bufferLineSize = render.bufferLineSize();

    var quit = false;
    const targetFrameTimeNs = @intToFloat(f32, sys.targetFrameTimeMs() * 1_000_000);

    _= try game.init();

    while (!quit) 
    {
        {
            var el = Sampler.begin(&profiler,"engine.main");
            defer el.end();
            
            {
                var supdate = Sampler.begin(&profiler,"system.update");
                defer supdate.end();

                quit = !sys.beginUpdate();
            }

            const b = render.beginFrame();
            {
                var c = Sampler.begin(&profiler, "game.update");
                defer c.end();
                if(!game.update())
                  return;
            }
            render.endFrame();

            {
                var srt = Sampler.begin(&profiler, "system.render.present");
                defer srt.end();

                sys.updateRenderTexture(b, bufferLineSize);
                sys.renderPresent();
            }

            {
                var sup = Sampler.begin(&profiler, "system.wait");
                defer sup.end();

                _= sys.endUpdate();
            }
        }

        //try profiler.streamPrint(stdout);
        profiler.nextFrame();
    }
}
