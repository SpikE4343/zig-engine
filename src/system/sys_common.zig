const std = @import("std");
const KeyCode = @import("sys_input.zig").KeyCode;
const warn = std.debug.print;
const fmt = std.fmt;

pub fn init(windowWidth: u16, windowHeight: u16, renderWidth: u16, renderHeight: u16) !void {
    _ = windowWidth;
    _ = windowHeight;
    _ = renderWidth;
    _ = renderHeight;
}

pub fn shutdown() void {}

pub fn beginUpdate() bool {
    return true;
}

pub fn endUpdate() void {}
