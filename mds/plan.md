## Baseline for benchmarking:

- Should be done on exact same dataset -> should data fit in memory?
- Batch size should be the same
- Benchmark types:
	- Size of the hash table
	- Data types
	- Selectivity

## Steps:

- nested loop join: just get it to work
- nested loop join benchmarks against Datafusion's operator
- hash join: optimizing hashing algorithms to be faster
- hash join benchmarks against Datafusion's operator
- partitioned hash join: thread per core?
- partitioned hash join benchmarks against Datafusion's operator
- spillable hash join: optimizing writing to disk with io_uring etc
- spillable + partitioned hash join: algorithmic level optimization
- distributable hash join
- check for better vectorization opportunities in Zig implementation

## Links:

- https://github.com/apache/arrow/issues/30038#issuecomment-1378057061
- https://github.com/tylitianrui/zarrow
- https://github.com/gpanders/ztags
