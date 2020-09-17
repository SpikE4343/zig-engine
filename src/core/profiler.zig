const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const Thread = std.Thread;
const Timer = std.time.Timer;
const File = std.fs.File;

// TODO: make these parameters compile time, like generics
const SamplePoolCount = 2048;
const ThreadPoolCount = 32;

/// Track wall clock timing for sub steps (functions) of a single thread
pub const Profile = struct {
  nextSample : u16,
  depth : u8,
  samples : [SamplePoolCount]Sample,
  frameCount : u32,
  frameStartTime : u64,

  /// Single timing block
  pub const Sample = struct {
    depth : u8, 
    tag:[]const u8,
    begin : u64,
    end : u64,
  };


  pub fn init() Profile {
    return Profile{
        .nextSample = 1,
        .depth = 0,
        .frameCount = 0,
        .frameStartTime = 0,
        .samples = [_]Profile.Sample{ .{.depth=0, .tag="", .begin=0, .end=0} }** SamplePoolCount,
      };
  }

  /// Start tracking wall clock time
  pub fn beginSample(self:*Profile, tag:[]const u8) u32 {    
    const id = @atomicRmw(u16, &self.nextSample, .Add, 1, .SeqCst);
    assert(id < self.samples.len);

    var sample = &self.samples[id];

    sample.depth = @atomicRmw(u8, &self.depth, .Add, 1, .SeqCst);
    sample.tag = tag;
    //TODO: find out how to correctly handle a timer error here
    var timer = Timer.start() catch return id;
    sample.begin = timer.start_time;
    return id;
  }

  // Stop tracking wall clock timing
  pub fn endSample(self:*Profile, id:u32) void {
    const d = @atomicRmw(u8, &self.depth, .Sub, 1, .SeqCst);

    //TODO: find out how to correctly handle a timer error here
    var timer = Timer.start() catch |e| return;
    self.samples[id].end = timer.start_time;
  }

  /// Reset profile data for a new frame
  pub fn nextFrame(self:*Profile) void {
    self.depth = 0;
    self.nextSample = 1;
    self.frameCount += 1;

    //TODO: find out how to correctly handle a timer error here
    var timer = Timer.start() catch |e| return;
    self.frameStartTime = timer.start_time;
  }

  pub fn streamPrint(self:*Profile, file:File ) !void {
    var stream = file.outStream();
    try stream.print("f:{}, sc:{}\n", .{self.frameCount, self.nextSample});

    for(self.samples) |sample, i| 
    {
      if( i == 0 or sample.begin == 0)
        continue;
      
      var s = sample.depth;
      while(s > 0) 
      {
        try stream.print(" ", .{});
        s -= 1;
      }
      
      const begin = sample.begin - self.frameStartTime;
      const end = sample.end - self.frameStartTime;
      try stream.print("[{}:{}] b:{} ns, e:{} ns, d:{} ns, t:{}\n", .{
        i,
        sample.depth, 
        begin, 
        end, 
        end-begin,
        sample.tag
      });
    }
  }
};

pub const Sampler = struct {
  id:u32,
  owner: *Profile,
  
  pub fn begin(profiler: *Profile, tag:[]const u8) Sampler {
    return Sampler {
      .owner = profiler,
      .id = profiler.beginSample(tag),
    };
  }

  pub fn end(self:*Sampler) void {
    self.owner.endSample(self.id);
  }
};


test "Profiler.init" 
{
  var profiler = ThreadProfile{
        .id = Thread.getCurrentId(),
        .nextSample = 1,
        .depth = 0,
        .samples = [_]ThreadProfile.Sample{ .{.depth=0, .tag="", .begin=0, .end=0} }** SamplePoolCount,
      };
  {
    var sampleA = profiler.beginSample("A");
    defer profiler.endSample(sampleA);
    
    var i:u16 = 0;
    while(i < 10) {
      var sampleB = profiler.beginSample("B"); 
      defer profiler.endSample(sampleB);
      i += 1;
    }
  } 

  std.debug.warn("\n",.{});
  profiler.print();
}
