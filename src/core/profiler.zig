const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const Thread = std.thread.Thread;
const Timer = std.time.Timer;

const SamplePoolCount = 256;
const ThreadPoolCount = 32;


const Sample = struct {
  tag:[]const u8,
  begin : u64,
  end : u64,
};

const ThreadProfile = struct {
  topId : std.atomic.Int(u32),
  samples : [SamplePoolCount]Sample,
  pub fn beginSample(tag:[]const u8) u32 {
    var id = topId.incr();
  }
};

/// Sample system time at init and again when out of scope
pub const Profiler = struct 
{
  //assert(SamplePoolCount < @exp2(@bitSizeOf(SamplePoolCount));

  description: []const u8,
  threadId: Thread.Id,
  beginNs: u64,
  endNs: u64,
  parentId: u32,

  pub fn start(tag:[]const u8) *Profiler {

    const id = topId.incr();
    assert(id < SamplePoolCount);
    var sample = samples[id];
    sample.parentId = id;
    sample.start();
    return sample;
  }

  pub fn start(self:*Profiler) void {
    self.beginNs = Timer.clockNative();
    self.threadId = Thread.getCurrentId();
    self.endNs = 0;
  }

  pub fn stop(self:*Profiler) void {
    self.endNs = Timer.clockNative();
    const id = topId.decr();
  }

  pub fn restart() void 
  {
    nextId.set(0);
  }
};

test "Profiler.init" 
{
  var prof = Profiler.init("test1");

  assert(prof.id)
}


test "Vec4f.set" 
{
    var lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    const rhs = Vec4f.init(2.0, 3.0, 4.0, 1.0);
    lhs.set(rhs);

    assert_f32_equal(lhs.x, rhs.x);
    assert_f32_equal(lhs.y, rhs.y);
    assert_f32_equal(lhs.z, rhs.z);
    assert_f32_equal(lhs.w, rhs.w);
}

test "Vec4f.normalize" 
{
    var lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    lhs.normalize();
    assert_f32_equal(lhs.length(), 1.0);
}

test "Vec4f.normalized" 
{
    const lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    const lhsLen = lhs.length();
    const normal = lhs.normalized();
    assert_f32_equal(normal.length(), 1.0);
    assert_f32_equal(lhs.length(), lhsLen);
}

test "Vec4f.lengthSqr" 
{
    const lhs = Vec4f.init(1.0, 2.0, 3.0, 1.0);
    const len = lhs.length();
    const sqr = lhs.lengthSqr();
    assert_f32_equal(sqr, len * len);
}