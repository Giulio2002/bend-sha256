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
Universal proof mutation checks: 12 algorithm defects rejected without test vectors
JS: 182 SHA-256 cases passed
Native: 182 SHA-256 cases passed
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
