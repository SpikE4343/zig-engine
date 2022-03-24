const std = @import("std");
const math = std.math;
// const trace = @import("../tracy.zig").trace;

pub const Job = struct {
    pub const Error = error{JobError};
    pub const Result = enum { Complete, Retry, Abort };

    pub const ExecuteFunc = fn (self: *Job) Error!Result;
    pub const AbortFunc = fn (self: *Job) Error!void;

    executeFn: ExecuteFunc,
    abortFn: AbortFunc,

    // priority: i16,
    // name: []const u8,

    next: ?*Job = null,

    pub fn execute(self: *Job) Error!Result {
        // const ta = trace(@src());
        // defer ta.end();
        return try self.executeFn(self);
    }

    pub fn abort(self: *Job) Error!void {
        try self.abortFn(self);
    }

    pub fn implementor(self: *Job, comptime T: type, comptime field: []const u8) *T {
        return @fieldParentPtr(T, field, self);
    }

    pub fn implement(comptime T: type, e: ExecuteFunc, a: AbortFunc) T {
        return T{
            .job = Job{
                .executeFn = e,
                .abortFn = a,
            },
        };
    }
};

pub fn InPlaceQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        head: ?*T = null,
        tail: ?*T = null,
        //lock:std.Mutex,
        writeLock: std.Thread.Mutex.AtomicMutex,
        readLock: std.Thread.Mutex.AtomicMutex,
        wait: std.Thread.Semaphore,
        size: usize,

        pub fn init() Self {
            var s = Self{
                .head = null,
                .tail = null,
                .writeLock = std.Thread.Mutex.AtomicMutex{},
                .readLock = std.Thread.Mutex.AtomicMutex{},
                .wait = undefined,
                .size = 0,
            };

            return s;
        }

        pub fn push(self: *Self, node: ?*T) void {
            //std.debug.warn("push: {}\n",.{std.Thread.getCurrentId()});
            self.writeLock.lock();
            defer self.writeLock.unlock();

            self.readLock.lock();
            defer self.readLock.unlock();

            if (self.tail != null)
                self.tail.?.next = node;

            self.tail = node;

            self.size += 1;

            if (self.head == null)
                self.head = self.tail;

            self.wait.post();
        }

        pub fn pop(self: *Self) ?*T {
            self.readLock.lock();
            defer self.readLock.unlock();

            var node = self.head orelse return null;
            self.head = self.head.?.next;
            node.next = null;

            self.size -= 1;

            // if(self.head == null)
            //   self.wait.reset();

            return node;
        }

        pub fn popWait(self: *Self) ?*T {

            // const t = trace(@src());
            // defer t.end();

            var attempts: u16 = 0;
            while (true) {
                // const ta = trace(@src());
                // defer ta.end();

                var job = self.pop();
                attempts += 1;

                if (job != null)
                    return job;

                // only wait if the queue is empty
                if (self.head == null) {
                    // const tf = trace(@src());
                    // defer tf.end();
                    self.wait.wait();
                }
            }
        }

        pub fn isEmpty(self: *Self) bool {
            return self.head == null;
        }
    };
}

pub const JobQueue = InPlaceQueue(Job);

pub const Worker = struct {
    pending: *JobQueue,
    thread: std.Thread,
    id: u8,
    active: bool,

    pub fn init(ident: u8, queue: *JobQueue) !Worker {
        var worker = Worker{
            .id = ident,
            .pending = queue,
            .thread = undefined,
            .active = false,
        };

        return worker;
    }

    pub fn start(self: *Worker) !void {
        self.thread = try std.Thread.spawn(.{}, Worker.run, .{self});
    }

    pub fn run(self: *Worker) void {
        self.active = true;
        while (self.active) {
            var job = self.pending.popWait();

            // const ta = trace(@src());
            // defer ta.end();

            const result = job.?.execute() catch unreachable;
            switch (result) {
                .Complete, .Abort => {},
                .Retry => self.pending.push(job.?),
            }
        }
    }

    pub fn stop(self: *Worker) !void {
        self.active = false;
    }
};

