# SHA-256 in Bend, with an all-input correctness proof

Pure Bend implementation (release checked with Bend 2.0.16), formally verified for functional correctness
against a separate executable specification of byte-oriented SHA-256 from
FIPS 180-4. For the byte-list API, the universal proof covers preprocessing and the complete digest
computation. No external cryptographic library computes the Bend hash.

## Packed input without hardware acceleration

`sha256_packed(words: Array<U32>, byte_length: Nat)` hashes a prefix of a
consumed array and returns `Maybe<&2, List<&2, U32>>`: `Some` contains the eight
SHA-256 digest words, and `None` means the declared prefix exceeds the array's
byte capacity. Each U32 stores four bytes in big-endian order. Unused low bytes
of the last word and unused array slots are ignored; callers need not zero them.

```bend
# The three bytes "abc", packed into one word. Capacity = four bytes.
SHA.sha256_packed(Array.new(U32, 0n, 1633837824), 3n)
# Some{[the eight digest words for SHA-256("abc")]}
```

Use balanced arrays created by `Array.new`; its depth argument allocates 2^depth
words. This API accepts packed U32 storage, not a raw byte pointer. It does not
add incremental hashing, crypto FFI, SHA instruction intrinsics, or a compiler
fork. Existing list and 32-byte digest APIs remain unchanged. On the native C
backend, closed U32 array reads use contiguous word storage instead of walking
four list nodes per input word. Compression is the existing scalar Bend SHA-256.

