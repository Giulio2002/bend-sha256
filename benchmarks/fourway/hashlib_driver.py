"""Standard-library hashlib, sequential, with input setup outside timing."""
import hashlib
import os
from pathlib import Path
import time

size = int(os.environ['SHA_BENCH_SIZE'])
corpus = Path(os.environ['SHA_BENCH_INPUT']).read_bytes()
if size < 1 or len(corpus) % size:
    raise ValueError('invalid message size/batch')
inputs = [corpus[i:i+size] for i in range(0, len(corpus), size)]
start = time.perf_counter_ns()
outputs = [hashlib.sha256(message).digest() for message in inputs]
elapsed = time.perf_counter_ns() - start
print(f'BENCH_MS={elapsed / 1e6:.6f}')
for digest in reversed(outputs):
    print(digest.hex())
