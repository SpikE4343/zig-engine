const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const Thread = std.Thread;
const Timer = std.time.Timer;

const SamplePoolCount = 256;
const ThreadPoolCount = 32;

// threadlocal var profiler : ThreadProfile = ThreadProfile{
//         //.id = Thread.getCurrentId(),
//         .nextSample = 0,
//         .depth = 0,
//         .samples = [_]ThreadProfile.Sample{ .{.depth=0, .tag="", .begin=0, .end=0} }** SamplePoolCount,
//       };

/// Track wall clock timing for sub steps (functions) of a single thread
pub const ThreadProfile = struct {
  //id: Thread.Id,
  nextSample : u8,
  depth : u8,
  samples : [SamplePoolCount]Sample,

  /// Single timing block
  pub const Sample = struct {
    depth : u8, 
    tag:[]const u8,
    begin : u64,
    end : u64,
  };


  pub fn init() ThreadProfile {
    return ThreadProfile{
        //.id = Thread.getCurrentId(),
        .nextSample = 1,
        .depth = 0,
        .samples = [_]ThreadProfile.Sample{ .{.depth=0, .tag="", .begin=0, .end=0} }** SamplePoolCount,
      };
  }

  /// Start tracking wall clock time
  pub fn beginSample(self:*ThreadProfile, tag:[]const u8) u32 {    
    const id = @atomicRmw(u8, &self.nextSample, .Add, 1, .SeqCst);
    assert(id < self.samples.len);

    var sample = &self.samples[id];

    sample.depth = @atomicRmw(u8, &self.depth, .Add, 1, .SeqCst);
    sample.tag = tag;
    var timer = Timer.start() catch return id;
    sample.begin = timer.start_time;
    return id;
  }

  // Stop tracking wall clock timing
  pub fn endSample(self:*ThreadProfile, id:u32) void {
    const d = @atomicRmw(u8, &self.depth, .Sub, 1, .SeqCst);
    var timer = Timer.start() catch |e| return;
    self.samples[id].end = timer.start_time;
  }

  pub fn reset(self:*ThreadProfile) void {
    self.depth = 0;
    self.nextSample = 1;
  }

  pub fn print(self:*ThreadProfile) void {
    for(self.samples) |sample, i| {
      if( i != 0 and sample.begin != 0)
        {
          var s = sample.depth;
          while(s > 0) 
          {
            std.debug.warn("\t", .{});
            s -= 1;
          }
          
          std.debug.warn("[{}:{}] b:{}, e:{}, d:{}, t:{}\n", .{
           i,
           sample.depth, 
           sample.begin, 
           sample.end, 
           sample.end-sample.begin,
           sample.tag
          });
        }
    }
  }
};

pub const Sampler = struct {
  id:u32,
  owner: *ThreadProfile,

  
  pub fn begin(profiler: *ThreadProfile, tag:[]const u8) Sampler {
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
        //.id = Thread.getCurrentId(),
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
