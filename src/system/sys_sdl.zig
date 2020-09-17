const std = @import("std");
const warn = std.debug.warn;
const fmt = std.fmt;

const common = @import("sys_common.zig");
const input = @import("sys_input.zig");

const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const assert = @import("std").debug.assert;

const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, c.SDL_WINDOWPOS_UNDEFINED_MASK);
const SDL_INIT_EVERYTHING = c.SDL_INIT_TIMER |
    c.SDL_INIT_AUDIO |
    c.SDL_INIT_VIDEO |
    c.SDL_INIT_EVENTS |
    c.SDL_INIT_JOYSTICK |
    c.SDL_INIT_HAPTIC |
    c.SDL_INIT_GAMECONTROLLER;

const INIT_WIDTH = 800;
const INIT_HEIGHT = 600;
pub const maxFps = 10;
const targetDt = 1000 / maxFps;

var t0: u32 = 0;
//var t1:u32 = 0;

var renderTexture: ?*c.SDL_Texture = null;
var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;

pub fn init(windowWidth: u16, windowHeight: u16, renderWidth: u16, renderHeight: u16) !void {
    try common.init(windowWidth, windowHeight, renderWidth, renderHeight);

    if (c.SDL_Init(c.SDL_INIT_EVERYTHING) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    // defer c.SDL_Quit();

    window = c.SDL_CreateWindow("zig-engine", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, @intCast(c_int, windowWidth), @intCast(c_int, windowHeight), c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE) // c.SDL_WINDOW_FULLSCREEN_DESKTOP ) //c.SDL_WINDOW_RESIZABLE)
        orelse
        {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    // defer c.SDL_DestroyWindow(window);

    renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse
        {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    //defer
    renderTexture = c.SDL_CreateTexture(renderer, c.SDL_PIXELFORMAT_ABGR8888, c.SDL_TEXTUREACCESS_STATIC, @intCast(c_int, renderWidth), @intCast(c_int, renderHeight));
}

pub inline fn targetFrameTimeMs() u32 {
  return targetDt;
}

pub fn updateRenderTexture(data: *u8, len: usize) void {
    var pixelsPtr = @ptrCast(*c_void, data);
    if (c.SDL_UpdateTexture(renderTexture, 0, pixelsPtr, @intCast(c_int, len)) != 0)
        c.SDL_Log("Unable to update texture: %s", c.SDL_GetError());
}

pub fn shutdown() void {
    common.shutdown();

    c.SDL_DestroyRenderer(renderer);
    c.SDL_DestroyWindow(window);
    c.SDL_Quit();
}

pub fn beginUpdate() bool {
    _= common.beginUpdate();

    t0 = @intCast(u32, c.SDL_GetTicks());

    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event) != 0) 
    {
        switch (event.@"type") 
        {
            c.SDL_QUIT => {
                return false;
            },

            c.SDL_KEYDOWN, c.SDL_KEYUP => {
              //printf("key(%u): %u\n", event->key.state, event->key.keysym.scancode);
              const scancode = @enumToInt(event.key.keysym.scancode);
              const keyCode = @intToEnum(input.KeyCode, @intCast(u16, scancode));

              input.setKeyState(keyCode, @intCast(u1, event.key.state));
            },

            c.SDL_MOUSEMOTION => {
              input.setMousePos(event.motion.x, event.motion.y);
            },

            else => {},
        }
    }

    return true;
}

pub fn endUpdate() u32 {

    common.endUpdate();

    _ = c.SDL_RenderClear(renderer);
    if (c.SDL_RenderCopy(renderer, renderTexture, 0, 0) != 0)
        c.SDL_Log("Unable to copy texture: %s", c.SDL_GetError());

    _ = c.SDL_RenderPresent(renderer);

    var t1 = @intCast(u32, c.SDL_GetTicks());
    const dtInt = t1 - t0;
    //const dt = @intToFloat(f32, dtInt);
    if (dtInt < targetDt)
        c.SDL_Delay((targetDt - dtInt) - 1);

    //std.debug.warn("dt:{} ms\n", .{dtInt});
    // else {
    //     dt = 0.001 * @intToFloat(f32, t1 - t0);
    // }
    t0 = t1;

    return dtInt;
}
