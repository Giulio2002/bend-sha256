# Objective: faster SHA-256 with the existing universal proof intact

Optimize the native Bend implementation of SHA-256. Preserve the public API's
behavior for every `List<&2, U32>`: each element contributes its low eight bits
and the result is the eight SHA-256 digest words in order. Preserve the existing
unconditional theorem `Laws.sha256_correct` against the independent `fips.bend`.

```toml
name = "SHA-256 / PROOF-PRESERVING NATIVE OPTIMIZATION"
project = "."
command = ["uv", "run", "--frozen", "python", "benchmark_sha256.py", "--gpu", "required"]
validation = ["uv", "run", "--frozen", "python", "research_validate.py"]
metric = "best_bend_total_ms"
direction = "min"
patience = 3
max_iterations = 8
repeats = 3
min_delta = 0.0
min_relative_delta = 0.03
benchmark_timeout = 1200
agent_timeout = 1200
orchestrator_timeout = 600
model = "gpt-5.6-sol"
orchestrator_model = "gpt-5.6-sol"
editable = ["core.bend", "sha256.bend", "conformance.bend", "list_proofs.bend", "padding_proof.bend"]
protected = ["fips.bend", "state.bend", "LAWS.bend", "CORRECTNESS.bend", "PROOF.bend", "test_sha256.py", "research_validate.py", "benchmark_sha256.py", "benchmarks/**", "pyproject.toml", "uv.lock", "OBJECTIVE.md", "ORCHESTRATOR.MD"]
ignore = []
```

## Measure

Run `uv run --frozen python research_validate.py` before benchmarking. Any failure
rejects the candidate. Then run `uv run --frozen python benchmark_sha256.py --gpu required`.
The final stdout line is JSON. The score is `best_bend_total_ms`: for each Bend execution mode, sum its median
batch times across 64-, 1,024-, 16,384-, and 65,536-byte messages. Select the lowest complete-suite total across sequential CPU, parallel CPU and
GPU. Do not mix the best per-size samples from different modes. Each
workload hashes exactly 1 MiB of deterministic runtime-loaded binary data.
Each has an untimed warmup and five measured samples; every digest is checked.
Autoresearch repeats the complete benchmark three times and compares medians.

The Python leaderboard measures hashlib, PyCryptodome and cryptography. It is
context, not the optimization metric: slowing down a reference cannot improve
the score. "Fastest Python" means fastest among those measured on this machine.
The GPU check is mandatory on this Metal-capable machine. It also measures the
same proved public hash on a balanced parallel message tree, once with GPU
forced off and once with GPU forced on. Every GPU digest is checked. GPU and
parallel CPU totals are reported separately; the optimization metric is the
fastest complete-suite Bend mode, which may change between candidates. No CPU fallback may be labeled a GPU result.

Compilation, process startup, file loading, message chunking, hex conversion and
output are excluded. Hashing, digest production and result retention are timed.
Do not change batching, timers, compiler flags, runtime, environment, or inputs.

## Formal correctness is a hard gate

`research_validate.py` checks the frozen trust boundary, checks the universal
and concrete Bend proofs, runs 182 differential cases on JS and native backends,
and requires the universal theorem to reject three type-correct public API
mutations. This is mandatory for every candidate before measurement.

You may change the implementation and supporting proof bodies in the editable
files. Existing supporting law statements and imports are frozen by
`benchmarks/proof_contract.json`. New local, terminating helper definitions are
allowed. Do not change the independent specification, shared state type, public
theorem, universal gate, fixed-vector proofs, checker or dependencies. Do not
weaken a statement, add assumptions or new laws, use holes or unsafe annotations,
introduce foreign code, override imported definitions, or bypass termination.

The original 12 text-based mutation checks in `test_sha256.py` still run by
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
can prove within the frozen statements, such as redundant traversal removal,
allocation reduction, or equivalent primitive expressions. If proof checking
fails, repair the proof within scope or abandon the change.

An independent read-only orchestrator must approve each measured improvement.
A gain must exceed 3 percent. Stop after three consecutive attempts without an
approved improvement, with an absolute cap of eight attempts. Keep all failures
and review reasons. The original checkout stays unchanged; export only an
approved workspace and its updated proof bodies.
