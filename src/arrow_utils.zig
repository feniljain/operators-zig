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

pub fn mergeBatches(alloc: Allocator, first: RecordBatch, second: RecordBatch) !RecordBatch {
    const schemaRef = try SchemaRef.fromBorrowed(alloc, (first.schema()).*);
    var builder = try RecordBatchBuilder.initBorrowed(alloc, schemaRef);
    defer builder.deinit();

    for (0..first.numColumns()) |colIdx| {
        const mergedArr = try concatArrayRefs(first.column(colIdx), second.column(colIdx));
        builder.setColumn(colIdx, mergedArr);
    }

    return try builder.finish();
}

pub const CoalesceBatches = struct {
    targetBatchSize: u64,
    alloc: Allocator,
    resultQueue: Deque,
    incompleteBatchOpt: ?RecordBatch,

    const Self = @This();

    pub fn init(alloc: Allocator, targetBatchSize: u64) Self {
        return .{
            .alloc = alloc,
            .targetBatchSize = targetBatchSize,
            .resultQueue = Deque.initCapacity(alloc, 10),
            .incompleteBatchOpt = null,
        };
    }

    // - if len is greater than 8192, break into
    // 8192 pieces till it comes down below the 8192.
    // - break loop if exact 0 is left
    // - if len is less than 8192, merge with current stored record
    // till 8192 is reached and then push that to queue.
    // - And finally pop from queue when asked for result
    pub fn registerRecordBatch(self: *Self, recordBatch: RecordBatch) !void {
        var batchTrackingIdx = 0;
        const nRows = recordBatch.numRows();
        while(nRows >= self.targetBatchSize) {
            self.resultQueue.pushBack(try recordBatch.slice(batchTrackingIdx, self.targetBatchSize));
            batchTrackingIdx += self.targetBatchSize;
        }

        // we have exhausted record batch
        const remainingRows = nRows - batchTrackingIdx;
        if(remainingRows == 0) {
            return;
        }

        // if incomplete batch is not present, current record batch becomes the one
        var neededRows = remainingRows;
        if (self.incompleteBatchOpt) |incompleteBatch| {
            neededRows = self.targetBatchSize - self.incompleteBatchOpt.numRows();
            if(remainingRows <= neededRows) {
                const batch = try mergeBatches(self.alloc, incompleteBatch, try recordBatch.slice(batchTrackingIdx, remainingRows));
                if(remainingRows == neededRows) {
                    self.resultQueue.pushBack(batch);
                } else {
                    self.incompleteBatchOpt = batch;
                }
            } else {
                const batch = try mergeBatches(self.alloc, incompleteBatch, try recordBatch.slice(batchTrackingIdx, neededRows));
                self.resultQueue.pushBack(batch);

                batchTrackingIdx += neededRows;
                self.incompleteBatchOpt = try recordBatch.slice(batchTrackingIdx, remainingRows - neededRows);
            }
        }
    }

    // pub fn next(self: *Self) !?RecordBatch {
    // }
};

const std = @import("std");
const Allocator = std.mem.Allocator;

const Deque = @import("deque");

const zarrow = @import("zarrow");
const Field = zarrow.Field;
const RecordBatchBuilder = zarrow.RecordBatchBuilder;
const RecordBatch = zarrow.RecordBatch;
const ArrayRef = zarrow.ArrayRef;
const concatArrayRefs = zarrow.concatArrayRefs;
const SchemaRef = zarrow.SchemaRef;
