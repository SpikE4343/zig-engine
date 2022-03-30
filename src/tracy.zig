pub const std = @import("std");
const builtin = @import("builtin");

pub const enable = true; //if (builtin.is_test) false else @import("build_options").enable_tracy;

extern fn ___tracy_emit_zone_begin_callstack(
    srcloc: *const ___tracy_source_location_data,
    depth: c_int,
    active: c_int,
) ___tracy_c_zone_context;

extern fn ___tracy_emit_zone_end(ctx: ___tracy_c_zone_context) void;

extern fn ___tracy_emit_frame_mark(name:?[*:0]const u8) void;

extern fn ___tracy_emit_plot(name:?[*:0]const u8, value:c_longdouble) void;

pub const ___tracy_source_location_data = extern struct {
    name: ?[*:0]const u8,
    function: [*:0]const u8,
    file: [*:0]const u8,
    line: u32,
    color: u32,
};

pub const ___tracy_c_zone_context = extern struct {
    id: u32,
    active: c_int,

    pub fn end(self: ___tracy_c_zone_context) void {
        ___tracy_emit_zone_end(self);
    }
};

pub const Ctx = if (enable) ___tracy_c_zone_context else struct {
    pub fn end(self: Ctx) void {
        _ = self;
    }
};

pub inline fn trace(comptime src: std.builtin.SourceLocation) Ctx {
    if (!enable) return .{};

    const loc: ___tracy_source_location_data = .{
        .name = null,
        .function = src.fn_name.ptr,
        .file = src.file.ptr,
        .line = src.line,
        .color = 0,
    };
    return ___tracy_emit_zone_begin_callstack(&loc, 1, 1);
}


pub inline fn markFrame() void {
    ___tracy_emit_frame_mark(null);
}

pub inline fn plotValue(name:[*c]const u8, value:anytype) void {
    switch (@typeInfo(@TypeOf(value))) {
        .Int, .ComptimeInt =>  {
            ___tracy_emit_plot(name, @intToFloat(f64, value));
        },
        .Float, .ComptimeFloat => if (@floatCast(f64, value) == value) {
            ___tracy_emit_plot(name, @floatCast(f64, value));
        },
        else => {},
    }
}
