const std = @import("std");
const utils = @import("utils");

const DEFAULT_BATCH_SIZE: u32 = 8192;
const DEFAULT_BUILD_SIZE: u32 = 1000;
const DEFAULT_PROBE_SIZE: u32 = 1000000;
const DEFAULT_BUILD_NDV: u32 = 100;

pub fn main() !void {
    std.debug.print("Namastey Duniyaa!\n", .{});

    var prng = std.Random.DefaultPrng.init(0x1234_5678_9ABC_DEF0);
    genDataset(prng.random());
}

fn genDataset(rng: std.Random) void { // return array of arrow batches from here
    // generate build side
    // - generate core distinct numbers
    // - expand them to BULID_SIDE size
    // - shuffle
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

    var buildArr = utils.repeatArr(u64, ndv, DEFAULT_BUILD_SIZE, &distinctVals);
    rng.shuffle(u64, &buildArr);

    std.debug.print("Size of build array: {}\n", .{buildArr.len});

    // generate probe side
    // - take core distinct numbers
    // - expand them to PROBE_SIDE size
    // - shuffle

    var probeArr = utils.repeatArr(u64, ndv, DEFAULT_PROBE_SIZE, &distinctVals);
    // rng.shuffle(u64, &probeArr);
    //
    // std.debug.print("Size of probe array: {}", .{probeArr.len});
}

test "simple_nested_loop_join_benchmark" {
    var prng = std.Random.DefaultPrng.init(0x1234_5678_9ABC_DEF0);
    genDataset(prng.random());
}
