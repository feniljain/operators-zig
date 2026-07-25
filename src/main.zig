pub fn main() !void {
    const smp_allocator: Allocator = .{
        .ptr = undefined,
        .vtable = &SmpAllocator.vtable,
    };

    var prng = std.Random.DefaultPrng.init(0x1234_5678_9ABC_DEF0);
    const result = try benchmark.genDataset(smp_allocator, prng.random());

    std.debug.print("Size of build record batch: {}\n", .{result.build.numRows()});
    std.debug.print("Size of probe record batch: {}\n", .{result.probe.numRows()});

    // nestedLoopJoin();
}

// fn nestedLoopJoin() {}

const std = @import("std");
const SmpAllocator = std.heap.SmpAllocator;
const Allocator = std.mem.Allocator;

const benchmark = @import("benchmark");

const zarrow = @import("zarrow");
const RecordBatch = zarrow.RecordBatch;
