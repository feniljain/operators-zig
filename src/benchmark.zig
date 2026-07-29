const DEFAULT_BATCH_SIZE: u64 = 8192;
const DEFAULT_BUILD_SIZE: u64 = 1000;
const DEFAULT_PROBE_SIZE: u64 = 1000000;
const DEFAULT_BUILD_NDV: u64 = 100;

pub const ProbeRecordBatchIter = struct {
    masterBatch: RecordBatch,
    trackingIdx: usize,

    const Self = @This();

    pub fn init(alloc: Allocator, probeArr: []u64) !Self {
        return .{ .masterBatch = try buildRecordBatch(alloc, probeArr, &probeFields), .trackingIdx = 0 };
    }

    pub fn next(self: *Self) !?RecordBatch {
        const startIdx = self.trackingIdx;
        const masterBatchLen = self.masterBatch.numRows();

        if(self.trackingIdx == masterBatchLen) {
            return null;
        }

        const endIdx = self.trackingIdx + DEFAULT_BATCH_SIZE;
        if(endIdx > masterBatchLen) {
            const remainingLen = masterBatchLen - self.trackingIdx;
            self.trackingIdx = masterBatchLen;
            return try self.masterBatch.slice(startIdx, remainingLen);
        }

        self.trackingIdx += DEFAULT_BATCH_SIZE;
        return try self.masterBatch.slice(startIdx, DEFAULT_BATCH_SIZE);
    }
};

pub fn toArrowArrRef(
    alloc: Allocator,
    arr: []u64
) !zarrow.ArrayRef {
    var builder = try zarrow.UInt64Builder.init(alloc, arr.len);
    defer builder.deinit();

    for(arr) |ele| {
        try builder.append(ele);
    }

    return try builder.finish();
}

pub const buildFields = [_]Field{
    .{ .name = "a", .data_type = &uint64Type, .nullable = false },
};

pub const probeFields = [_]Field{
    .{ .name = "a", .data_type = &uint64Type, .nullable = false },
};

fn buildRecordBatch(alloc: Allocator, arr: []u64, fields: []const Field) !RecordBatch {
    const arrRef = try toArrowArrRef(alloc, arr);
    // defer arrRef.release();

    var recordBatchBuilder = try RecordBatchBuilder.initBorrowed(alloc, .{ .fields = fields });
    defer recordBatchBuilder.deinit();

    try recordBatchBuilder.setColumn(0, arrRef);

    return try recordBatchBuilder.finish();
}

pub const GenDatasetResult = struct {
    build: RecordBatch,
    probeIter: ProbeRecordBatchIter,
};

pub fn genDataset(alloc: Allocator, rng: std.Random) !GenDatasetResult {
    const ndv = DEFAULT_BUILD_NDV;

    var distinctVals = utils.genRandomArray(rng, u64, ndv);
    const max_u64: u64 = std.math.maxInt(u64);

    for(0..distinctVals.len) |idx|  {
        if (distinctVals[idx] > max_u64) {
            distinctVals[idx] = distinctVals[idx] % max_u64;
        }
    }

    const buildArr = try utils.repeatArr(alloc, u64, DEFAULT_BUILD_SIZE, &distinctVals);
    rng.shuffle(u64, buildArr);

    const probeArr = try utils.repeatArr(alloc, u64, DEFAULT_PROBE_SIZE, &distinctVals);
    rng.shuffle(u64, probeArr);

    const probeIter = try ProbeRecordBatchIter.init(alloc, probeArr);

    return .{ .build = try buildRecordBatch(alloc, buildArr, &buildFields), .probeIter = probeIter };
}

test "genDatasetSimple" {
    const smp_allocator: Allocator = .{
        .ptr = undefined,
        .vtable = &SmpAllocator.vtable,
    };

    var prng = std.Random.DefaultPrng.init(0x1234_5678_9ABC_DEF0);
    const result = try genDataset(smp_allocator, prng.random());

    try expect(result.build.numRows() == DEFAULT_BUILD_SIZE);
    try expect(result.probe.numRows() == DEFAULT_PROBE_SIZE);
}

const std = @import("std");
const SmpAllocator = std.heap.SmpAllocator;
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;

const utils = @import("utils");

const zarrow = @import("zarrow");
const Field = zarrow.Field;
const RecordBatchBuilder = zarrow.RecordBatchBuilder;
const RecordBatch = zarrow.RecordBatch;
const ArrayRef = zarrow.ArrayRef;
const uint64Type = zarrow.DataType{ .uint64 = {} };
