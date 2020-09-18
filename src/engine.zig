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

pub var stdout = std.io.getStdOut();


pub const windowWidth: u16 = 1024;
pub const windowHeight: u16 = 768;

pub const renderWidth: u16 = 320;
pub const renderHeight: u16 = 240;

pub fn main() !void {

    var profiler = Profile.init();
    profiler.nextFrame();

    try sys.init(windowWidth, windowHeight, renderWidth, renderHeight);
    defer sys.shutdown();

    try render.init(renderWidth, renderHeight, undefined);
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
                quit = quit or !game.update();
            }
            render.endFrame();

            {
                var srt = Sampler.begin(&profiler, "system.render.present");
                defer srt.end();
                
                sys.updateRenderTexture(b, bufferLineSize);
                _= sys.endUpdate();
            }
        }

      try profiler.streamPrint(stdout);
      profiler.nextFrame();
    }
}
