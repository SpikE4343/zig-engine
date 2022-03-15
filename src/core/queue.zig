pub fn InPlaceQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        head: ?*T = null,
        tail: ?*T = null,
        //lock:std.Mutex,
        lock: std.Thread.Mutex,
        wait: std.Thread.Semaphore,
        size: usize,

        pub fn init() Self {
            var s = Self{
                .head = null,
                .tail = null,
                .lock = std.Thread.Mutex{},
                .wait = undefined,
                .size = 0,
            };

            return s;
        }

        pub fn push(self: *Self, node: ?*T) void {
            //std.debug.warn("push: {}\n",.{std.Thread.getCurrentId()});
            const held = self.lock.acquire();
            defer held.release();

            if (self.tail != null)
                self.tail.?.next = node;

            self.tail = node;

            self.size += 1;

            if (self.head == null)
                self.head = self.tail;

            self.wait.post();
        }

        pub fn pop(self: *Self) ?*T {
            const held = self.lock.acquire();
            defer held.release();

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
