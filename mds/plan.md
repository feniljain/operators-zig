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
- https://zigbyexample.neocities.org/
- www.p99conf.io/2025/09/25/better-async-rust-disk-i-o/
- https://codearcana.com/posts/2013/05/18/achieving-maximum-memory-bandwidth.html
- https://akkadia.org/drepper/cpumemory.pdf

## Types of benchmarks to use:

- Single threaded performance (non-partitioned hash join)
- Multi-threaded performance (partitioned hash join)
- Selectivity of join
- Larger than memory joins
- Size of build vs probe side
- Data types, 16, 32 and 64 bits for all
    - Integer
    - Unsigned Integer
    - Float
    - String
    - Decimal

## External References

https://github.com/apache/arrow/issues/30038, good ticket discussing various factors to write benchmark for. Dimensions:

- Size of the hash table
- Data types
- Selectivity
- Join Types
- Number of matches
- Payload size
- Degree of parallelism
- Distribution of key frequencies

## Big ideas

- Use arrow-rs but don't use any of the internally implemented arrow functions
- Optimize using SIMD
- Specialized hash functions for each data type
- Better cache locality
- Minimize false sharing
- Benchmark against datafusions implementation
