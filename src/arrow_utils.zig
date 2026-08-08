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
    var builder = try RecordBatchBuilder.initBorrowed(alloc, first.schema().*);
    defer builder.deinit();

    for (0..first.numColumns()) |colIdx| {
        const mergedArr = try concatArrayRefs(alloc, dataset.buildFields[0].data_type.*, &[_]ArrayRef{ first.column(colIdx).*, second.column(colIdx).* });
        try builder.setColumn(colIdx, mergedArr);
    }

    return try builder.finish();
}

pub const CoalesceBatches = struct {
    targetBatchSize: u64,
    alloc: Allocator,
    resultQueue: Deque(RecordBatch),
    incompleteBatchOpt: ?RecordBatch,

    const Self = @This();

    pub fn init(alloc: Allocator, targetBatchSize: u64) !Self {
        return .{
            .alloc = alloc,
            .targetBatchSize = targetBatchSize,
            .resultQueue = try Deque(RecordBatch).initCapacity(alloc, 10),
            .incompleteBatchOpt = null,
        };
    }

    // - if len is greater than 8192, break into
    // 8192 pieces till it comes down below the 8192.
    // - break loop if exact 0 is left
    // - if len is less than 8192, merge with current stored record
    // till 8192 is reached and then push that to queue.
    // - And finally pop from queue when asked for result
    pub fn push(self: *Self, recordBatch: RecordBatch) !void {
        var batchTrackingIdx: usize = 0;
        const nRows = recordBatch.numRows();
        while(nRows >= self.targetBatchSize) {
            try self.resultQueue.pushBack(self.alloc, try recordBatch.slice(batchTrackingIdx, self.targetBatchSize));
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
            neededRows = self.targetBatchSize - incompleteBatch.numRows();
            if(remainingRows <= neededRows) {
                const batch = try mergeBatches(self.alloc, incompleteBatch, try recordBatch.slice(batchTrackingIdx, remainingRows));
                if(remainingRows == neededRows) {
                    try self.resultQueue.pushBack(self.alloc, batch);
                } else {
                    self.incompleteBatchOpt = batch;
                }
            } else {
                const batch = try mergeBatches(self.alloc, incompleteBatch, try recordBatch.slice(batchTrackingIdx, neededRows));
                try self.resultQueue.pushBack(self.alloc, batch);

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

const deque = @import("deque");
const Deque = deque.Deque;

const dataset = @import("dataset");

const zarrow = @import("zarrow");
const Field = zarrow.Field;
const RecordBatchBuilder = zarrow.RecordBatchBuilder;
const RecordBatch = zarrow.RecordBatch;
const ArrayRef = zarrow.ArrayRef;
const concatArrayRefs = zarrow.concatArrayRefs;
