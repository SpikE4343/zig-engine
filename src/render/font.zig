const std = @import("std");
const warn = std.debug.print;
const fmt = std.fmt;
const assert = @import("std").debug.assert;
const math = std.math;

const Vec4f = @import("../core/vector.zig").Vec4f;
const Texture = @import("texture.zig").Texture;

pub const Font = struct {
    glyphWidth: i32,
    glyphHeight: i32,
    texture: Texture,

    pub fn characterY(self: Font, c: u8) i32 {
        return c / @intCast(u8, @divTrunc(self.texture.iwidth, self.glyphWidth));
    }

    pub fn characterX(self: Font, c: u8) i32 {
        return c % @intCast(u8, @divTrunc(self.texture.iwidth, self.glyphWidth));
    }

    pub fn characterColor(self: Font, cx: i32, cy: i32, offsetx: i32, offsety: i32) Vec4f {
        const tx = cx * self.glyphWidth + offsetx;
        const ty = cy * self.glyphHeight + offsety;

        return self.texture.samplePixel(tx, ty);
    }
};

test "Char offset" {
    const twidth = 112;
    const glyphWidth = 7;
    const c: u8 = 'A';

    const gwidth = twidth / glyphWidth;

    const cy = (c / gwidth);
    const cx = (c % gwidth);

    const cty = (c / gwidth) * glyphWidth;
    const ctx = (c % gwidth) * glyphWidth;

    // const offset = cy * glyphWidth + cx;
    std.debug.print("c: {any}, cy: {any}, cx: {any}, cty: {any}, ctx: {any}\n", .{ c, cy, cx, cty, ctx });
}
