#!/usr/bin/env python3
"""Compare prebuilt list/packed native binaries; verify every retained digest."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import random
import statistics
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--list', required=True, type=Path)
    parser.add_argument('--packed', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--corpus-mib', type=int, default=32)
    args = parser.parse_args()
    if not 1 <= args.corpus_mib <= 64:
        parser.error('corpus size must be 1..64 MiB')
    binaries = {'list': args.list.resolve(), 'packed': args.packed.resolve()}
    corpus = random.Random(20260920).randbytes(args.corpus_mib * 1024**2)
    report = {
        'host': platform.platform(),
        'binary_sha256': {n: hashlib.sha256(p.read_bytes()).hexdigest() for n, p in binaries.items()},
        'corpus_bytes': len(corpus), 'corpus_sha256': hashlib.sha256(corpus).hexdigest(),
        'timer': 'Bend IO.now; milliseconds',
        'timed': 'sequential hashing and digest allocation/retention; excludes loading, packing, startup, printing',
        'warmups': 1, 'samples': 5, 'rows': [],
    }
    with tempfile.TemporaryDirectory(prefix='sha-packed-benchmark-') as tmp:
        source = Path(tmp) / 'corpus.bin'
        source.write_bytes(corpus)
        for size in [64, 1024, 16384, 65536]:
            expected = [hashlib.sha256(corpus[i:i+size]).hexdigest() for i in range(0, len(corpus), size)][::-1]
            def run(name):
                proc = subprocess.run([str(binaries[name])], env={**os.environ, 'SHA_BENCH_INPUT': str(source), 'SHA_BENCH_SIZE': str(size)}, capture_output=True, text=True, check=True, timeout=180)
                lines = proc.stdout.splitlines()
                if not lines or not lines[0].startswith('BENCH_MS=') or lines[1:] != expected:
                    raise RuntimeError(f'{name}, {size}: invalid benchmark output or digest mismatch')
                return int(lines[0].split('=')[1])
            for name in binaries:
                run(name)
            samples = {name: [] for name in binaries}
            for repetition in range(5):
                for name in (['list', 'packed'] if repetition % 2 == 0 else ['packed', 'list']):
                    samples[name].append(run(name))
            medians = {n: statistics.median(v) for n, v in samples.items()}
            row = {'message_bytes': size, 'messages': len(expected), 'samples_ms': samples, 'median_ms': medians,
                   'us_per_hash': {n: v * 1000 / len(expected) for n, v in medians.items()},
                   'speedup': medians['list'] / medians['packed'], 'every_digest_matches': True}
            report['rows'].append(row)
            args.output.write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps(row), flush=True)


if __name__ == '__main__':
    main()
