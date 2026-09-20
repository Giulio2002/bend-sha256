# Checked functional correctness

The principal statement is `LAWS.sha256_correct`, proved in `CORRECTNESS.bend`:

    for every bytes : List<&2, U32>,
    SHA.sha256(bytes) = FIPS.sha256(bytes).

The two sides are the actual exported implementation and the separate
specification in `fips.bend`. Both select the standard initialization, 48 schedule
extension words, and the fixed 64-word SHA-256 table. No helper correctness is
assumed by this theorem. Run `bend CORRECTNESS.bend` to check it without running
or proving a single concrete-message test vector.

## Independent specification

`fips.bend` imports only Bend's Base library and `state.bend`, a record with eight
U32 fields and no algorithm. It defines all algorithm operations itself. This
includes padding, length encoding, parsing, recurrence, boolean functions,
initialization, constants, compression, and digest extraction.

The specification is an executable transcription of
[NIST FIPS 180-4](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf).
The mapping is:

| FIPS section | Specification definitions |
|---|---|
| 4.1.2 | `rotate`, `sigma0`, `sigma1`, `sum0`, `sum1`, `ch`, `maj` |
| 4.2.2 | `constants` |
| 5.1.1 | `zero_count`, `octets`, `length_field`, `padding_suffix`, `pad` |
| 5.2.1 | `decode`, `words`, `schedules` |
| 5.3.3 | `initial` |
| 6.2.2 | `previous`, `recurrence`, `extension`, `step`, `rounds`, `feedforward`, `blocks`, `digest` |

U32 arithmetic expresses modulo-2^32 operations. The schedule is represented by
reverse history: `previous(history, lag)` indexes `lag-1`. Thus the specification
names the standard lags 2, 7, 15, and 16. The implementation selects the
corresponding fields of its fixed 16-word window; supporting list-based helpers
use indices 1, 6, 14, and 15.

The byte-oriented padding rule uses r = n mod 64. If r <= 55, append 55-r zeros;
otherwise append 119-r zeros. This leaves eight bytes after the marker and zeros.
For the length field, 8n = 256*(n/32) + 8*(n mod 32). The specification emits the
seven big-endian digits of n/32, followed by the low byte. This expresses the
64-bit length without overflowing the runtime Nat by multiplying the entire n.
For supported message lengths, no significant bit is discarded.

These representation choices are part of the specification's mathematical
transcription, not calls to implementation code. The trust boundary below applies
to their correspondence to the natural-language standard.

## Checked proof structure

All named equalities in the following table are actual checked Bend laws.

| Lemma | What it establishes |
|---|---|
| `octets_correct`, `length_correct` | Length encoding agrees with the independent specification |
| `Padding.zeros_correct`, `suffix_correct` | The full padding suffix agrees for every message length |
| `nth_correct`, `next_correct`, `extension_correct`, `schedule_correct` | Generic schedule generation agrees with the FIPS recurrence |
| `step_correct`, `rounds_correct`, `feedforward_correct`, `compression_correct` | Arithmetic and generic compression agree |
| `expanded_rounds_correct`, `schedule_rounds_correct` | Fused generation agrees with materialized schedule rounds |
| `fused_compress_correct`, `fused_compress_slow_correct` | Optimized and fallback compression refine the generic algorithm |
| `window_rounds_correct`, `window_schedule_rounds_correct`, `window_compress16_correct` | Fixed-window operations refine list-based compression |
| `kr64_correct` through `kr16_correct`, `fips16_correct` | Literal-constant round sequence agrees with the fixed FIPS table |
| `mod_quotient`, `mod_shift`, `mod_tail` | Counting full blocks preserves the remainder needed for final padding |
| `stream_correct` | Processing input blocks directly agrees with generic processing of the padded message |
| `block_bytes_correct`, `digest_correct`, `sha256_correct` | Streaming output reaches the independent complete hash pipeline |
| All five `Laws.*` public proofs | Constants, word digest, serialization, byte digest and byte length remain correct |

