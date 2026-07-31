// pub const MergedFieldsAndArrResult = struct {
//     fields: []Field,
//     arrs: [][],
// };

pub fn main() !void {
    const alloc: Allocator = .{
        .ptr = undefined,
        .vtable = &SmpAllocator.vtable,
    };

    var prng = std.Random.DefaultPrng.init(0x1234_5678_9ABC_DEF0);
    // TODO(feniljian): make this generate 8192 rows and keep feeding in
    // to join algo
    var result = try benchmark.genDataset(alloc, prng.random());

    std.debug.print("Size of build record batch: {}\n", .{result.build.numRows()});

    const resultFields = try mergeSchemas(alloc, &benchmark.buildFields, &benchmark.probeFields, 0);
    // std.debug.print("DEBUG::fields::{any}\n", .{fields});

    const buildJoinCol = PrimitiveArray(u64){ .data = result.build.column(0).data() };

    var validIndices = [_]usize{0} ** benchmark.DEFAULT_BATCH_SIZE;
    var validIndicesIdx: usize = 0;
    while(try result.probeIter.next()) |probeBatch| {
        std.debug.print("Size of probe record batch: {}\n", .{probeBatch.numRows()});
        const probeJoinCol = PrimitiveArray(u64){ .data = probeBatch.column(0).data() };

        var resultBatchBuilder = try RecordBatchBuilder.initBorrowed(alloc, .{ .fields = resultFields });
        defer resultBatchBuilder.deinit();

        for(try buildJoinCol.values(), 0..buildJoinCol.len()) |buildVal, buildIdx| {
            for(try probeJoinCol.values(), 0..probeJoinCol.len()) |probeVal, probeIdx| {
                if(std.meta.eql(buildVal, probeVal)) {
                    validIndices[validIndicesIdx] = probeIdx;
                    validIndicesIdx += 1;
                }
            }

            for(0..result.build.numColumns()) |colIdx| {
                var arr = try UInt64Builder.init(alloc, benchmark.DEFAULT_BATCH_SIZE);
                const col = PrimitiveArray(u64){ .data = result.build.column(colIdx).data() };
                const val = try col.value(buildIdx);
                for(0..benchmark.DEFAULT_BATCH_SIZE) |_| {
                    try arr.append(val);
                }

                try resultBatchBuilder.setColumn(colIdx, try arr.finish());
            }

            var resultColIdx = result.build.numColumns();
            for(0..probeBatch.numColumns()) |colIdx| {
                const col = probeBatch.column(colIdx);
                const datum = ComputeDatum.fromArray(*col);
                const filteredDatum = try computeDatumTake(datum, validIndices);
                try resultBatchBuilder.setColumn(resultColIdx, filteredDatum.asArray() orelse return null);
                resultColIdx += 1;
            }
        }
    }
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

// TOOD(feniljain):
// - X implement merge schema
// - X convert probe side generation to an iterator
// - loop over iterator, then loop over the received batch, then loop over the build side
// - accumulate results into new batch with new schema and for start get answers using value(idx) directly
// - then optimize this loop

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

const std = @import("std");
const SmpAllocator = std.heap.SmpAllocator;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const benchmark = @import("benchmark");
const GenDatasetResult = benchmark.GenDatasetResult;

const zarrow = @import("zarrow");
const RecordBatch = zarrow.RecordBatch;
const Schema = zarrow.Schema;
const Field = zarrow.Field;
const MutableValidityBitmap = zarrow.MutableValidityBitmap;
const ComputeDatum = zarrow.ComputeDatum;
const computeDatumTake = zarrow.computeDatumTake;
const PrimitiveBuilder = zarrow.PrimitiveBuilder;
const RecordBatchBuilder = zarrow.RecordBatchBuilder;
const PrimitiveArray = zarrow.PrimitiveArray;
const UInt64Builder = zarrow.UInt64Builder;