/// Group of workers pulling from the same queue
pub const WorkerPool = struct {
    workers: std.ArrayList(Worker),
    queue: *JobQueue,

    pub fn init(queue: *JobQueue, allocator: *std.mem.Allocator, workerCount: u8) !WorkerPool {
        var workers = try std.ArrayList(Worker).initCapacity(allocator.*, workerCount);

        var w = workerCount;
        while (w > 0) {
            defer w -= 1;
            try workers.append(try Worker.init(w, queue));
        }

        return WorkerPool{
            .workers = workers,
            .queue = queue,
        };
    }

    /// Begin all jobs executing off of the queue
    pub fn start(self: *WorkerPool) !void {
        for (self.workers.items) |*w| {
            try w.start();
        }
    }

    pub fn stop(self: *WorkerPool) !void {
        for (self.workers.items) |*w| {
            try w.stop();
        }
    }

    pub fn deinit(self: *WorkerPool) void {
        self.stop();
        self.workers.deinit();
    }
};

//
// Tests
//

pub const TestJob = struct {
    job: Job,
    id: u8,

    pub fn init(ident: u8) TestJob {
        return TestJob{
            .job = Job{
                // .priority = 0,
                // .name = "testjob",
                .executeFn = execute,
                .abortFn = abort,
            },

            .id = ident,
        };
    }

    fn execute(job: *Job) !Job.Result {
        const self = @fieldParentPtr(TestJob, "job", job);
        std.debug.print("\t job: {} execution!\n", .{self.id});
        return Job.Result.Complete;
    }

    fn abort(job: *Job) !void {
        const self = @fieldParentPtr(TestJob, "job", job);
        _ = self;
    }
};

pub const TestJob2 = struct {
    job: Job,

    pub fn init() TestJob2 {
        return Job.implement(TestJob2, execute, abort);
    }

    fn execute(job: *Job) !Job.Result {
        _ = job;
        // const self = @fieldParentPtr(TestJob2, "job", job);
        std.debug.print("execution2!\n", .{});
        return Job.Result.Complete;
    }

    fn abort(job: *Job) !void {
        _ = job;
        // const self = @fieldParentPtr(TestJob2, "job", job);
    }
};

const assert = @import("std").debug.assert;
test "Job Interface Basic Execute" {
    var testjob = TestJob.init(0);
    var job: *Job = &testjob.job;
    _ = try job.execute();
    try job.abort();

    var testjob2 = TestJob2.init();
    job = &testjob2.job;
    _ = try job.execute();
    try job.abort();
}

fn anonExec(self: *Job) !Job.Result {
    std.debug.print("execution anon exec!\n", .{});
    _ = self;
    return Job.Result.Complete;
}

fn anonAbort(self: *Job) !void {
    _ = self;
    std.debug.print("execution anon abort!\n", .{});
}

test "Anonymous Job Interface Basic" {
    var j = Job{
        // .priority = 0,
        // .name = "Anon Job 1",
        .executeFn = anonExec,
        .abortFn = anonAbort,
    };

    var job: *Job = &j;

    _ = try job.execute();
    try job.abort();

    var testjob2 = TestJob2.init();
    job = &testjob2.job;
    _ = try job.execute();
    try job.abort();
}

test "Job Queue" {
    var j = Job{
        // .priority = 0,
        // .name = "Anon Job 1",
        .executeFn = anonExec,
        .abortFn = anonAbort,
    };

    var queue = InPlaceQueue(Job).init();

    var job: *Job = &j;

    queue.push(job);
    var pj = queue.pop();

    assert(pj == job);
    _ = try pj.?.execute();
}

test "Job Workers" {
    var queue = JobQueue.init();

    var workers = [_]Worker{
        try Worker.init(0, &queue),
        try Worker.init(1, &queue),
        try Worker.init(2, &queue),
        try Worker.init(3, &queue),
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

    for (jobs) |j| {
        var job = j.job;
        queue.push(&job);
    }

    for (workers) |*w| {
        try w.start();
    }

    while (!queue.isEmpty())
        std.time.sleep(1_000_000);

    //std.os.sleep(100);
    assert(queue.isEmpty());
}

test "Job Worker Pool" {
    var allocator = std.heap.page_allocator;
    var queue = JobQueue.init();
    var pool = try WorkerPool.init(&queue, allocator, 8);

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

    for (jobs) |j| {
        var job = j.job;
        queue.push(&job);
    }

    try pool.start();

    while (!queue.isEmpty())
        std.time.sleep(1_000_000);

    try pool.stop();
    //std.os.sleep(100);
    assert(queue.isEmpty());
}
