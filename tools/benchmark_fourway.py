#!/usr/bin/env python3
"""One sequential SHA-256 comparison: Bend, hashlib, Go and Lean."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import random
import ssl
import statistics
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def parse_output(output, expected):
    lines = output.splitlines()
    if not lines or not lines[0].startswith('BENCH_MS='):
        raise ValueError('Missing in-process timing')
    elapsed = float(lines[0].split('=', 1)[1])
    if not math.isfinite(elapsed) or elapsed <= 0:
        raise ValueError('Timing must be positive and finite')
    if lines[1:] != expected:
        raise ValueError('Digest mismatch or missing/extra digest')
    return elapsed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['bend', 'go', 'lean']:
        parser.add_argument('--'+name, required=True, type=Path, help='Prebuilt executable')
    parser.add_argument('--lean-source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--corpus-mib', type=int, default=32)
    args = parser.parse_args()
    if not 1 <= args.corpus_mib <= 64:
        parser.error('corpus must be 1..64 MiB')
    binaries = {n: getattr(args, n).resolve() for n in ['bend', 'go', 'lean']}
    commands = {n: [str(p)] for n, p in binaries.items()}
    commands['hashlib'] = [sys.executable, str(ROOT/'benchmarks/fourway/hashlib_driver.py')]
    corpus = random.Random(20260920).randbytes(args.corpus_mib * 1024**2)
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    lean_commit = subprocess.check_output(['git', '-C', str(args.lean_source), 'rev-parse', 'HEAD'], text=True).strip()
    lean_core = args.lean_source/'LeanSha256/Core.lean'
    # Reject an accidentally modified competitor implementation.
    subprocess.run(['git', '-C', str(args.lean_source), 'diff', '--exit-code', 'HEAD', '--', 'LeanSha256/Core.lean', 'LeanSha256.lean'], check=True)
    report = {
        'host': platform.platform(), 'python': sys.version, 'openssl': ssl.OPENSSL_VERSION,
        'hashlib_constructor': repr(hashlib.sha256), 'lean_commit': lean_commit,
        'lean_core_sha256': sha(lean_core), 'binary_sha256': {n: sha(p) for n, p in binaries.items()},
        'source_sha256': {str(p.relative_to(ROOT)): sha(p) for p in [ROOT/'packed.bend', ROOT/'core.bend', ROOT/'benchmarks/packed_driver.bend', *sorted((ROOT/'benchmarks/fourway').glob('*'))] if p.is_file()},
        'corpus_bytes': len(corpus), 'corpus_sha256': hashlib.sha256(corpus).hexdigest(),
        'sequential': True, 'samples_per_workload': 5, 'warmups_per_workload': 1,
        'timing': 'In-process hashing, result allocation and retention; input loading/chunking/packing and output formatting excluded.',
        'api_inputs': 'Bend: packed U32 Array; Python: bytes; Go: byte slices; Lean: ByteArray. Prepared before timing.',
        'acceleration': 'Bend and Lean pure software; Go and Python use their standard default implementations, including available hardware acceleration.',
        'timers': {'bend': 'IO.now milliseconds', 'hashlib': 'perf_counter_ns', 'go': 'time.Since nanoseconds', 'lean': 'IO.monoNanosNow'},
        'caveat': 'Shared hosts, no exclusive CPU reservation; compiler and OS differences affect cross-host comparisons.',
        'rows': [],
    }
    order = ['bend', 'hashlib', 'go', 'lean']
    with tempfile.TemporaryDirectory(prefix='sha-fourway-') as tmp:
        path = Path(tmp)/'corpus.bin'; path.write_bytes(corpus)
        for size in [64, 1024, 16384, 65536]:
            expected = [hashlib.sha256(corpus[i:i+size]).hexdigest() for i in range(0, len(corpus), size)][::-1]
            def run(name):
                result = subprocess.run(commands[name], env={**os.environ, 'SHA_BENCH_INPUT': str(path), 'SHA_BENCH_SIZE': str(size)}, capture_output=True, text=True, check=True, timeout=300)
                return parse_output(result.stdout, expected)
            for name in order:
                run(name)
            samples = {n: [] for n in order}
            for repetition in range(5):
                for name in order[repetition % 4:] + order[:repetition % 4]:
                    samples[name].append(run(name))
            medians = {n: statistics.median(v) for n, v in samples.items()}
            row = {'message_bytes': size, 'messages': len(expected), 'samples_ms': samples, 'median_ms': medians,
                   'us_per_hash': {n: v*1000/len(expected) for n, v in medians.items()},
                   'MiB_per_second': {n: args.corpus_mib*1000/v for n, v in medians.items()}, 'all_digests_match': True}
            report['rows'].append(row)
            args.output.write_text(json.dumps(report, indent=2)+'\n')
            print(json.dumps(row), flush=True)


if __name__ == '__main__':
    main()
