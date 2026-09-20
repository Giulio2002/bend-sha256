#!/usr/bin/env python3
"""Require the fixed universal packed proof to reject implementation mutations."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
MUTATIONS = [
    ('padding marker', 'case 0n: 2147483648', 'case 0n: 0'),
    ('partial-byte mask', 'U32.and(w,4278190080)', 'U32.and(w,4294901760)'),
    ('word index', 'read2(extra,U32.inc(index),s,w0,at(a,U32.inc(index)))', 'read2(extra,U32.inc(index),s,w0,at(a,index))'),
    ('bounds check', 'checked(Nat.is_le(length,Nat.mul(4n,U32.to_nat(capacity)))', 'checked(Nat.is_lt(length,Nat.mul(4n,U32.to_nat(capacity)))'),
    ('compression word order', 'Core.fips_compress16(w0,w1,w2', 'Core.fips_compress16(w1,w0,w2'),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bend', default='bend')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    imports = re.findall(r'^import (.+)$', (ROOT / 'packed_spec.bend').read_text(), re.M)
    if imports != ['Base', './fips.bend as F', './state.bend as S']:
        raise RuntimeError(f'Packed specification imports implementation code: {imports}')
    report = []
    for name, before, after in MUTATIONS + [('digest word order', 'ALeaf{a},ALeaf{b}', 'ALeaf{b},ALeaf{a}')]:
        with tempfile.TemporaryDirectory(prefix='.test-packed-mutation-', dir=ROOT) as tmp:
            target = Path(tmp)
            for source in ROOT.glob('*.bend'):
                (target / source.name).write_bytes(source.read_bytes())
            impl = target / ('buffer.bend' if name == 'digest word order' else 'packed.bend')
            text = impl.read_text()
            if text.count(before) != 1:
                raise RuntimeError(f'Mutation anchor is not unique: {name}')
            impl.write_text(text.replace(before, after))
            subprocess.run([args.bend, str(impl)], check=True, capture_output=True, text=True, timeout=60)
            started = time.monotonic()
            result = subprocess.run([args.bend, str(target / 'CORRECTNESS.bend')], capture_output=True, text=True, timeout=180)
            elapsed = time.monotonic() - started
            diagnostic = result.stdout + result.stderr
            # A timeout, crash, parse error, or missing-name error is not proof rejection.
            if result.returncode != 1 or 'Error:' not in diagnostic or 'Location:' not in diagnostic or '- expected :' not in diagnostic or 'a defined name' in diagnostic:
                raise RuntimeError(f'{name}: no valid proof rejection\n{diagnostic[-3000:]}')
            location = diagnostic.split('Location:')[1].splitlines()[0].strip()
            report.append({'mutation': name, 'rejected': True, 'proof_location': location, 'seconds': elapsed})
            print(f'{name}: proof rejected at {location} ({elapsed:.2f}s)', flush=True)
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
