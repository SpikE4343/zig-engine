const std = @import("std");
// const trace = @import("../tracy.zig").trace;

const Mutex = std.Thread.Mutex.AtomicMutex;



pub fn Fifo(comptime T: type, comptime sizeType: type) type {
    const maxSize = 1 << @bitSizeOf(sizeType);
    return struct {
        
        const Self = @This();

        pub const Error = error{
            FifoFullError,
            FifoEmptyError,
        };
        

        
        head: sizeType,
        tail: sizeType,
        wait: std.Thread.Semaphore,
        items: [maxSize]T,
        readLock: Mutex,
        writeLock: Mutex,

        pub fn init() Self {
            // list.resize(maxSize);
            var s = Self{
                .head = 0,
                .tail = 0,
                .wait = undefined,
                .items = undefined,
                .readLock = undefined,
                .writeLock = undefined,
            };

            return s;
        }


        pub fn push(self: *Self, node: T) Error!void {
            if( self.isFull() )
                return error.FifoFullError;

            self.writeLock.lock();
            errdefer self.writeLock.unlock();
            // const next = self.head+1;
            // @cmpxchgWeak(sizeType, &self.head, self.head, next, .);
            // const id = self.tail + 1;
            
            //std.debug.warn("push: {}\n",.{std.Thread.getCurrentId()});
            const id = @atomicRmw(sizeType, &self.tail, .Add, 1, .SeqCst);
            

            std.debug.print("[{d}] fifo.push: head=[{d}], tail=[{d}, {d}], s=[{d}], e=[{b}]\n", .{std.Thread.getCurrentId(), self.head, id, self.tail, self.size(), self.isEmpty()});
            self.items[id] = node;
            self.writeLock.unlock();

            self.wait.post();
        }

        pub fn pop(self: *Self) Error!T {
            self.readLock.lock();
            defer self.readLock.unlock();
            
            if(self.isEmpty())
                return error.FifoEmptyError;

            const id = @atomicRmw(sizeType, &self.head, .Add, 1, .SeqCst);
            
            std.debug.print("[{d}]fifo.pop: head=[{d},{d}], tail={d}, s=[{d}], e=[{b}]\n", .{std.Thread.getCurrentId(), id, self.head, self.tail, self.size(), self.isEmpty()});
            return self.items[id];
        }

        pub fn popWait(self: *Self) T {

            // const t = trace(@src());
            // defer t.end();

            var attempts: u16 = 0;
            while (true) {
                
                if (self.isEmpty()) {
                    // const tf = trace(@src());
                    // defer tf.end();
                    self.wait.wait();
                }
                
                var item = self.pop() catch {
                    attempts += 1;
                    continue;
                };

                return item;

                // only wait if the queue is empty
                
            }
        }

        pub fn isEmpty(self: *Self) bool {
            return self.head == self.tail;
        }

        pub fn isFull(self:*Self) bool {
            return (self.tail +% 1) == self.head;
        }

        pub fn size(self:*Self) usize {
            const diff = (self.tail - self.head);
            return if( diff < 0 ) maxSize + diff else diff;
        }
    };
}


//
// Tests
//

test "Fifo" 
{    
    std.debug.print("{d}", .{std.math.pow( usize, 2,@bitSizeOf(u16))});

    // var allocator = std.heap.page_allocator;
    const TestFifo = Fifo(u32, u16); 
    var queue = TestFifo.init();
    var v:u32 = 10;

    try queue.push(v);
    try queue.push(v*v);

    var pj = try queue.pop();

    std.debug.assert(pj == @as(u32,10));
}
