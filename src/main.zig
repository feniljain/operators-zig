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
    var result = try benchmark.genDataset(alloc, prng.random());

    const resultFields = try mergeSchemas(alloc, &benchmark.buildFields, &benchmark.probeFields, 0);

    const buildJoinCol = PrimitiveArray(u64){ .data = result.build.column(0).data() };
    var validIndices = [_]usize{0} ** benchmark.DEFAULT_BATCH_SIZE;
    while(try result.probeIter.next()) |probeBatch| {
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

            for(0..result.build.numColumns()) |colIdx| {
                var arr = try UInt64Builder.init(alloc, benchmark.DEFAULT_BATCH_SIZE);
                const col = PrimitiveArray(u64){ .data = result.build.column(colIdx).data() };
                const val = try col.value(buildIdx);
                for(0..benchmark.DEFAULT_BATCH_SIZE) |_| {
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
            if (resultFields.len == result.build.numColumns()) {
                continue;
            }

            var resultColIdx = result.build.numColumns();
            for(0..probeBatch.numColumns()) |colIdx| {
                const col: ArrayRef = (probeBatch.column(colIdx)).*;
                const datum = Datum.fromArray(col);
                const filteredDatum = try computeDatumTake(datum, &validIndices);
                try resultBatchBuilder.setColumn(resultColIdx, filteredDatum.asArray() orelse unreachable);
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
const Datum = zarrow.ComputeDatum;
const computeDatumTake = zarrow.computeDatumTake;
const PrimitiveBuilder = zarrow.PrimitiveBuilder;
const RecordBatchBuilder = zarrow.RecordBatchBuilder;
const PrimitiveArray = zarrow.PrimitiveArray;
const UInt64Builder = zarrow.UInt64Builder;
const ArrayRef = zarrow.ArrayRef;