The new public law proves this actual exported API equals `packed_spec.sha256`
for every array and logical length in Bend's semantics. The packed specification
uses a generic list block reader and the independent FIPS schedule/compression.
The five existing list/serialization laws are unchanged. **There is not yet a
universal theorem connecting arbitrary byte-list packing to the original
byte-list FIPS specification.** The test/benchmark packing helper is outside the
proved API and outside benchmark timing. See [the exact proof boundary](CORRECTNESS.md#packed-array-api).

Validate the complete release:

```sh
bend CORRECTNESS.bend
python3 test_sha256.py --native
python3 tools/test_packed.py --native
python3 tools/check_packed_mutations.py
```

The packed tests use dirty unused bytes/slots, all lengths 0–129, larger block
boundaries through 64 KiB, and invalid lengths. Negative checks change the
padding marker, partial-word mask, reader index, bounds comparison, and word
order while keeping the specification and proof fixed.

To reproduce the software-only sequential comparison:

```sh
bend benchmarks/list_driver.bend -o /tmp/sha-list
bend benchmarks/packed_driver.bend -o /tmp/sha-packed
python3 tools/benchmark_packed.py --list /tmp/sha-list --packed /tmp/sha-packed --output /tmp/sha-results.json
```

The native builds use the stock compiler's `-O3` C build. Each workload hashes
32 MiB of deterministic input, with one warmup and five alternating measured
batches. Every digest is checked against Python's `hashlib`. Timing includes
hashing and digest allocation/retention, and excludes startup, loading, input
packing, and printing. A caller starting with a byte list must also pay packing
cost; these measurements do not claim that conversion is free.

### Software-only native measurements

| Message | ARM packed | Intel packed | ARM / Intel speedup | ARM improvement over list | Intel improvement over list |
|---|---:|---:|---:|---:|---:|
| 64 B | 0.490 µs | 0.776 µs | 1.58× | 1.48× | 1.43× |
| 1,024 B | 3.845 µs | 6.226 µs | 1.62× | 2.24× | 1.92× |
| 16,384 B | 43.457 µs | 91.797 µs | 2.11× | 2.24× | 2.01× |
| 65,536 B | 169.922 µs | 363.281 µs | 2.14× | 2.37× | 2.02× |

Apple M4 with Apple Clang 17 versus an actual Intel Xeon Gold 5412U with GCC
15.2.0; both `-O3 -std=c11`. These are host/build comparisons, not an isolated
ISA comparison. Both hosts had other workloads; raw samples show that variance.
[ARM samples and provenance](benchmarks/packed_arm.json) ·
[Intel samples and provenance](benchmarks/packed_intel.json).

The complete source-level correctness gate checked in 16.89 seconds on the M4
(1.65 GiB peak RSS). This includes the existing proofs and the new packed laws;
proof checking is separate from native compilation and runtime benchmarks.
[Release verification record](benchmarks/packed_verification.json).

## Current sequential implementation and verification

The 2026-09-19 implementation streams complete blocks from the input list,
unrolls the fixed SHA-256 rounds, and packs final padding and length words
directly. The public input remains a list; this is not an incremental I/O API.
The approved sequential score fell from 117 to 26.5 ms per normalized suite,
a 77.35% reduction (4.42x speedup) in that optimization run.

Fresh publication checks passed all five unchanged public claims, the concrete
proofs, 182 cases per API on JS and native, and three negative public mutations.
An additional 132 random messages per backend covered both APIs, every tail
length after larger blocks, messages up to 4 MiB and high-bit U32 inputs;
19 large length-field cases passed per backend. Four targeted mutations to
length encoding, a round constant, and the 55/56-byte padding boundary were
rejected by the appropriate proof. All 22 harness regression tests passed.
[Verification evidence and limits](benchmarks/sequential_verification.json).

No introduced correctness defect or benchmark shortcut was found. This is a
proof of equivalence to the frozen executable specification, not a proof of
the compiler or hardware. Generated code is larger and compilation can take
substantially longer. The final small incremental gain remains noise-sensitive.

### Comparison with optimized Lean-generated C

Both implementations ran sequentially on the same host and identical runtime
inputs. Lean SHA-256 was compiled through Lean 4.29.1's C backend with verified
`-O3 -march=native` flags, at commit
`4310886800df03d5850ae5aed170c5611548f921`. Its hash implementation was unchanged.
This compares against the native build of etheorem/LeanSha256, not an unrelated
hand-written C SHA-256 implementation.

| Implementation | Median raw suite time | Relative throughput |
|---|---:|---:|
| Lean SHA-256, optimized C backend | 3,641.513 ms | 1.00x |
| Bend SHA-256, sequential native | 357.000 ms | 10.20x |

Three suites per backend, with one warmup and five measured samples per
workload; backend order alternated between workloads and suites. Each workload
hashed the same 8 MiB corpus, split into 64-, 1,024-, 16,384- or 65,536-byte
messages, for 32 MiB per suite. Every digest matched hashlib, and every raw
batch exceeded 20 ms. These raw totals differ from normalized optimization
scores. Build, startup, input preparation and output were excluded; hashing
and digest allocation/retention were included. Other host workloads may affect
absolute times. [All samples, source hashes and method](benchmarks/lean_sequential_comparison.json).

For sequential-only measurements without any parallel/GPU compilation, run:

```sh
uv run --frozen python benchmark_sha256.py --gpu off --sequential-only
```

## Quick start

Requirements:

- Bend 2.0.16, the proof-capable language used for the packed API release. The older Bend 0.2 is not compatible.
- Python 3 for the test harness. Only Python's standard library is used.
- Clang 14 or newer for the optional native backend tests.

```sh
git clone https://github.com/Giulio2002/bend-sha256.git
cd bend-sha256
bend --version
```

Run the checks and example:

```sh
bend CORRECTNESS.bend                   # universal correctness; no test vectors
bend PROOF.bend                         # also checks four exact digest proofs
bend main.bend                          # prints SHA-256("abc")
python3 research_validate.py            # proofs, JS/native tests, negative checks
```

The correctness gate prints `All terms check.`. Its public theorem in
`LAWS.bend` is:

```python
law sha256_correct:
  for +bytes: List<&2, U32>
  {SHA.sha256(bytes) == FIPS.sha256(bytes) : List<&2, U32>}
```

This quantifies over **every input byte list**, and names the actual public
function with the fixed SHA-256 constants and 64 rounds. It has no assumed
preprocessing function, correctness hypotheses, or concrete test inputs.

## What the proof covers

All stages are connected to separately defined specification functions:

- byte counting, padding, and the eight-byte bit-length field;
- big-endian decoding and message-schedule generation;
- the boolean/rotation expressions, 64 rounds, and feed-forward;
- initial state, block order, digest extraction, and the constant table;
- the public `SHA.sha256` wrapper.

`fips.bend` imports **only Base and the neutral State datatype**. It calls no
implementation function and contains its own constants and arithmetic
expressions. For example, its padding uses the direct two-case rule (room in
this block versus another block), whereas the implementation uses modular
arithmetic. `padding_proof.bend` proves their equivalence for every Nat.
The specification's list traversals are direct recursion; the implementation's
large-input traversals use accumulators. Their equivalence is proved by induction.

The proof gate checks the algorithm lemmas, generic list/Nat lemmas,
padding arithmetic, serialization, and all five public claims. There are no
holes, `@unsafe` definitions, or added axioms. See [CORRECTNESS.md](CORRECTNESS.md) for the proof
structure, specification mapping, and trust boundary.

## Implementation and proof design

The implementation uses native U32 arithmetic, which wraps modulo 2^32. It
adds SHA-256 padding, encodes the bit length in eight bytes, decodes big-endian
words, generates the 64 schedule words incrementally in a fixed 16-word window,
executes the rounds, and adds the working state back into the incoming state. The digest is the
final eight words in order.

Long input traversals use tail recursion to avoid stack growth. This change was
validated with the standard million-`a` message. Compression directly executes
all 64 rounds with literal FIPS constants and a fixed schedule window.
It consumes complete blocks directly, counts bytes during that traversal, and
constructs only the final padded block or blocks as packed words. The specification uses a reverse-history list, expressing
the recurrence at lags 2, 7, 15, and 16.

The proof proceeds through byte counting, length encoding, padding, parsing,
schedule generation, rounds, blocks, and digest extraction. Supporting list
lemmas connect accumulator-based traversals to direct recursive definitions.
The padding proof covers every Nat, including a symbolic tail after the finite
prefix 0 through 119.

Generic compression lemmas remain generalized over the extension count and
constant table. The streaming theorem specializes the compressor to the fixed
SHA-256 table and connects it to the independent specification. The public
theorem selects 48 extension words and has no arbitrary preprocessing parameter.

The initial version had only a core refinement proof with shared preprocessing.
That gap is closed here: the specification now contains its own algorithm
definitions, and the public theorem connects the actual implementation to them.
The initial test-vector work remains as additional validation.

## API

```python
import Base
import ./sha256.bend as SHA

def main() -> IO(Unit):
  IO.print(SHA.hex(SHA.sha256([97, 98, 99])))
```

Output:

```text
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
```

`SHA.sha256` accepts `List<&2, U32>` and returns eight U32 digest words in
big-endian order. Each input contributes its **low eight bits**; use 0-255 for
ordinary bytes. `SHA.hex` formats digest words as lowercase hexadecimal.
`SHA.ascii` is an ASCII convenience, **not a UTF-8 encoder**. Encode other text
to bytes before hashing. The formal public theorems cover the eight digest
words and the 32-byte digest API; text helpers are outside these theorems.

Requires **Bend 2.0.16**, not the older Bend 0.2 language. The optimized
implementation uses a rolling schedule window and keeps the input in memory;
this is not a streaming API. Bend's runtime Nat limit is 2^48−1, with available
memory imposing a smaller practical bound.

NIST conformance applies to byte-aligned messages shorter than 2^61 bytes.
The all-list equality theorem also covers a mathematical extension outside that
domain, where the fixed-width length field wraps modulo 2^64. It does not claim
NIST conformance for those excessive lengths.

## Evidence and limits

The universal gate checks independently of test vectors. The test harness also
checks four exact digest proofs, compares 182 cases on JS and native C with
fixed standard digests/Python hashlib, and checks three structural public API
mutations in `research_validate.py`.
The original implementation also passed the 15 text-mutation checks recorded
below; those historical results are not a claim that every textual anchor
survives subsequent rewrites.
The execution suite includes every length 0-129, longer block boundaries,
all byte values, random binary messages, and the million-`a` vector.

This is functional correctness **relative to the explicit FIPS-derived
specification**. As with other formal verification, the specification's faithful
transcription and the proof checker/Base semantics are trusted. The theorem does
not verify the native compiler, hardware, resource availability, or cryptographic
collision/preimage resistance. No external crypto library computes the Bend hash.

## Historical deliberate defect checks

In the original implementation, each mutation was applied to a temporary copy.
The harness ran `CORRECTNESS.bend`, which contains no concrete-message test vectors, and
required rejection at the expected proof obligation. These historical checks
did not modify the working implementation.

| Defect | Deliberate change | Rejecting obligation |
|---|---|---|
| Round arithmetic | Add 1 to `T1 + T2` | `step_correct` |
| Constant table | Increase the first round constant by 1 | `constants_correct` |
| Padding marker | Replace byte 128 with 129 | `pad_correct` |
| Padding zero count | Replace 119 with 118 in the formula | `pad_correct` |
| Byte count | Count each byte as two bytes | `count_acc` |
| Length encoding | Shift the low length component by 4 bits instead of 3 | `length_correct` |
| Byte order | Shift the first byte by 16 bits instead of 24 | `words_acc` |
| Schedule index | Read history index 7 instead of 6 | `next_correct` |
| Schedule sigma | Rotate right by 16 instead of 17 | `next_correct` |
| Round sigma | Rotate right by 1 instead of 2 | `step_correct` |
| Initial state | Increase the first initialization word by 1 | `hash_correct` |
| Digest order | Swap the first two output words | `digest_correct` |
| Output byte order | Shift a serialized byte from the wrong position | `digest_bytes_correct` |
| Output byte mask | Narrow a serialized byte mask | `digest_bytes_correct` |
| Output byte count | Omit a serialized byte | `digest_bytes_correct` |

## Recorded verification

The original implementation verification run used Bend 2.0.5. These are
historical results; current winner validation is reported separately below:

```text
Specification independence: only Base and the neutral state datatype imported
Universal correctness theorem: All terms check.
Bend proofs: All terms check.
Universal proof mutation checks: 15 algorithm defects rejected without test vectors
JS words: 182 SHA-256 cases passed
JS bytes (32 octets, each 0..255): 182 SHA-256 cases passed
Native words: 182 SHA-256 cases passed
Native bytes (32 octets, each 0..255): 182 SHA-256 cases passed
```

The 182 execution cases comprise four fixed standard vectors, 141 lengths and
block-boundary cases, three byte-pattern cases, 32 deterministic random cases,
one low-byte API case, and the million-`a` vector. Random cases are reproducible
with seed 256. The four concrete equality proofs cover the empty input, `abc`,
the standard 56-byte message, and the standard 112-byte message.

These are recorded local results, not a claim about a hosted CI run. See
[VALIDATION.txt](VALIDATION.txt) for the record and
[test_sha256.py](test_sha256.py) for the reproducible harness.

## Files

| File | Role |
|---|---|
| `sha256.bend`, `core.bend` | Public API and implementation |
| `fips.bend` | Separate executable FIPS specification |
| `state.bend` | Shared data representation; no operations |
| `LAWS.bend`, `CORRECTNESS.bend` | Public universal claims and proofs |
| `conformance.bend` | Inductive proofs for the complete pipeline |
| `list_proofs.bend`, `padding_proof.bend` | Supporting universal lemmas |
| `PROOF.bend` | Universal proof plus four concrete equality proofs |
| `test_sha256.py` | Independence checks, negative tests, differential tests |

Reference: [NIST FIPS 180-4](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf).

## CPU performance benchmark

Install the locked Python comparison backends, then benchmark:

```sh
uv sync --python 3.12
uv run --frozen python benchmark_sha256.py --gpu off
```

`--gpu required` forces real GPU execution and fails if the device, compiler,
GPU build or digest checks fail. `--gpu auto` detects Metal on macOS
or NVIDIA CUDA with its toolkit on Linux; an unavailable GPU is explicitly
reported as skipped. `--gpu off` is the default and measures both sequential and parallel CPU against Python.
GPU measurements are optional diagnostics and never contribute to the score.
GPU build or execution errors on a detected device are errors, not silent skips.

The benchmark compares our public `SHA.sha256` against three Python interfaces:
`hashlib`, PyCryptodome and `cryptography`. "Fastest Python" means the fastest
of these measured implementations on this machine and workload. It is not a
claim to have exhausted every SHA-256 library. Python's
[hashlib documentation](https://docs.python.org/3/library/hashlib.html) describes
its native/OpenSSL-backed hash implementations.

All backends hash identical deterministic binary inputs. Each workload processes
an initially 1 MiB corpus, split into 64-, 1,024-, 16,384-, or 65,536-byte messages. The native driver
loads and constructs the inputs before starting its clock, invokes the actual
public Bend function, retains every digest, stops the clock, then prints results.
Python verifies every native digest and every Python result against hashlib.
Compilation, process startup, input preparation, hex formatting and output are
excluded. Hashing and digest allocation/retention are included. The compared APIs
have different representations: Bend consumes lists of U32 values, while Python
libraries consume bytes. This is API-level throughput, not isolated compression
round performance.

Bend's GPU driver builds a balanced tree of independent messages before timing.
Every leaf calls the same proved public `SHA.sha256`. It runs with GPU forced
off for the mandatory parallel CPU comparison. Optional GPU diagnostics force
it on for Metal/CUDA. GPU dispatch and
completion synchronization are inside the measured interval. The result is
host-observed completion time, not a GPU kernel-only timing. GPU execution does
not imply that Bend's GPU compiler/runtime has been formally verified.

Each Bend mode has one unrecorded run and five recorded process runs per size.
Each run measures a fresh batch; this is not repeated use of a persistent process.
Bend's millisecond clock requires at least 20 ms per batch; unresolved batches
trigger a retry with twice the corpus for every mode and workload, up to 64 MiB.
Schema 3 reports actual corpus sizes and raw measurements, with score times
normalized to 1 MiB. This avoids rejecting a correct implementation for being
faster than the original timer-resolution floor. Timings below the floor never
become accepted raw samples. Larger batches can alter parallel occupancy, so
cross-size comparisons require care and matched-size evidence for marginal gains.
Python calibrates repeated batches to at least
50 ms and uses `perf_counter_ns`. Raw samples, library/tool versions, device
identity, corpus hash and per-size winners are included in the final JSON line.
Readable progress goes to stderr. Save a report with `--output report.json`.

### Recorded local baseline

On 2026-09-18, Apple M4 with 10 GPU cores, Bend 2.0.5, Python 3.12.12,
OpenSSL 3.5.5, PyCryptodome 3.23.0 and cryptography 49.0.0:

| Backend | Sum of four batch medians |
|---|---:|
| Python hashlib | 4.23 ms |
| Python cryptography | 14.97 ms |
| Python PyCryptodome | 52.29 ms |
| Bend parallel CPU | 325 ms |
| Bend sequential CPU | 1,239 ms |
| Bend Metal GPU | 5,537 ms |

These are local measurements of 4 MiB total input per suite. The GPU is slower
for this implementation and workload; more parallel hardware is not evidence
of a faster algorithm. See [benchmarks/baseline.json](benchmarks/baseline.json)
for all raw samples and per-workload results. Timings vary with load and hardware.

## Proof-preserving autoresearch

The research runner is a separate private repository:
[Giulio2002/autoresearch](https://github.com/Giulio2002/autoresearch).
The SHA-256 objective, review policy, benchmark and validation gate live here.
With both repositories cloned next to one another:

```sh
cd ../autoresearch
uv sync
uv run autoresearch check --objective ../bend-sha256/OBJECTIVE.md
uv run autoresearch run --objective ../bend-sha256/OBJECTIVE.md
```

Every candidate must pass `uv run --frozen python research_validate.py` before
it is measured. This gate checks:

- frozen FIPS specification, state type, public theorem and proof entry points;
- checked supporting proofs (whose statements may evolve), frozen imports, and no unsafe code, holes,
  foreign imports, effects or overrides of trusted definitions;
- the universal theorem and all four concrete digest proofs;
- all 182 differential cases for each API on both JS and native CPU backends;
- three type-correct public API mutations that the universal proof must reject.

The standalone `python3 test_sha256.py --native` command and the full
`python3 research_validate.py` gate both use structural public-wrapper mutations
for a zero digest, prepended byte, and reversed digest. Each mutant must execute
successfully, then fail the universal proof. The full gate runs this suite once,
after invoking the standalone execution checks with `--skip-mutations`.

Historical text mutations require `--legacy-mutations` and their original source
anchors. They are not the default and may fail on optimized implementations.
Standalone correctness checks use explicit exceptions and remain active under
Python `-O` and `-OO`. The full gate also rejects optimized Python execution.

The agent can edit `core.bend`, `sha256.bend`, `conformance.bend`,
`list_proofs.bend`, `padding_proof.bend`, and `CORRECTNESS.bend`. Supporting
lemmas may be added, renamed, replaced or restated, and proof bodies may change.
Every law must have a checked proof, and all five unchanged public claims must
still hold unconditionally. The independent specification, state type,
`LAWS.bend`, concrete vector proofs, import graph and measurement harness remain
frozen. The orchestrator reviews the revised dependency chain and must explain
why full arbitrary-input verification still reaches the measured implementation.
Proof rewrites require a concrete performance mechanism and repeatable gain
above 3 percent, beyond timing noise; proof churn alone is not an improvement.
The hash manifest is a reviewed, protected baseline that the agent may not edit.

The metric is the fastest complete-suite Bend time (`best_bend_total_ms`) across
sequential CPU and parallel CPU, not a ratio that could improve by slowing
Python down. Each mode's four workload medians are summed first; the smallest
mode total wins. The runner never mixes per-size winners into a synthetic mode.
A candidate may change which mode wins; it must beat the previous best under
the same scoring rule. The CPU benchmark is repeated three times. Acceptance requires more than 3 percent gain
and an independent orchestrator approval based on code, proofs, measurements
and previous runs. The orchestrator verifies all mode totals and the winning mode.
The loop stops after three consecutive misses, with no total iteration cap.

The source checkout is never edited by the loop. Runs, temporary directories,
agent events, exposed reasoning summaries and review evidence are retained under
`.autoresearch/runs`. Export an approved result into a new directory:

```sh
uv run autoresearch export ../bend-sha256/.autoresearch/runs/RUN_ID --to ../sha256-optimized
```

An absent or failed proof, validation, CPU benchmark or review cannot become an
accepted improvement. The static contract checks and orchestrator add defenses;
they are not a proof of the orchestration software or a hostile-code sandbox.
The formal claim remains exactly the trust boundary described above and in
[CORRECTNESS.md](CORRECTNESS.md).

### Rolling-window implementation

The current implementation fuses schedule generation with compression and stores
schedule history in a fixed 16-word internal datatype. Its supporting proofs
establish equivalence to the unchanged independent specification. The public
list-based word and byte APIs remain unchanged.

A matched-size diagnostic compared it with the previously approved fused-list
implementation on 8 MiB per workload. Median parallel suite totals were 946 ms
and 192 ms, respectively, a 4.93x speedup. Every measured batch exceeded 20 ms;
every output was checked. Full research validation passed, including universal
proofs and mutation rejection. These diagnostics ran alongside the research
worker and are not an orchestrator approval. See
[measurements and method](benchmarks/rolling_window_evidence.json).

## Previous implementation verification (d329dab)

The implementation published at `d329dab` passed fresh validation on 2026-09-18:

- Universal correctness and four concrete digest proofs checked.
- All 182 cases passed for each word and byte API on JS and native backends.
- Zero-digest, prepended-byte and reversed-digest mutations executed, then were
  rejected by the universal proof.
- The independent specification, public laws and protected imports were unchanged.

These results concern the optimized implementation. Separately executing the
recursive reference specification hit a JS memory/stack fault on a million-byte
probe, while its native probe passed. See [the specification audit](CORRECTNESS.md#specification-audit-and-domain-qualification)
for this resource limitation and remaining specification-hardening opportunities.

## Previous parallel-scored research run

Run `20260918T194829Z-b4cc8b` ended for publication with `plateau` after 6 iterations.
The best retained CPU score was **21.375 ms per normalized suite**,
compared with 23.125 ms at this run's baseline (7.57% lower).
Each workload time is normalized to 1 MiB; raw batch sizes and timings are retained
in [the final report](benchmarks/research_final.json). These normalized scores
should not be compared directly with older uncalibrated totals.

The winning implementation and supporting proofs are now in this checkout.
The winner's complete research validation was rerun successfully before publication:
universal and vector proofs, 182 differential cases per API on JS/native, and
three negative public-mutation proof checks. Only the retained winner is exported;
failed, rejected and unreviewed candidates remain archived in the local run.

## Historical Lean versus Bend benchmark (b3ce430)

Measured on the same Apple M4 with identical deterministic inputs: 8 MiB per
workload at 64-, 1,024-, 16,384- and 65,536-byte message sizes, or 32 MiB per suite.
Three suites per backend, each with one warmup and three measured samples per
workload; backend order rotated. Every digest matched hashlib. Compilation,
process startup, input preparation and output were excluded; hashing and digest
allocation/retention were timed.

| Implementation | Median suite time | Relative to Lean |
|---|---:|---:|
| Lean native, sequential | 1,664.618 ms | 1.00x |
| Bend sequential CPU | 1,018.000 ms | 1.64x |
| Bend parallel CPU | 208.000 ms | 8.00x |

The Lean implementation is [etheorem/LeanSha256](https://github.com/etheorem/LeanSha256),
commit `4310886800df03d5850ae5aed170c5611548f921`, compiled with Lean 4.29.1
and the repository's native optimization settings. The measured Bend version
is the rolling-window implementation at `b3ce430`, using Bend 2.0.5. This is a
versioned comparison recorded before the final research winner above; the table
does not claim to measure subsequent optimizations.

Parallel Bend used multiple CPU cores; the tested Lean driver was single-threaded.
Both used their public APIs, with ByteArray inputs in Lean and word lists in Bend.
The research worker remained running, so concurrent load is a limitation.
All batches exceeded 20 ms. These are raw 32 MiB suite totals, not the normalized
research scores above. [Complete measurements and metadata](benchmarks/lean_comparison.json).
