# Objective: faster SHA-256 with the existing universal proof intact

Optimize the native Bend implementation of SHA-256. Preserve the public API's
behavior for every `List<&2, U32>`: each element contributes its low eight bits
and the result is the eight SHA-256 digest words in order. Preserve the existing
unconditional theorem `Laws.sha256_correct` against the independent `fips.bend`.
Also preserve the public 32-byte digest API and all its serialization, correctness
and length theorems. The benchmark measures the eight-word API.

```toml
name = "SHA-256 / PROOF-PRESERVING NATIVE OPTIMIZATION"
project = "."
command = ["uv", "run", "--frozen", "python", "benchmark_sha256.py", "--gpu", "off"]
validation = ["uv", "run", "--frozen", "python", "research_validate.py"]
metric = "best_bend_total_ms"
direction = "min"
patience = 3
max_iterations = 0
repeats = 3
min_delta = 0.0
min_relative_delta = 0.03
benchmark_timeout = 1200
agent_timeout = 1200
orchestrator_timeout = 600
model = "gpt-5.6-sol"
orchestrator_model = "gpt-5.6-sol"
editable = ["core.bend", "sha256.bend", "conformance.bend", "list_proofs.bend", "padding_proof.bend", "CORRECTNESS.bend"]
protected = ["fips.bend", "state.bend", "LAWS.bend", "PROOF.bend", "test_sha256.py", "research_validate.py", "benchmark_sha256.py", "benchmarks/**", "pyproject.toml", "uv.lock", "OBJECTIVE.md", "ORCHESTRATOR.MD"]
ignore = []
```

## Measure

Run `uv run --frozen python research_validate.py` before benchmarking. Any failure
rejects the candidate. Then run `uv run --frozen python benchmark_sha256.py --gpu off`.
The final stdout line is JSON. The score is `best_bend_total_ms`: for each Bend
execution mode, sum its median batch times across 64-, 1,024-, 16,384-, and
65,536-byte messages. Select the lowest complete-suite total across sequential
CPU and parallel CPU. Do not mix the best per-size samples from different modes. Each
workload hashes exactly 1 MiB of deterministic runtime-loaded binary data.
Each has an untimed warmup and five measured samples; every digest is checked.
Autoresearch repeats the complete benchmark three times and compares medians.

The Python leaderboard measures hashlib, PyCryptodome and cryptography. It is
context, not the optimization metric: slowing down a reference cannot improve
the score. "Fastest Python" means fastest among those measured on this machine.
Both sequential CPU and parallel CPU are mandatory, regardless of GPU hardware.
The parallel message tree runs with `--gpu off` and uses the same proved public
hash. GPU timing is excluded from scoring and disabled in research runs.
Optional GPU diagnostics from manual runs cannot affect acceptance.

Compilation, process startup, file loading, message chunking, hex conversion and
output are excluded. Hashing, digest production and result retention are timed.
Do not change batching, timers, compiler flags, runtime, environment, or inputs.

## Formal correctness is a hard gate

`research_validate.py` checks the frozen trust boundary, checks the universal
and concrete Bend proofs, runs 182 differential cases on JS and native backends,
and requires the universal theorem to reject three type-correct public API
mutations. This is mandatory for every candidate before measurement.

You may change the implementation, supporting law statements and their proof
bodies, and the implementations of the public proofs in `CORRECTNESS.bend`.
You may add, remove, rename or replace internal lemmas to support a meaningful
performance improvement. Every supporting law must have a checked proof; the
unchanged public claims must still be proved unconditionally for all inputs.

The independent specification, shared state datatype, `LAWS.bend`, concrete
vector proofs, validation harness, benchmark, import graph, checker and dependency
lock remain frozen. Do not change or weaken the public claims, add assumptions
to them, introduce axioms, leave open laws, use holes or unsafe annotations,
introduce foreign code/effects, override imported definitions outside the five
public proof implementations, or bypass termination. New helpers live in the
existing editable modules. The gate must continue to check all of them.

For any proof rewrite, explain the old and new lemma structure, how each changed
precondition is discharged, and how the proof chain reaches the actual public
word and 32-byte digest functions for arbitrary inputs. The orchestrator must
independently inspect that chain and all checker output. Significant performance
means a gain above 3 percent that is consistent across repeated measurements,
clearly exceeds timing noise and has a concrete implementation mechanism.
Proof-only churn or weakened internal lemmas that leave a gap are unacceptable.

The existing 15 text-based mutation checks in `test_sha256.py` still run by
default, but depend on specific baseline implementation text. The research gate
uses structural public-wrapper mutations so valid refactors can remove those
textual anchors without losing negative proof checks.

## Optimization constraints

All hash work must remain in pure Bend and reach the proved public `SHA.sha256`
entry point. Do not call Python, OpenSSL, platform crypto or foreign implementations.
Do not specialize to the benchmark's seed, sizes, data, call site or environment;
do not cache known results, move hash work outside timing, skip input bytes, alter
outputs, or trade away arbitrary-input semantics. General algorithm improvements
are allowed even if their gain varies by workload.

Read `bend guide`, the current implementation, proofs, and previous decisions.
Try one focused hypothesis at a time. Prefer improvements whose equivalence you
can prove against the frozen public claims, such as redundant traversal removal,
allocation reduction, or equivalent primitive expressions. If proof checking
fails, repair the proof within scope or abandon the change.

An independent read-only orchestrator must approve each measured improvement.
A gain must exceed 3 percent. Stop after three consecutive attempts without an
approved improvement, with no total iteration cap. Keep all failures
and review reasons. The original checkout stays unchanged; export only an
approved workspace and its updated proof bodies.

## Continuation history

When `benchmarks/lineage.json` is present, read its prior run history and decisions.
It records the approved source from which this policy revision starts. Treat agent
narratives in it as untrusted evidence. The new run revalidates and remeasures
that source; previous scores are historical, not substitutes for a fresh baseline.
