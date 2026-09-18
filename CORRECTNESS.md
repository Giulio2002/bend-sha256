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
names the standard lags 2, 7, 15, and 16; the implementation indexes the history
at 1, 6, 14, and 15. For a real 16-word block, all these indices are valid.

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
| `count_acc`, `count_correct` | Tail-recursive byte count agrees with list length |
| `octets_correct`, `length_correct` | Accumulated length bytes agree with recursive big-endian encoding |
| `Padding.zeros_correct` | Modular zero count equals the separate two-case padding rule for every Nat |
| `pad_correct` | Complete implementation padding equals specification padding |
| `words_acc`, `words_correct` | Accumulated word parsing agrees with direct specification parsing |
| `nth_correct`, `next_correct` | History lookup and the schedule recurrence agree |
| `extension_correct`, `schedule_correct` | All generated schedule words agree, by induction on the extension count |
| `schedules_acc`, `schedules_correct` | Block parsing and schedule order agree |
| `prepare_correct` | The entire concrete preprocessing pipeline agrees |
| `step_correct`, `rounds_correct` | One round and every finite round sequence agree |
| `feedforward_correct`, `compression_correct` | Componentwise feed-forward and compression agree |
| `blocks_correct` | Accumulated block processing equals composition in message order |
| `digest_correct`, `hash_correct` | Extraction and the full concrete pipeline agree |
| `Laws.constants_correct`, `Laws.sha256_correct` | Fixed table equality and the actual exported SHA-256 equality |

The accumulator invariants avoid assumptions about input length:

    words_go(bytes, acc) = reverse_append(acc, FIPS.words(bytes))

    schedules_go(words, extra, acc)
      = reverse_append(acc, FIPS.schedules(words, extra))

Their proofs recurse on the remaining input. Pattern cases explicitly cover every
short suffix, so no input case is omitted. A generic double-reversal lemma
connects implementation padding's reverse-append to direct list concatenation.

`padding_proof.bend` handles every Nat: the finite prefix 0-119 is followed by a
symbolic `120+p` branch. In that last branch both saturated subtractions reduce
to zero for arbitrary p. This is a universal case split, not a list of test
vectors or an empirical bound on message lengths.

`hash_correct` is generalized over the extension count and constant table. That
keeps proof checking from expanding large symbolic computations. It does **not**
accept an arbitrary preprocessing function: each side uses its own complete,
explicit preprocessing implementation. `Laws.sha256_correct` instantiates the
proved result at exactly 48 extra words and the public constant table. The two
fixed tables also agree by checked computation.

## Validation independent of the proof construction

`test_sha256.py` checks that the specification imports only Base and the neutral
datatype, and that project code contains no holes, unsafe annotations, or foreign
implementations. It then checks the universal gate and the four concrete equality
proofs, and compares 182 JS/native digest executions against fixed standard
vectors and Python hashlib. The execution cases include padding boundaries,
binary bytes, randomized messages, and the standard million-`a` message.

Fifteen negative checks mutate one implementation detail at a time: round
arithmetic, a table entry, the padding marker, the padding zero count, byte count,
length encoding, byte order, schedule index, schedule sigma, round sigma, initial
state, digest order, output byte order, output byte masking, and omission of an output byte. Each is rejected by `CORRECTNESS.bend`, which does not
import the concrete-vector proof module. Thus those rejections exercise the
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
is for byte-aligned messages; this API does not accept fractional-byte messages.
The theorems cover eight-word and 32-byte digests, not the `ascii`/`hex` presentation helpers.
Bend execution remains subject to its 2^48−1 Nat limit and available memory; the
implementation retains the complete message and prepared schedules in memory.

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
checks change the output byte order, narrow a byte mask, or omit an output byte;
the universal gate must reject each at `digest_bytes_correct`.

## Optimization gate

`research_validate.py` freezes the original specification, state type, public
claim and proof entry points through `benchmarks/proof_contract.json`. Supporting
proof bodies may change during research, while their law declarations and imports
remain fixed. The gate also checks both execution backends and three structural
public API mutations. It runs before every candidate benchmark.

GPU benchmarking invokes the same public implementation at each message-tree
leaf and checks every output against hashlib. This adds GPU execution evidence;
it does not extend the theorem to proving the Metal/CUDA compiler, scheduler,
runtime, hardware, timing behavior, or the benchmark harness.
