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

const SDL_INIT_EVERYTHING = 
    c.SDL_INIT_TIMER |
    c.SDL_INIT_AUDIO |
    c.SDL_INIT_VIDEO |
    c.SDL_INIT_EVENTS |
    c.SDL_INIT_JOYSTICK |
    c.SDL_INIT_HAPTIC |
    c.SDL_INIT_GAMECONTROLLER;

var t0: u32 = 0;
//var t1:u32 = 0;

pub const Config = struct 
{
  windowWidth : u16,
  windowHeight : u16,

  renderWidth : u16,
  renderHeight : u16,

  maxFps : u16,

  pub inline fn targetDt(self:Config) u16 {
    return 1000 / config.maxFps;
  }
};

var renderTexture: ?*c.SDL_Texture = null;
var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;

var config = Config{
  .windowWidth = 800,
  .windowHeight = 600,
  .renderWidth = 800,
  .renderHeight = 600,
  .maxFps = 60
};

pub fn init(cfg:Config) !void 
{
  config = cfg;

    if (c.SDL_Init(c.SDL_INIT_EVERYTHING) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }

    window = c.SDL_CreateWindow(
      "zig-engine", 
      SDL_WINDOWPOS_UNDEFINED, 
      SDL_WINDOWPOS_UNDEFINED, 
      @intCast(c_int, config.windowWidth), 
      @intCast(c_int, config.windowHeight), 
      c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE) // c.SDL_WINDOW_FULLSCREEN_DESKTOP ) //c.SDL_WINDOW_RESIZABLE)
        orelse
        {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse
        {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    
    renderTexture = c.SDL_CreateTexture(
      renderer, 
      c.SDL_PIXELFORMAT_ABGR8888, 
      c.SDL_TEXTUREACCESS_STATIC, 
      @intCast(c_int, config.renderWidth), 
      @intCast(c_int, config.renderHeight)
      );
}

pub fn showMouseCursor(show:u1) u1 {
  return @intCast(u1, c.SDL_ShowCursor(@intCast(c_int, show)));
}

pub inline fn targetFrameTimeMs() u32 {
  return config.targetDt();
}

/// Set Render texture pointer
pub fn updateRenderTexture(data: *u8, len: usize) void {
    var pixelsPtr = @ptrCast(*c_void, data);
    if (c.SDL_UpdateTexture(renderTexture, 0, pixelsPtr, @intCast(c_int, len)) != 0)
        c.SDL_Log("Unable to update texture: %s", c.SDL_GetError());
}

/// Release resources
pub fn shutdown() void {
    common.shutdown();

    c.SDL_DestroyRenderer(renderer);
    c.SDL_DestroyWindow(window);
    c.SDL_Quit();
}

/// Start updating the system
/// returns false when system quit message handled
pub fn beginUpdate() bool 
{
    _= common.beginUpdate();

    t0 = @intCast(u32, c.SDL_GetTicks());

    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event) != 0) 
    {
        switch (event.@"type") 
        {
            c.SDL_QUIT => 
            {
                return false;
            },

            c.SDL_KEYDOWN, c.SDL_KEYUP => 
            {
              const scancode = @enumToInt(event.key.keysym.scancode);
              const keyCode = @intToEnum(input.KeyCode, @intCast(u16, scancode));

              input.setKeyState(keyCode, @intCast(u1, event.key.state));
            },

            c.SDL_MOUSEMOTION => 
            {
              input.setMousePos(event.motion.x, event.motion.y);
            },

            c.SDL_MOUSEBUTTONDOWN => {
              input.setMouseButton(event.button.button, 1);
            },

            c.SDL_MOUSEBUTTONUP => {
              input.setMouseButton(event.button.button, 0);
            },

            else => {},
        }
    }

    return true;
}

/// Copy render texture to device
pub fn renderPresent() void 
{
  _ = c.SDL_RenderClear(renderer);
    if (c.SDL_RenderCopy(renderer, renderTexture, 0, 0) != 0)
        c.SDL_Log("Unable to copy texture: %s", c.SDL_GetError());

    _ = c.SDL_RenderPresent(renderer);
}

/// Stop processing this frame
pub fn endUpdate() u32 
{
    common.endUpdate();

    var t1 = @intCast(u32, c.SDL_GetTicks());
    const dtInt = t1 - t0;
    if (dtInt < config.targetDt())
        c.SDL_Delay((config.targetDt()- dtInt) - 1);

    t0 = t1;

    return dtInt;
}
