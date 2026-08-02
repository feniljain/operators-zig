pub const DEFAULT_BATCH_SIZE: u64 = 8192;
pub const DEFAULT_BUILD_SIZE: u64 = 1000;
pub const DEFAULT_PROBE_SIZE: u64 = 1000000;
pub const DEFAULT_BUILD_NDV: u64 = 100;

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

pub fn buildRecordBatch(alloc: Allocator, arr: []u64, fields: []const Field) !RecordBatch {
    const arrRef = try toArrowArrRef(alloc, arr);
    // defer arrRef.release();

    var recordBatchBuilder = try RecordBatchBuilder.initBorrowed(alloc, .{ .fields = fields });
    defer recordBatchBuilder.deinit();

    try recordBatchBuilder.setColumn(0, arrRef);

    return try recordBatchBuilder.finish();
}

// pub const ConactRecordBatch = struct {
//     const targetBatchSize = benchmarks.
//     const Self = @This();
//
//     pub fn init(alloc: Allocator, targetBatchSize) Self {
//         return
//     }
// }

const std = @import("std");
const Allocator = std.mem.Allocator;

const zarrow = @import("zarrow");
const Field = zarrow.Field;
const RecordBatchBuilder = zarrow.RecordBatchBuilder;
const RecordBatch = zarrow.RecordBatch;
const ArrayRef = zarrow.ArrayRef;
