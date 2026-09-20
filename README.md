# SHA-256 in Bend

Pure Bend SHA-256 with machine-checked source-level correctness proofs.
The byte-list API is proved equivalent to an independent executable FIPS 180-4
specification for every input list, including padding and the complete digest.
The packed-array API has a separate universal packed-format refinement theorem.
No crypto FFI, hardware SHA intrinsics, compiler fork, added axioms, or unsafe
proof declarations are used. Checked with stock **Bend 2.0.16**.

## API

```bend
import Base
import ./sha256.bend as SHA

def main() -> IO(Unit):
  IO.print(SHA.hex(SHA.sha256([97, 98, 99])))
```

This prints SHA-256("abc"):
`ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`.

| Function | Input | Result |
|---|---|---|
| `SHA.sha256` | `List<&2, U32>`; low eight bits of each element | Eight U32 digest words |
| `SHA.sha256_bytes` | Same byte list | Exactly 32 octets |
| `SHA.sha256_packed` | `Array<U32>` and logical byte length | `Some` eight-word digest, or `None` if length exceeds capacity |
| `SHA.hex` | Digest words | Lowercase hexadecimal |
| `SHA.ascii` | ASCII text | Byte list; not a UTF-8 encoder |

The packed API **consumes** the array. Each word stores four input bytes in
big-endian order. Only the declared byte prefix is hashed; unused low bytes in
the last word and unused slots need not be zero. Use balanced arrays created by
`Array.new(U32, depth, initial)`, whose capacity is 2^depth words.

```bend
# One packed word holds "abc" followed by an unused zero byte.
SHA.sha256_packed(Array.new(U32, 0n, 1633837824), 3n)
```

Native U32 arrays use contiguous word storage, avoiding per-byte linked-list
traversal. Compression remains the existing scalar Bend implementation, with
fixed SHA-256 constants and a sixteen-word schedule window. This is a packed
word API, not a raw byte pointer or incremental I/O API.

## Correctness and verification

```sh
bend CORRECTNESS.bend
bend PROOF.bend
python3 test_sha256.py --native
python3 tools/test_packed.py --native
python3 tools/check_packed_mutations.py
uv run --frozen python -m unittest discover -s tests
```

The release checks passed:

- All five original public laws, unchanged, plus `sha256_packed_correct`.
- 182 cases per original API on both JS and native C, including million-`a`.
- 142 packed cases per backend: 138 digests, dirty unused storage, padding/block
  boundaries through 64 KiB, and four invalid lengths.
- Three original and five packed implementation mutations rejected by the proofs.

The full correctness gate checked in 16.89 seconds on the M4, with 1.65 GiB peak
RSS. The packed proofs keep the expansion count symbolic and use a proved
representation of linear arrays, without copying arrays in the runtime hash.
[Verification evidence](benchmarks/packed_verification.json).

**Proof boundary:** the new packed theorem targets `packed_spec.sha256`, which
uses a generic list reader and independent FIPS schedule/compression. There is
not yet a universal theorem connecting byte-list packing to the original
byte-list FIPS specification. The benchmark packing helper is outside the proved
API. The original byte-list-to-FIPS theorem remains intact. The compiler, native
array lowering, C toolchain, allocator and CPU remain trusted; runtime tests do
not constitute a proof of them. See [CORRECTNESS.md](CORRECTNESS.md) for the exact
statements, proof structure, specification mapping, and limits.

## Benchmark: Bend, hashlib, Go, Lean

This is the single published benchmark suite. **Median microseconds per hash;
lower is faster.** The Intel rows ran on the actual remote Xeon, not Rosetta.

| Host | Message | Bend | Python `hashlib` | Go `crypto/sha256` | Lean SHA-256 |
|---|---:|---:|---:|---:|---:|
| Apple M4 | 64 B | 0.286 | 0.212 | 0.048 | 4.656 |
| Apple M4 | 1,024 B | 2.411 | 0.667 | 0.461 | 45.553 |
| Apple M4 | 16,384 B | 29.297 | 5.741 | 5.682 | 560.533 |
| Apple M4 | 65,536 B | 119.141 | 22.497 | 22.727 | 2224.535 |
| Xeon 5412U | 64 B | 0.769 | 0.630 | 0.217 | 10.192 |
| Xeon 5412U | 1,024 B | 6.470 | 1.554 | 1.160 | 86.332 |
| Xeon 5412U | 16,384 B | 96.680 | 16.728 | 16.236 | 1320.653 |
| Xeon 5412U | 65,536 B | 373.047 | 65.188 | 64.446 | 4950.221 |

Each workload hashes the same deterministic **32 MiB corpus** sequentially,
split into the indicated message size: one warmup and five measured batches,
with participant order rotated. Every digest in every batch is checked against
`hashlib`. These are in-process timings, including hashing and result allocation/
retention, excluding build, startup, file loading, input preparation/packing,
hex formatting and printing. Input conversion is not free and is not measured.

Bend receives packed U32 arrays and returns eight digest words; Python receives
`bytes`, Go receives byte slices, and Lean receives `ByteArray`, returning
32-byte digests. This compares the public hashing work over prepared native
representations, not end-to-end file ingestion or compression alone.

Bend and Lean run software SHA-256. Python and Go use their standard default
implementations, including available hardware acceleration. Both generated-C
implementations use **`-O3 -march=native`**. Lean uses the unchanged optimized
`UInt32` implementation at
[`4310886`](https://github.com/etheorem/LeanSha256/commit/4310886800df03d5850ae5aed170c5611548f921),
compiled with Lean 4.29.1. Go is 1.25.5 on ARM and 1.26.0 on Intel. Bend's C
compiler is Apple Clang 17 on ARM and GCC 15.2.0 on Intel; Lean uses its bundled
Clang. The hosts had other workloads, so cross-host differences also reflect
compiler, runtime and load differences. No claim of exclusive CPU isolation.

[ARM raw samples, versions and hashes](benchmarks/fourway_arm.json) ·
[Intel raw samples, versions and hashes](benchmarks/fourway_intel.json).

To reproduce, install Bend 2.0.16, Go, a native C compiler, Python 3, and Lean/Lake
4.29.1, then run:

```sh
python3 tools/build_fourway.py
python3 tools/benchmark_fourway.py \
  --bend .bench-fourway/bend \
  --go .bench-fourway/go \
  --lean .bench-fourway/LeanSha256/.lake/build/bin/shaBench \
  --lean-source .bench-fourway/LeanSha256 \
  --output .bench-fourway/results.json
```

The build helper pins Lean's source commit and records build commands/versions.
It changes only the benchmark entry point and build target in the isolated clone.
Older measurement files remain historical evidence; they are not the current
comparison or a substitute for this suite.

## Repository layout

- `sha256.bend`, `core.bend`, `packed.bend`: public API and implementations.
- `fips.bend`, `packed_spec.bend`: independent executable specifications.
- `LAWS.bend`, `CORRECTNESS.bend`: public claims and their checked proofs.
- `conformance.bend`, `packed_proof.bend`, `packed_array_proof.bend`,
  `list_proofs.bend`, `padding_proof.bend`: supporting universal proofs.
- `benchmarks/fourway/`, `tools/build_fourway.py`, `tools/benchmark_fourway.py`:
  the four-participant benchmark.
- `research_validate.py`, `benchmarks/proof_contract.json`: frozen trust-boundary
  audit and proof/test/mutation gate for further implementation changes.
