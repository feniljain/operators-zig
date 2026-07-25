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
    }

    const buildArr = try utils.repeatArr(alloc, u64, DEFAULT_BUILD_SIZE, &distinctVals);
    rng.shuffle(u64, buildArr);

    var buildArrRef = try utils.toArrowArrRef(alloc, buildArr);
    defer buildArrRef.release();

    const buildArrowArr = zarrow.UInt64Array{ .data = buildArrRef.data() };

    std.debug.print("Size of build arrow array: {}\n", .{buildArrowArr.len()});

    const probeArr = try utils.repeatArr(alloc, u64, DEFAULT_PROBE_SIZE, &distinctVals);
    rng.shuffle(u64, probeArr);

    var probeArrRef = try utils.toArrowArrRef(alloc, probeArr);
    defer probeArrRef.release();

    const probeArrowArr = zarrow.UInt64Array{ .data = probeArrRef.data() };

    std.debug.print("Size of probe arrow array: {}\n", .{probeArrowArr.len()});
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
