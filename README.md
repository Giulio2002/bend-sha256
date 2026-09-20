# SHA-256 in Bend

Pure Bend SHA-256 with machine-checked source-level correctness proofs.
The historical byte-list proof model is proved equivalent to an independent executable FIPS 180-4
specification for every input list, including padding and the complete digest.
The production packed-array API has a universal packed-format refinement theorem,
plus checked digest word-order and eight-word size laws.
No crypto FFI, hardware SHA intrinsics, compiler fork, added axioms, or unsafe
proof declarations are used. Checked with stock **Bend 2.0.16**.

## BendHub

Published package: [0xda83506fb9f059ead7afcfa2f498df5f](https://hub.bend-lang.com/0xda83506fb9f059ead7afcfa2f498df5f).

Import the packed-array implementation directly:

```bend
import Base
import 0xda83506fb9f059ead7afcfa2f498df5f/sha256.bend as SHA
```

The package includes the checked proof modules and specifications. To import the
entry module that also checks those proofs, use:

```bend
import 0xda83506fb9f059ead7afcfa2f498df5f/package.bend as SHA
```

Both expose `SHA.sha256(words, byte_length)` and `SHA.hex(digest)`. Input and output
words contain four **big-endian** bytes each; the digest has exactly eight words.
The implementation-only import does not load the historical list proof models.

BendHub packages are immutable and addressed by their content hash. This package
contains the production and proof sources from release `c77b76c`, plus the package
entry module. The published bundle contains 19 files (580,462 bytes); its scope
and limitations are documented in `package.bend` and [CORRECTNESS.md](CORRECTNESS.md).
A clean-cache download was checked on the interpreter and native backend.

To publish a future checked release:

```sh
bend PROOF.bend
bend package.bend --publish
```

A source change produces a new package hash; update the import line accordingly.

## API (breaking change: packed arrays only)

The production API no longer accepts or returns linked lists:

```bend
import Base
import ./sha256.bend as SHA

def show(r: Maybe<&1,Array<U32>>) -> String:
  match r:
    case None{}: "invalid length"
    case Some{digest}: SHA.hex(digest)

def main() -> IO(Unit):
  # One big-endian word contains "abc" and an ignored low byte.
  IO.print(show(SHA.sha256(Array.new(U32,0n,1633837824),3n)))
```

`SHA.sha256(Array<U32>, byte_length: Nat)` consumes packed input and returns
`Maybe<&1,Array<U32>>`: exactly eight big-endian U32 words (32 digest bytes),
or `None` when the declared byte length exceeds the array's byte capacity.
Four input bytes occupy each word. Unused low bytes and trailing capacity are
ignored. Construct balanced input arrays with `Array.new`; capacity is 2^depth
words. `SHA.hex` consumes an eight-word digest for display.

The old byte-list `sha256`, `sha256_bytes`, `ascii`, `digest_bytes` and list-result
`sha256_packed` interfaces are removed. Callers must migrate to packed buffers;
there is no implicit conversion back to lists. Native input and output use array
storage; the compression core uses scalar words and a fixed rolling window.
No crypto FFI or hardware SHA acceleration has been added.

Historical list algorithms survive **only as proof models**, in `core_model.bend`
and `legacy_model.bend`. The production import graph is `sha256 -> buffer -> packed
-> core`, plus the state record and Base; it does not import those models, specs or
proofs. List-valued specifications remain mathematical proof artifacts.

## Correctness and verification

```sh
bend CORRECTNESS.bend
bend PROOF.bend
python3 test_sha256.py --native
python3 tools/test_packed.py --native
python3 tools/check_packed_mutations.py
uv run --frozen python -m unittest discover -s tests
```

Validation includes:

- Historical model laws remain checked; `sha256_array_correct` targets the actual
  array-only public API, and digest word-order and size laws check its output.
- 182 cases per original API on both JS and native C, including million-`a`.
- 142 packed cases per backend: 138 digests, dirty unused storage, padding/block
  boundaries through 64 KiB, and four invalid lengths.
- Three public array mutations and six packed/output mutations rejected.
- Production dependency audit: no list storage or imports of proof models.

Before the array-output migration, the full correctness gate checked in 16.89 seconds on the M4, with 1.65 GiB peak
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

The table below records the preceding packed-input/list-digest release. It has not
been rerun for this breaking array-output API; no new speedup is claimed. The
four-way runner now invokes the production array API.

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

- `sha256.bend`, `buffer.bend`, `core.bend`, `packed.bend`: array-only runtime.
- `fips.bend`, `packed_spec.bend`: independent executable specifications.
- `LAWS.bend`, `CORRECTNESS.bend`: public claims and their checked proofs.
- `buffer_proof.bend`, `conformance.bend`, `packed_proof.bend`, `packed_array_proof.bend`,
  `list_proofs.bend`, `padding_proof.bend`: supporting universal proofs.
- `benchmarks/fourway/`, `tools/build_fourway.py`, `tools/benchmark_fourway.py`:
  the four-participant benchmark.
- `research_validate.py`, `benchmarks/proof_contract.json`: frozen trust-boundary
  audit and proof/test/mutation gate for further implementation changes.
