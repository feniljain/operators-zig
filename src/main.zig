const DEFAULT_BATCH_SIZE: u64 = 8192;
const DEFAULT_BUILD_SIZE: u64 = 1000;
const DEFAULT_PROBE_SIZE: u64 = 1000000;
const DEFAULT_BUILD_NDV: u64 = 100;

pub fn main() !void {
    const smp_allocator: Allocator = .{
        .ptr = undefined,
        .vtable = &SmpAllocator.vtable,
    };

    std.debug.print("Namastey Duniyaa!\n", .{});

    var prng = std.Random.DefaultPrng.init(0x1234_5678_9ABC_DEF0);
    try genDataset(smp_allocator, prng.random());
}

// TODO(feniljain): return batches from arrow from here
fn genDataset(alloc: Allocator, rng: std.Random) !void {
    const ndv = DEFAULT_BUILD_NDV;

    var distinctVals = utils.genRandomArray(rng, u64, ndv);
    const max_u64: u64 = std.math.maxInt(u64);

    for (0..distinctVals.len) |idx|  {
        if (distinctVals[idx] > max_u64) {
            distinctVals[idx] = distinctVals[idx] % max_u64;
        }

        std.debug.print("{} ", .{distinctVals[idx]});
    }

    std.debug.print("\n", .{});

    const buildArr = try utils.repeatArr(alloc, u64, DEFAULT_BUILD_SIZE, &distinctVals);
    rng.shuffle(u64, buildArr);

    std.debug.print("Size of build array: {}\n", .{buildArr.len});

    const probeArr = try utils.repeatArr(alloc, u64, DEFAULT_PROBE_SIZE, &distinctVals);
    rng.shuffle(u64, probeArr);

    std.debug.print("Size of probe array: {}\n", .{probeArr.len});

    // =========
    var builder = try zarrow.Int32Builder.init(std.heap.page_allocator, 3);
    defer builder.deinit();

    try builder.append(10);
    try builder.appendNull();
    try builder.append(30);

    var arr_ref = try builder.finish();
    defer arr_ref.release();

    const arr = zarrow.Int32Array{ .data = arr_ref.data() };

    std.debug.print("len={d}, v0={d}, isNull1={any}, v2={d}\n", .{
        arr.len(),
        try arr.value(0),
        arr.isNull(1),
        try arr.value(2),
    });
    // =========
}

test "simple_nested_loop_join_benchmark" {
    const smp_allocator: Allocator = .{
        .ptr = undefined,
        .vtable = &SmpAllocator.vtable,
    };

    var prng = std.Random.DefaultPrng.init(0x1234_5678_9ABC_DEF0);
    try genDataset(smp_allocator, prng.random());
}

const std = @import("std");
const SmpAllocator = std.heap.SmpAllocator;
const Allocator = std.mem.Allocator;

const utils = @import("utils");
const zarrow = @import("zarrow");
