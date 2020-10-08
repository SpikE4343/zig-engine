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

pub var stdout = std.io.getStdOut();

var bufferAllocator = std.heap.page_allocator;

// pub const systemConfig = sys.Config{
//   .windowWidth = 1024,
//   .windowHeight = 768,
//   .renderWidth = 320,
//   .renderHeight = 240,
//   .maxFps = 60,
//   .fullscreen = false,
// };

// pub const systemConfig = sys.Config{
//   .windowWidth = 1920,
//   .windowHeight = 1080,
//   .renderWidth = 1920,
//   .renderHeight = 1080,
//   .maxFps = 60,
//   .fullscreen = true,
// };


pub const systemConfig = sys.Config{
  .windowWidth = 1920,
  .windowHeight = 1080,
  .renderWidth = 426,
  .renderHeight = 240,
  .maxFps = 60,
  .fullscreen = true,
};

var profileId:u1 = 0;

var profiles:[2]Profile = undefined;

  

pub fn swapProfile() *Profile {
  profileId = ~profileId;
  return currentProfile();
}

pub fn currentProfile() *Profile {
  return &profiles[profileId];
}

pub fn nextProfile() *Profile {
  return &profiles[~profileId];
}

pub fn main() !void {

    profiles = [2]Profile {
      try Profile.init(bufferAllocator),
      try Profile.init(bufferAllocator)
    };

    var profiler = currentProfile();
    profiler.nextFrame();

    var lastProfile = nextProfile();
    lastProfile.nextFrame();


    try sys.init(systemConfig);
    defer sys.shutdown();

    try render.init(systemConfig.renderWidth, systemConfig.renderHeight, bufferAllocator, profiler);
    defer render.shutdown();

    const bufferLineSize = render.bufferLineSize();

    var quit = false;
    const targetFrameTimeNs = @intToFloat(f32, sys.targetFrameTimeMs() * 1_000_000);

    _= try game.init();

    var mainSampler:Sampler = undefined;
    var systemSampler:Sampler = undefined;
    var gameSampler:Sampler = undefined;
    var renderSampler:Sampler = undefined;

    while (!quit) 
    {
        {
            var el = Sampler.begin(profiler,"engine.main");
            defer el.end();
            
            {
                var supdate = Sampler.begin(profiler,"system.update");
                defer supdate.end();

                quit = !sys.beginUpdate();
            }

            const b = render.beginFrame();
            {
                var c = Sampler.begin(profiler, "game.update");
                defer c.end();
                if(!game.update())
                  break;
            }
            render.endFrame();

            {
                var srt = Sampler.begin(profiler, "engine.render.profile");
                defer srt.end();

                if(lastProfile.hasSamples())
                {
                  render.drawProgress(2, 2, 100, @intToFloat(f32, lastProfile.sampleTime(1)), targetFrameTimeNs );
                  render.drawProgress(2, 5, 100, @intToFloat(f32, lastProfile.sampleTime(2)), targetFrameTimeNs );
                }
            }


            {
                var srt = Sampler.begin(profiler, "system.render.present");
                defer srt.end();

                sys.updateRenderTexture(b, bufferLineSize);
                sys.renderPresent();
            }

            {
                var sup = Sampler.begin(profiler, "system.wait");
                defer sup.end();

                _= sys.endUpdate();
            }
        }

      
        lastProfile = profiler;
        profiler = swapProfile();
        profiler.nextFrame();
    }

    try lastProfile.jsonFileWrite(bufferAllocator, "prof.json");

    //bufferAllocator.deinit();
}