The key streaming invariant quantifies over arbitrary remaining bytes, block
count k, expansion count and state. It relates `stream(bytes, 64*k, ...)` to
generic `block_bytes` applied to those bytes plus the padding suffix for their
length plus 64*k. The full-block case recurses at k+1. All 64 short-tail cases
prove the exact placement of the marker, zero padding and length words, including
the two-block boundary at 56 bytes. The public function starts at k=0.

`padding_proof.bend` handles every Nat: the finite prefix 0-119 is followed by a
symbolic `120+p` branch. In that last branch both saturated subtractions reduce
to zero for arbitrary p. This is a universal case split, not a list of test
vectors or an empirical bound on message lengths.

The public proof invokes `Conformance.sha256_correct`, which composes
`suffix_correct`, `digest_correct`, `stream_correct` and `block_bytes_correct`.
The streaming lemma uses `fips16_correct` and the literal-round lemmas to connect
the actual optimized execution to the prior generic compression proof. The
public entry point selects exactly 48 derived rounds and the standard initial
state; fixed-table agreement is checked by conversion. The theorem is
unconditional over every public input list, with no caller-supplied correctness
premise. The public serialization and length proofs remain unchanged.

## Validation independent of the proof construction

`test_sha256.py` checks that the specification imports only Base and the neutral
datatype, and that project code contains no holes, unsafe annotations, or foreign
implementations. It then checks the universal gate and the four concrete equality
proofs, and compares 182 JS/native digest executions against fixed standard
vectors and Python hashlib. The execution cases include padding boundaries,
binary bytes, randomized messages, and the standard million-`a` message.

The original implementation passed fifteen text-based negative checks,
recorded as historical evidence. Their anchors need not survive optimization.
The standalone default suite and current research gate instead check three
structural public mutations; historical text mutations require `--legacy-mutations`.
The original checks mutated one implementation detail at a time: round
arithmetic, a table entry, the padding marker, the padding zero count, byte count,
length encoding, byte order, schedule index, schedule sigma, round sigma, initial
state, digest order, output byte order, output byte masking, and omission of an output byte. Each was rejected by `CORRECTNESS.bend`, which does not
import the concrete-vector proof module. Thus those historical rejections exercised the
universal conformance proof itself.

## Precise trust boundary

The result is a universal proof of equality to the explicit FIPS-derived
specification, including the formerly shared preprocessing and arithmetic
helpers. It is not conditional on their correctness as unproved hypotheses.

As in ordinary program verification, correspondence between a written standard
and its formal transcription remains an auditable specification assumption.
Bend 2.0.5's proof checker and Base's Nat/U32/list semantics are trusted. No
additional axioms or unsafe definitions were introduced. This work does not
formally verify the checker, compiler, hardware, or the cryptographic security
of SHA-256.

The API hashes low-eight-bit interpretations of its U32 inputs. FIPS conformance
is for byte-aligned messages shorter than 2^61 bytes; this API does not accept
fractional-byte messages.
The theorems cover eight-word and 32-byte digests, not the `ascii`/`hex` presentation helpers.
Bend execution remains subject to its 2^48−1 Nat limit and available memory; the
implementation retains the complete message and uses a rolling schedule window.

## Byte digest API

`SHA.sha256_bytes(bytes)` serializes the eight digest words as exactly 32
big-endian octets, represented by U32 values. Each output masks the selected
bits with 255. `FIPS.word_octets` independently specifies the four bytes of a
word in decreasing significance; `FIPS.digest_octets` concatenates them.

`Laws.digest_bytes_correct` proves the implementation traversal agrees with
that specification for every word list, by induction. `Laws.sha256_bytes_correct`
composes this with the all-input SHA-256 theorem. `digest_octets_length` proves
serialization of every eight-word State has length 32; `Laws.sha256_bytes_length`
transfers this result to the actual public function for every input.

All 182 execution cases exercise both APIs on JS and native C. Byte results are
compared element by element with hashlib's digest bytes, checking the length,
order, and U32 values (including their zero high bits). Three additional negative
checks in the original text-mutation suite changed output byte order, narrowed
a byte mask, or omitted an output byte; these historical checks were rejected
at `digest_bytes_correct`. Current validation uses the three structural public
mutations described below.

