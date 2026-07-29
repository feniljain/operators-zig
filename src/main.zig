pub fn main() !void {
    const smp_allocator: Allocator = .{
        .ptr = undefined,
        .vtable = &SmpAllocator.vtable,
    };

    var prng = std.Random.DefaultPrng.init(0x1234_5678_9ABC_DEF0);
    // TODO(feniljian): make this generate 8192 rows and keep feeding in
    // to join algo
    var result = try benchmark.genDataset(smp_allocator, prng.random());

    std.debug.print("Size of build record batch: {}\n", .{result.build.numRows()});

    while(try result.probeIter.next()) |probeBatch| {
        std.debug.print("Size of probe record batch: {}\n", .{probeBatch.numRows()});
    }

    const fields = try mergeSchemas(smp_allocator, &benchmark.buildFields, &benchmark.probeFields, 0);
    std.debug.print("DEBUG::fields::{any}\n", .{fields});

    // nestedLoopJoin(result, 0, 0);
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

// // TOOD(feniljain):
// // - X implement merge schema
// // - X convert probe side generation to an iterator
// // - loop over iterator, then loop over the received batch, then loop over the build side
// // - accumulate results into new batch with new schema and for start get answers using value(idx) directly
// // - then optimize this loop
//
// // Inner Join Nested Loop Join
// //
// // Datafusion:
// //
// // points:
// // - all build side batches are in memory
// // - probe side is streamed until threshold is reached
// //
// // process:
// // - create a bitmap of selected results
// // - remove all the unwanted rows using filter bitmap
// // - copy all the required columns into a new batch
// // - return when you hit configured record batch size
// fn nestedLoopJoin(result: GenDatasetResult, buildJoinColIdx: u32, probeJoinColIdx: u32) void {
//     // loop over join column in build side
//     // - init vector for this iteration
//     // - loop over join column in probe side
//     // - find matches and push to vector
//
//     // research: codex resume 019fa7ff-7729-7803-ba4d-a6c297f877bf
//
//     const probeJoinCol = result.probe.column(probeJoinColIdx);
//     const buildJoinCol = result.build.column(buildJoinColIdx);
//     for(buildJoinCol.values(), 0..buildJoinCol.len) |buildVal, buildIdx| {
//         const vec = ArrayList(u64);
//         for(probeJoinCol.values(), 0..probeJoinCol.len) |probeVal, probeIdx| {
//             if(std.meta.eql(buildVal, probeVal)) {
//                 // construct row and push into vector
//                 // vec.append();
//             }
//         }
//     }
//
//     // convert row format to column?
//
//     // return record batches
// }

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
