# SHA-256 in Bend, with an all-input correctness proof

Pure Bend 2.0.5 implementation, formally verified for functional correctness
against a separate executable specification of byte-oriented SHA-256 from
FIPS 180-4. The universal proof covers preprocessing and the complete digest
computation. No external cryptographic library computes the Bend hash.

## Quick start

Requirements:

- Bend 2.0.5, the proof-capable language. The older Bend 0.2 is not compatible.
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
the first 16 rounds from packed words, then generates remaining schedule words
in a fixed window. The specification uses a reverse-history list, expressing
the recurrence at lags 2, 7, 15, and 16.

The proof proceeds through byte counting, length encoding, padding, parsing,
schedule generation, rounds, blocks, and digest extraction. Supporting list
lemmas connect accumulator-based traversals to direct recursive definitions.
The padding proof covers every Nat, including a symbolic tail after the finite
prefix 0 through 119.

The internal pipeline theorem is generalized over the extension count and
constant table to keep symbolic proof checking manageable. The public theorem
instantiates it with 48 extension words and the fixed SHA-256 table. It has no
arbitrary preprocessing parameter.

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

Requires **Bend 2.0.5**, not the older Bend 0.2 language. The optimized
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

The legacy `test_sha256.py --native` command still enables the original
15 implementation-text mutations by default. Some anchors no longer match the
optimized implementation, so that command is not the current acceptance gate.
Use `python3 research_validate.py`: it runs the execution suite with legacy
mutations disabled, then checks structural public-wrapper mutations for a zero
digest, prepended byte, and reversed digest. Each mutant must first execute
successfully, then fail the universal proof.

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

## Current implementation verification

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
