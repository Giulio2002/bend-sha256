#!/usr/bin/env python3
"""Test the public packed API against hashlib, including dirty unused storage."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bend', default='bend')
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    rng = random.Random(712)
    expected = []
    definitions = []
    lengths = list(range(130)) + [255, 256, 257, 1023, 1024, 1025, 16384, 65536]
    for i, length in enumerate(lengths):
        capacity = 1 << max(0, ((length + 3) // 4 - 1).bit_length()) if length else 1
        seed = rng.randrange(2**32)
        words = [((j * 2654435761) ^ seed) & 0xffffffff for j in range(capacity)]
        data = b''.join(w.to_bytes(4, 'big') for w in words)
        lines = [f'def case_{i}() -> Maybe<&2,List<&2,U32>>:',
                 f'  a = fill({capacity}n,0,{seed},Array.new(U32,{capacity.bit_length()-1}n,0))',
                 f'  SHA.sha256_packed(a,{length}n)']
        definitions.append('\n'.join(lines))
        expected.append(hashlib.sha256(data[:length]).hexdigest())
    # Reject over-capacity lengths, including a large Nat. Empty input is valid.
    for depth, length in [(0,5), (1,9), (4,65), (0,4294967295)]:
        i = len(expected)
        definitions.append(f'def case_{i}() -> Maybe<&2,List<&2,U32>>:\n  SHA.sha256_packed(Array.new(U32,{depth}n,0),{length}n)')
        expected.append('NONE')
    source = """import Base
import ../sha256.bend as SHA

def fill(n: Nat, +index: U32, +seed: U32, a: Array<U32>) -> Array<U32>:
  match n:
    case 0n: a
    case 1n+p:
      fill(p,U32.inc(index),seed,Array.set(U32,a,index,U32.xor(U32.mul(index,2654435761),seed)))

""" + '\n\n'.join(definitions)
    source += '\n\ndef show(r: Maybe<&2,List<&2,U32>>) -> String:\n  match r:\n    case None{}: "NONE"\n    case Some{ws}: SHA.hex(ws)\n\ndef main() -> IO(Unit):\n  do IO<Unit>:\n'
    source += ''.join(f'    IO.print(show(case_{i}()))\n' for i in range(len(expected)))
    with tempfile.TemporaryDirectory(prefix='.test-packed-', dir=ROOT) as tmp:
        driver = Path(tmp) / 'cases.bend'
        driver.write_text(source)
        commands = {'js': [args.bend, str(driver)]}
        if args.native:
            binary = Path(tmp) / 'cases'
            subprocess.run([args.bend, str(driver), '-o', str(binary)], cwd=ROOT, check=True, timeout=300)
            commands['native'] = [str(binary)]
        for name, command in commands.items():
            result = subprocess.run(command, cwd=ROOT, check=True, capture_output=True, text=True, timeout=300)
            actual = result.stdout.splitlines()
            if actual != expected:
                raise AssertionError((name, next(((i, a, b) for i, (a, b) in enumerate(zip(actual, expected)) if a != b), ('length', len(actual), len(expected)))))
            print(f'{name}: {len(expected)} packed API cases pass ({len(lengths)} digests, 4 invalid lengths)', flush=True)


if __name__ == '__main__':
    main()
