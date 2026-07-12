// Re-implemeting cause of this bug: https://codeberg.org/ziglang/zig/issues/35683
pub fn genRandomArray(r: std.Random, comptime E: type, comptime N: usize) [N]E {
    var result: [N]E = undefined;
    std.Random.bytes(r, @ptrCast(&result));
    return result;
}

/// T: Type of elements of array
/// N: Current array size
/// S: Desired result array size
/// arry: actual array to repeat
pub fn repeatArr(
    comptime T: type,
    comptime N: u64,
    comptime S: u64,
    arr: *[N]T
) [S]T {
    var remainingCnt: u64 = S;
    var resultArr = [_]T{0} ** S;
    var trackingIdx: u64 = 0;

    while (true) {
        if (remainingCnt <= 0) {
            break;
        }

        const diff = @min(remainingCnt, arr.len);
        const endIdx = trackingIdx + diff;

        @memcpy(resultArr[trackingIdx..endIdx], arr[0..diff]);

        trackingIdx = endIdx;
        remainingCnt -= diff;
    }

    return resultArr;
}

test "repeatArr" {
    const arr =  [_]u64{ 1, 2, 3 };

    const resultArr = repeatArr(u64, 3, 5, arr);
    const expectedResultArr = [_]u64{ 1, 2, 3, 1, 2 };
    try expectEqualSlices(u64, &expectedResultArr, &resultArr);
}

const std = @import("std");
const expectEqualSlices = std.testing.expectEqualSlices;