## Optimization gate

`research_validate.py` freezes the original specification, state type, public
claims through `benchmarks/proof_contract.json`. Supporting law statements and
proof bodies may change during research, including the public proof implementations
in `CORRECTNESS.bend`. The import graph stays fixed. Every supporting law must
have a checked proof, and all unchanged public declarations in `LAWS.bend` must
still be proved unconditionally. The orchestrator audits the revised proof chain. The gate also checks both execution backends and three structural
public API mutations. It runs before every candidate benchmark.

Optional GPU benchmarking invokes the same public implementation at each message-tree
leaf and checks every output against hashlib. This adds GPU execution evidence;
it does not extend the theorem to proving the Metal/CUDA compiler, scheduler,
runtime, hardware, timing behavior, or the benchmark harness.

## Specification audit and domain qualification

NIST SHA-256 conformance here is restricted to byte-aligned inputs with fewer
than 2^61 bytes, corresponding to the standard's bit-length bound below 2^64.
The universal equality laws intentionally remain unchanged: outside that domain
they describe equality to the total executable specification, whose fixed-width
length field wraps, not an extension of NIST's conformance claim.

A source audit and independent prime-root derivation confirmed all 64 round
constants and eight initial words. Direct reference execution matched both
APIs on 180 JS cases and 181 native cases; the million-byte reference JS probe
failed with a runtime memory/stack fault, while native passed. This resource
limitation does not refute the mathematical theorem or establish a failure in
the optimized implementation. Both backends passed 19 large length-field probes.

The specification's incomplete-group and short-round fallback cases appear
unreachable through its public construction. Separate machine-checked alignment,
schedule-length and round-count invariants remain possible hardening work;
this audit does not claim those additional laws have been proved. The existing
proof is equivalence to the explicit specification, whose transcription remains
within the documented trust boundary.

## Packed-array API

The additional public theorem is:

```text
for every words : Array<U32>, byte_length : Nat,
SHA.sha256_packed(words, byte_length)
  = PackedSpec.sha256(words, byte_length).
```

`packed_spec.bend` imports only Base, `fips.bend`, and the neutral state record.
It gathers blocks with a generic countdown/list accumulator, specifies padding
in packed big-endian words, and calls the independent FIPS schedule and
compression. It does not import the optimized implementation. The theorem
covers the actual public wrapper, array reads and their order, complete-block
iteration, final one/two-block processing, length bounds, and digest extraction.
Bounds and storage semantics follow Base.Array; normal native callers should
construct balanced arrays with Array.new.

`packed_proof.bend` reuses the existing compression refinement lemmas. It proves
all sixteen reader steps, each padding equation, block induction, bounds
selection, and output conversion. Internal lemmas quantify the expansion count;
the public entry point fixes it to 48. Keeping that count symbolic prevents the
checker from repeatedly expanding 64 concrete SHA rounds. It does not change
the public round count or assume compression correctness.

`packed_array_proof.bend` constructs a duplicable mathematical description of
any linear array **with a proof that reconstructing it yields that exact
array**. This permits the block proof to use an array description more than
once without violating Bend's affine rules. It is proof-only: hashing does not
copy arrays or traverse this tree. Neither the proof checker nor Base was
modified, and no axioms or unsafe declarations were added.

The packed theorem targets the packed-format reference. It is not a theorem
that an arbitrary byte-list-to-array conversion followed by packed hashing equals
`FIPS.sha256` on that list. In particular, `benchmarks/packed_input.bend` is a
measurement helper, not a verified conversion API. Padding's correspondence to
the byte-level standard is supported by reviewed equations and differential
tests, while equivalence of optimized packed execution to the packed reference
is machine checked. The original all-input byte-list-to-FIPS theorem remains
unchanged and checked.

All statements are source-level functional correctness. They do not verify the
Bend compiler's native array lowering, C compiler, allocator, CPU, timing,
side-channel behavior, or out-of-memory behavior. The stock backend's finite
runtime integer and allocation limits still apply. Native/JS differential tests
exercise these trusted components; they are not a proof of those components.
