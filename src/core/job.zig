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

pub fn InPlaceQueue(comptime T:type) type {
  return struct {
      const Self = @This();

      head:?*T=null,
      tail:?*T=null,
      lock:std.Mutex,
      wait:std.ResetEvent,
      size:usize,

      pub fn init() Self {
        return Self {
          .head = null,
          .tail = null,
          .lock = std.Mutex{},
          .wait = std.ResetEvent.init(),
          .size = 0,
        };
      } 

      pub fn push(self:*Self, node:*T) void {
        //std.debug.warn("push: {}\n",.{std.Thread.getCurrentId()});
        const held = self.lock.acquire();
        defer held.release();

        if(self.tail != null)
          self.tail.?.next = node;
        
        self.tail = node;

        self.size += 1;

        if(self.head == null)
          self.head = self.tail;

        self.wait.set();
      }

      pub fn pop(self:*Self) ?*T {
        //std.debug.warn("pop: {}, {}\n",.{std.Thread.getCurrentId(), self.lock});
        const held = self.lock.acquire();
        defer held.release();

        var node = self.head orelse return null;
        self.head = self.head.?.next;
        node.next = null;

        self.size -= 1;

        if(self.head == null)
          self.wait.reset();

        return node;
      }

      pub fn popWait(self:*Self) ?*T {
        var attempts:u16 = 0;
        while(true)
        {
          var job = self.pop();
          attempts += 1;
          if(job == null) {
            self.wait.wait();
          } else {
            //std.debug.warn("pop: {}, a:{}, s:{}\n",.{std.Thread.getCurrentId(), attempts, self.size});
            return job;
          }
        }
      }

      pub fn isEmpty(self:*Self) bool {
        return self.head == null;
      }
  };
}

const JobQueue = InPlaceQueue(Job);

pub const JobWorker = struct {
  pending:*JobQueue,
  thread: *std.Thread,
  id:u8,
  active:bool,

  pub fn init(ident:u8, queue:*JobQueue) !JobWorker {
    var worker = JobWorker{
      .id = ident,
      .pending = queue,
      .thread = undefined,
      .active = false, 
    };
    
    return worker;
  }

  pub fn start(self:*JobWorker) !void {
    self.thread = try std.Thread.spawn(self, JobWorker.run);
  }

  pub fn run(self:*JobWorker) void {
    self.active = true;
    while(self.active)
    {
      //std.debug.warn("run: {}, {}\n", .{self.id, std.Thread.getCurrentId()});
      var job = self.pending.popWait();
      job.?.execute() catch unreachable;
      
    }
  }

  pub fn stop() void {
    self.active = false;
  }
};


pub const TestJob = struct {
  job: Job,
  id: u8,

  pub fn init(ident:u8) TestJob {
    return TestJob{
      .job = Job {  
        // .priority = 0,
        // .name = "testjob",
        .executeFn = execute,
        .abortFn = abort,
        },

      .id = ident,
    };
  }

  fn execute(job:*Job) !void {
    const self = @fieldParentPtr(TestJob, "job", job);
    std.debug.warn("\t job: {} execution!\n", .{self.id});
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



test "Job Interface Basic Execute" 
{
  var testjob = TestJob.init(0);
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

test "Job Workers" 
{

  var queue = JobQueue.init();
  
  
  var workers = [_]JobWorker{
    try JobWorker.init(0, &queue),
    try JobWorker.init(1, &queue),
    try JobWorker.init(2, &queue),
    try JobWorker.init(3, &queue),
  };

  const jobs = [_]TestJob{
    TestJob.init(0),
    TestJob.init(1),
    TestJob.init(2),
    TestJob.init(3),
    TestJob.init(4),
    TestJob.init(5),
    TestJob.init(6),
    TestJob.init(7),
  };

  std.time.sleep(1_000_000);
  
  for(jobs) |j| {
    var job = j.job;
    queue.push(&job);
  }

  for(workers) |*w| {
    try w.start();
  }

  while(!queue.isEmpty())
    std.time.sleep(1_000_000);

    //std.os.sleep(100);  
  assert(queue.isEmpty());
}



