pub fn main() !void {
    const alloc: Allocator = .{
        .ptr = undefined,
        .vtable = &SmpAllocator.vtable,
    };

    var prng = std.Random.DefaultPrng.init(0x1234_5678_9ABC_DEF0);
    var dataset = try datasetMod.genDataset(alloc, prng.random());
    try nestedLoopJoin(alloc, &dataset);
}

fn mergeSchemas(alloc: Allocator, buildFields: []const Field, probeFields: []const Field, probeJoinColIdx: u32) ![]Field {
    // -1 cause join column is repeated in both
    var resultFields: []Field = try alloc.alloc(Field, buildFields.len + probeFields.len - 1);

    for(0..buildFields.len) |idx| {
        resultFields[idx] = buildFields[idx];
    }

    for(buildFields.len..probeFields.len) |idx| {
        // do not include join column from probe side
        if((idx - buildFields.len) != probeJoinColIdx) {
            resultFields[idx] = probeFields[(idx - buildFields.len)];
        }
    }

    return resultFields;
}

// Inner Join Nested Loop Join
//
// Datafusion:
//
// points:
// - all build side batches are in memory
// - probe side is streamed until threshold is reached
//
// process:
// - create a bitmap of selected results
// - remove all the unwanted rows using filter bitmap
// - copy all the required columns into a new batch
// - return when you hit configured record batch size
fn nestedLoopJoin(alloc: Allocator, dataset: *GenDatasetResult) !void {
    const resultFields = try mergeSchemas(alloc, &datasetMod.buildFields, &datasetMod.probeFields, 0);

    var coalesceBatches = try CoalesceBatches.init(alloc, DEFAULT_BATCH_SIZE);

    const buildJoinCol = PrimitiveArray(u64){ .data = dataset.build.column(0).data() };
    var validIndices = [_]usize{0} ** DEFAULT_BATCH_SIZE;
    while(try dataset.probeIter.next()) |probeBatch| {
        const probeJoinCol = PrimitiveArray(u64){ .data = probeBatch.column(0).data() };

        for(try buildJoinCol.values(), 0..buildJoinCol.len()) |buildVal, buildIdx| {
            var resultBatchBuilder = try RecordBatchBuilder.initBorrowed(alloc, .{ .fields = resultFields });
            defer resultBatchBuilder.deinit();

            var validIndicesIdx: usize = 0;

            for(try probeJoinCol.values(), 0..probeJoinCol.len()) |probeVal, probeIdx| {
                if(std.meta.eql(buildVal, probeVal)) {
                    validIndices[validIndicesIdx] = probeIdx;
                    validIndicesIdx += 1;
                }
            }

            for(0..dataset.build.numColumns()) |colIdx| {
                var arr = try UInt64Builder.init(alloc, DEFAULT_BATCH_SIZE);
                const col = PrimitiveArray(u64){ .data = dataset.build.column(colIdx).data() };
                const val = try col.value(buildIdx);
                for(0..DEFAULT_BATCH_SIZE) |_| {
                    try arr.append(val);
                }

                try resultBatchBuilder.setColumn(colIdx, try arr.finish());
            }

            // TODO(feniljain): make record batch collector and concat batches to
            // serve them with DEFAULT_BATCH_SIZE over an iterator
            //
            // const resultBatch = try resultBatchBuilder.finish();
            // const aCol = PrimitiveArray(u64){ .data = resultBatch.column(0).data() };
            // for(0..aCol.len()) |idx| {
            //     std.debug.print("{any} ", .{aCol.value(idx)});
            // }
            // std.debug.print("\n-----\n", .{});

            // if we have filled all the columns already, return
            if (resultFields.len == dataset.build.numColumns()) {
                continue;
            }

            var resultColIdx = dataset.build.numColumns();
            for(0..probeBatch.numColumns()) |colIdx| {
                const col: ArrayRef = (probeBatch.column(colIdx)).*;
                const datum = Datum.fromArray(col);
                const filteredDatum = try computeDatumTake(datum, &validIndices);
                try resultBatchBuilder.setColumn(resultColIdx, filteredDatum.asArray() orelse unreachable);
                resultColIdx += 1;
            }

            try coalesceBatches.push(try resultBatchBuilder.finish());
        }
    }
}

const std = @import("std");
const SmpAllocator = std.heap.SmpAllocator;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const datasetMod = @import("dataset");
const GenDatasetResult = datasetMod.GenDatasetResult;

const arrowUtils = @import("arrow_utils");
const DEFAULT_BATCH_SIZE = arrowUtils.DEFAULT_BATCH_SIZE;
const CoalesceBatches = arrowUtils.CoalesceBatches;

const zarrow = @import("zarrow");
const RecordBatch = zarrow.RecordBatch;
const Schema = zarrow.Schema;
const Field = zarrow.Field;
const MutableValidityBitmap = zarrow.MutableValidityBitmap;
const Datum = zarrow.ComputeDatum;
const computeDatumTake = zarrow.computeDatumTake;
const PrimitiveBuilder = zarrow.PrimitiveBuilder;
const RecordBatchBuilder = zarrow.RecordBatchBuilder;
const PrimitiveArray = zarrow.PrimitiveArray;
const UInt64Builder = zarrow.UInt64Builder;
const ArrayRef = zarrow.ArrayRef;
