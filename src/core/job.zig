const std = @import("std");
const math = std.math;
const interp = @import("interp.zig");


pub const Job = struct {
  pub const Error = error{JobError};

  pub const ExecuteFunc = fn (self:*Job) Error!void;
  pub const AbortFunc = fn (self:*Job) Error!void;

  executeFn: ExecuteFunc,
  abortFn: AbortFunc,
  
  // priority: i16,
  // name: []const u8,

  next: ?*Job = null,


  pub fn execute(self:*Job) Error!void {
    try self.executeFn(self);
  }

  pub fn abort(self:*Job) Error!void {
    try self.abortFn(self);
  }

  pub fn implement(comptime T:type, e:ExecuteFunc, a:AbortFunc) T {
    return T{
      .job = Job{
        .executeFn = e,
        .abortFn = a,
      },
    };
  }
};

pub const TestJob = struct {
  job: Job,

  pub fn init() TestJob {
    return TestJob{
      .job = Job{
        // .priority = 0,
        // .name = "testjob",
        .executeFn = execute,
        .abortFn = abort,
      },
    };
  }

  fn execute(job:*Job) !void {
    const self = @fieldParentPtr(TestJob, "job", job);
    std.debug.warn("execution!\n", .{});
  }

  fn abort(job:*Job) !void {
    const self = @fieldParentPtr(TestJob, "job", job);
  }
};


pub const TestJob2 = struct {
  job: Job,

  
  pub fn init() TestJob2 {
    return Job.implement(
      TestJob2, 
      execute,
      abort
    );
  }


  fn execute(job:*Job) !void {
    const self = @fieldParentPtr(TestJob2, "job", job);
    std.debug.warn("execution2!\n", .{});
  }

  fn abort(job:*Job) !void {
    const self = @fieldParentPtr(TestJob2, "job", job);
  }
};

const assert = @import("std").debug.assert;

pub fn InPlaceQueue(comptime T:type) type {
  return struct {
      const Self = @This();

      head:?*T=null,
      tail:?*T=null,

      pub fn init() Self {
        return Self {
          .head = null,
          .tail = null,
        };
      } 

      pub fn push(self:*Self, node:*T) !void {
        if(self.tail != null)
          self.tail.?.next = node;
          
        self.tail = node;
        if(self.head == null)
          self.head = self.tail;
      }

      pub fn pop(self:*Self) !?*T {
        var node = self.head orelse return null;
        self.head = self.head.?.next;
        node.next = null;
        return node;
      }

      pub fn isEmpty(self:Self) bool {
        return self.head == null;
      }
  };
}

var head:*Job;
var tail: *Job;

test "Job Interface Basic Execute" 
{
  var testjob = TestJob.init();
  var job:*Job = &testjob.job;
  try job.execute();
  try job.abort();


  var testjob2 = TestJob2.init();
  job = &testjob2.job;
  try job.execute();
  try job.abort();
}

fn anonExec(self:*Job) !void {
  std.debug.warn("execution anon exec!\n", .{});
}

fn anonAbort(self:*Job) !void {
  std.debug.warn("execution anon abort!\n", .{});
}

test "Anonymous Job Interface Basic" 
{
  var j = Job{
    // .priority = 0,
    // .name = "Anon Job 1",
    .executeFn = anonExec,
    .abortFn = anonAbort,
  };

  var job:*Job = &j;

  try job.execute();
  try job.abort();


  var testjob2 = TestJob2.init();
  job = &testjob2.job;
  try job.execute();
  try job.abort();
}

test "Job Queue" 
{
  var j = Job{
    // .priority = 0,
    // .name = "Anon Job 1",
    .executeFn = anonExec,
    .abortFn = anonAbort,
  };

  var queue = InPlaceQueue(Job).init();

  var job:*Job = &j;

  queue.push(job);
  var pj = queue.pop();

  assert(pj == job);
  try pj.?.execute();
}



