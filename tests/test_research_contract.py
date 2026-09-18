import importlib.util
import contextlib
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


validation = module('research_validate')
benchmark = module('benchmark_sha256')


class ContractTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        contract = json.loads(validation.CONTRACT.read_text())
        for name in set(contract['frozen_sha256']) | set(validation.EDITABLE) | {'benchmarks/proof_contract.json'}:
            dest = self.root / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, dest)

    def tearDown(self):
        self.tmp.cleanup()

    def edit(self, name, before, after):
        p = self.root / name
        p.write_text(p.read_text().replace(before, after, 1))

    def test_original_contract(self):
        validation.audit(self.root)

    def test_specification_cannot_move_with_implementation(self):
        self.edit('fips.bend', '1779033703', '1779033704')
        with self.assertRaisesRegex(RuntimeError, 'Frozen trust-boundary'):
            validation.audit(self.root)

    def test_supporting_law_cannot_be_weakened(self):
        self.edit('conformance.bend', 'for +xs:', 'for xs:')
        with self.assertRaisesRegex(RuntimeError, 'Law declarations'):
            validation.audit(self.root)

    def test_foreign_import_rejected(self):
        p = self.root / 'core.bend'
        p.write_text(p.read_text() + '\nimport "cheat.c"\n')
        with self.assertRaisesRegex(RuntimeError, 'import graph'):
            validation.audit(self.root)

    def test_import_override_rejected(self):
        p = self.root / 'core.bend'
        p.write_text(p.read_text() + '\ndef U32.add(x: U32, y: U32) -> U32:\n  x\n')
        with self.assertRaisesRegex(RuntimeError, 'Overriding'):
            validation.audit(self.root)

    def test_score_uses_best_whole_mode_not_mixed_workload_winners(self):
        def timing(binary, env, expected, *options):
            size = int(env['SHA_BENCH_SIZE'])
            if not options:
                value = 100
            elif options[-1] == 'off':
                value = 5 if size in (64, 16384) else 100
            else:
                value = 100 if size in (64, 16384) else 5
            return {'median_ms': value, 'samples_ms': [value] * 5}
        with patch.object(benchmark, 'run', return_value='bend 2.0.5'), \
             patch.object(benchmark, 'gpu_hardware', return_value={'available': True, 'backend': 'test'}), \
             patch.object(benchmark, 'native_samples', side_effect=timing), \
             patch.object(benchmark, 'measure_python', return_value={'median_ms': 0.5, 'samples_ms': [0.5] * 5}), \
             contextlib.redirect_stderr(io.StringIO()):
            result = benchmark.benchmark('required')
        self.assertEqual(result['bend_mode_totals_ms'], {'sequential_cpu': 400, 'parallel_cpu': 210, 'gpu': 210})
        self.assertEqual(result['best_bend_total_ms'], 210)
        self.assertEqual(result['best_bend_mode'], 'parallel_cpu')

    def test_native_every_digest_checked(self):
        expected = [bytes.fromhex('ab' * 32), bytes.fromhex('cd' * 32)]
        good = 'BENCH_MS=100\n' + '\n'.join(x.hex() for x in reversed(expected))
        self.assertEqual(benchmark.parse_native(good, expected), 100)
        for bad in [good.replace('cd', 'ce', 1), good.splitlines()[0], good.replace('100', '0', 1)]:
            with self.assertRaises(RuntimeError):
                benchmark.parse_native(bad, expected)


if __name__ == '__main__':
    unittest.main()
