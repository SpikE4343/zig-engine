const std = @import("std");
const assert = std.debug.assert;
// const math = std.math;

/// t is 0.0-1.0 and returns from <= result <= to
/// TODO: comptime assert if T is not floating point?
/// TODO: allow integer from/to type and floating point t type
pub fn lerp(comptime T: type, from: T, to: T, t: T) T {
    return (1 - t) * from + t * to;
}

/// from <= v <= to and returns 0.0-1.0
/// TODO: comptime assert if T is not floating point?
/// TODO: allow integer from/to/v type and floating point return type
pub fn invLerp(comptime T: type, from: T, to: T, v: T) T {
    return (v - from) / (to - from);
}

/// Bilinear interpolation
pub fn blerp(comptime T: type, fromx: T, tox: T, fromy: T, toy: T, dx: T, dy: T) T {
    return lerp(lerp(fromx, tox, dx), lerp(fromy, toy, dx), dy);
}

test "Basic Lerp" {
    const v = lerp(f32, 1.0, 2.0, 0.5);
    assert(v == 1.5);

    const v2 = lerp(f64, 1.0, 2.0, 0.5);
    assert(v2 == 1.5);
}

test "Basic Inverse Lerp" {
    const v = invLerp(f32, 1.0, 2.0, 1.5);
    assert(v == 0.5);

    const v2 = invLerp(f64, 1.0, 2.0, 1.5);
    assert(v2 == 0.5);
}
