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
python3 test_sha256.py --native          # proofs, mutations, JS/native tests
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

The proof gate contains 34 checked laws: 21 algorithm lemmas, six generic list/
Nat lemmas, one padding-arithmetic lemma, and six serialization/public claims. There are no
holes, `@unsafe` definitions, or added axioms. See [CORRECTNESS.md](CORRECTNESS.md) for the proof
structure, specification mapping, and trust boundary.

## Implementation and proof design

The implementation uses native U32 arithmetic, which wraps modulo 2^32. It
adds SHA-256 padding, encodes the bit length in eight bytes, decodes big-endian
words, expands each 16-word block into 64 schedule words, executes the rounds,
and adds the working state back into the incoming state. The digest is the
final eight words in order.

Long input traversals use tail recursion to avoid stack growth. This change was
validated with the standard million-`a` message. The schedule uses reverse
history: offsets 1, 6, 14, and 15 refer to the preceding words at lags 2, 7, 15,
and 16. The specification expresses those lags separately.

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
to bytes before hashing. The formal public theorem concerns the eight digest
words; the text helpers are covered by execution tests.

Requires **Bend 2.0.5**, not the older Bend 0.2 language. The implementation
keeps the input and schedules in memory. Bend's runtime Nat limit is 2^48−1;
available memory is the practical limit. This is a reference implementation,
not a streaming or performance-tuned library.

## Evidence and limits

The universal gate checks independently of test vectors. The test harness also
checks four exact digest proofs, compares 182 cases on JS and native C with
fixed standard digests/Python hashlib, and deliberately introduces 15 defects.
The **universal proof alone** rejects all 15, including padding, length encoding,
byte order, schedule indices, sigma functions, initial state, and constants.
The execution suite includes every length 0-129, longer block boundaries,
all byte values, random binary messages, and the million-`a` vector.

This is functional correctness **relative to the explicit FIPS-derived
specification**. As with other formal verification, the specification's faithful
transcription and the proof checker/Base semantics are trusted. The theorem does
not verify the native compiler, hardware, resource availability, or cryptographic
collision/preimage resistance. No external crypto library computes the Bend hash.

## Deliberate defect checks

Each mutation is applied to a temporary copy. The harness runs
`CORRECTNESS.bend`, which contains no concrete-message test vectors, and
requires rejection at the expected proof obligation. The working implementation
is never modified by these checks.

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

## Recorded verification

The completed local run used Bend 2.0.5:

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

## Performance benchmark and GPU check

Install the locked Python comparison backends, then benchmark:

```sh
uv sync --python 3.12
uv run --frozen python benchmark_sha256.py --gpu required
```

`--gpu required` forces real GPU execution and fails if the device, compiler,
GPU build or digest checks fail. `--gpu auto` (the default) detects Metal on macOS
or NVIDIA CUDA with its toolkit on Linux; an unavailable GPU is explicitly
reported as skipped. `--gpu off` runs only the sequential Bend/Python comparison.
GPU build or execution errors on a detected device are errors, not silent skips.

The benchmark compares our public `SHA.sha256` against three Python interfaces:
`hashlib`, PyCryptodome and `cryptography`. "Fastest Python" means the fastest
of these measured implementations on this machine and workload. It is not a
claim to have exhausted every SHA-256 library. Python's
[hashlib documentation](https://docs.python.org/3/library/hashlib.html) describes
its native/OpenSSL-backed hash implementations.

All backends hash identical deterministic binary inputs. Each workload processes
1 MiB, split into 64-, 1,024-, 16,384-, or 65,536-byte messages. The native driver
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
off for parallel CPU comparison and forced on for Metal/CUDA. GPU dispatch and
completion synchronization are inside the measured interval. The result is
host-observed completion time, not a GPU kernel-only timing. GPU execution does
not imply that Bend's GPU compiler/runtime has been formally verified.

Each Bend mode has one unrecorded run and five recorded process runs per size.
Each run measures a fresh batch; this is not repeated use of a persistent process.
Bend's millisecond clock requires at least 20 ms per batch; unresolved batches
fail rather than reporting zero. Python calibrates repeated batches to at least
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
- unchanged supporting law statements and imports, with no unsafe code, holes,
  foreign imports, effects or overrides of trusted definitions;
- the universal theorem and all four concrete digest proofs;
- all 182 differential cases for each API on both JS and native CPU backends;
- three type-correct public API mutations that the universal proof must reject.

The existing 15 implementation-text mutations still run with
`uv run --frozen python test_sha256.py --native`. Their textual anchors can
legitimately disappear during optimization, so the research gate uses structural
public-wrapper mutations instead: zero digest, prepended byte, and reversed
digest. Each mutant must first execute successfully, then fail the universal
proof. The original mutation suite remains enabled by default.

The agent can edit `core.bend`, `sha256.bend`, and supporting proof bodies in
`conformance.bend`, `list_proofs.bend`, and `padding_proof.bend`. The existing
supporting statements and import graph are deliberately frozen. This limits
which refactors can be attempted, but prevents changing the correctness target
alongside the implementation. A broader proof architecture requires a separately
reviewed change to the research contract. The hash manifest is a reviewed,
protected baseline, not something the agent is allowed to regenerate.

The metric is the fastest complete-suite Bend time (`best_bend_total_ms`) across
sequential CPU, parallel CPU and GPU, not a ratio that could improve by slowing
Python down. Each mode's four workload medians are summed first; the smallest
mode total wins. The runner never mixes per-size winners into a synthetic mode.
A candidate may change which mode wins; it must beat the previous best under
the same scoring rule. The benchmark, including mandatory GPU
checks, is repeated three times. Acceptance requires more than 3 percent gain
and an independent orchestrator approval based on code, proofs, measurements
and previous runs. The orchestrator verifies all mode totals and the winning mode.
The default budget is three consecutive misses, at most eight attempts.

The source checkout is never edited by the loop. Runs, temporary directories,
agent events, exposed reasoning summaries and review evidence are retained under
`.autoresearch/runs`. Export an approved result into a new directory:

```sh
uv run autoresearch export ../bend-sha256/.autoresearch/runs/RUN_ID --to ../sha256-optimized
```

An absent or failed proof, validation, GPU check or review cannot become an
accepted improvement. The static contract checks and orchestrator add defenses;
they are not a proof of the orchestration software or a hostile-code sandbox.
The formal claim remains exactly the trust boundary described above and in
[CORRECTNESS.md](CORRECTNESS.md).
