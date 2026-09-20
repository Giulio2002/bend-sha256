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

    def test_supporting_law_can_be_renamed_with_complete_proof(self):
        p = self.root / 'conformance.bend'
        p.write_text(p.read_text().replace('count_acc', 'optimized_count_acc'))
        validation.audit(self.root)
        result = validation.checked(['bend', 'CORRECTNESS.bend'], cwd=self.root)
        self.assertIn('All terms check.', result)

    def test_new_proved_law_is_accepted(self):
        p = self.root / 'conformance.bend'
        p.write_text(p.read_text() + '\nlaw helper_identity:\n  for +x: U32\n  {x == x : U32}\n\ndef helper_identity(x):\n  {==}\n')
        validation.audit(self.root)
        self.assertIn('All terms check.', validation.checked(['bend', 'CORRECTNESS.bend'], cwd=self.root))

    def test_unproved_supporting_law_is_rejected(self):
        p = self.root / 'conformance.bend'
        p.write_text(p.read_text() + '\nlaw unproved:\n  {0 == 1 : U32}\n')
        with self.assertRaisesRegex(RuntimeError, 'Supporting law'):
            validation.audit(self.root)

    def test_false_proof_is_rejected_by_checker(self):
        p = self.root / 'conformance.bend'
        p.write_text(p.read_text() + '\nlaw false_claim:\n  {0 == 1 : U32}\n\ndef false_claim():\n  {==}\n')
        validation.audit(self.root)
        validation.checked(['bend', 'CORRECTNESS.bend'], cwd=self.root, expect_failure=True)

    def test_public_claim_is_still_frozen(self):
        self.edit('LAWS.bend', 'for +bytes:', 'for bytes:')
        with self.assertRaisesRegex(RuntimeError, 'Frozen trust-boundary'):
            validation.audit(self.root)

    def test_public_proof_cannot_be_removed(self):
        self.edit('CORRECTNESS.bend', 'def Laws.sha256_correct(', 'def removed(')
        with self.assertRaisesRegex(RuntimeError, 'Every frozen public claim'):
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
                value = 100 if size in (64, 16384) else 5
            elif options[-1] == 'off':
                value = 5 if size in (64, 16384) else 100
            else:
                value = 1
            return {'median_ms': value, 'samples_ms': [value] * 5}
        with patch.object(benchmark, 'run', return_value='bend 2.0.16'), \
             patch.object(benchmark, 'gpu_hardware', return_value={'available': True, 'backend': 'test'}), \
             patch.object(benchmark, 'native_samples', side_effect=timing), \
             patch.object(benchmark, 'measure_python', return_value={'median_ms': 0.5, 'samples_ms': [0.5] * 5}), \
             contextlib.redirect_stderr(io.StringIO()):
            result = benchmark.benchmark('required')
        self.assertEqual(result['bend_mode_totals_ms'], {'sequential_cpu': 210, 'parallel_cpu': 210})
        self.assertEqual(result['best_bend_total_ms'], 210)
        self.assertEqual(result['best_bend_mode'], 'sequential_cpu')
        self.assertEqual(result['bend_gpu_total_ms'], 4)

    def test_gpu_off_keeps_parallel_cpu_without_hardware_detection(self):
        with patch.object(benchmark, 'run', return_value='bend 2.0.16'), \
             patch.object(benchmark, 'gpu_hardware', side_effect=AssertionError('GPU detection must not run')), \
             patch.object(benchmark, 'native_samples', return_value={'median_ms': 100, 'samples_ms': [100] * 5}) as timing, \
             patch.object(benchmark, 'measure_python', return_value={'median_ms': 0.5, 'samples_ms': [0.5] * 5}), \
             contextlib.redirect_stderr(io.StringIO()):
            result = benchmark.benchmark()
        self.assertEqual(result['bend_mode_totals_ms'], {'sequential_cpu': 400, 'parallel_cpu': 400})
        self.assertNotIn('bend_gpu_total_ms', result)
        self.assertEqual(timing.call_count, 8)
        for call in timing.call_args_list[1::2]:
            self.assertEqual(call.args[-2:], ('--gpu', 'off'))

    def test_sequential_only_never_builds_or_measures_parallel(self):
        with patch.object(benchmark, 'run', return_value='bend 2.0.16') as run, \
             patch.object(benchmark, 'gpu_hardware', side_effect=AssertionError('No GPU detection')), \
             patch.object(benchmark, 'native_samples', return_value={'median_ms': 100, 'samples_ms': [100] * 5}) as timing, \
             patch.object(benchmark, 'measure_python', return_value={'median_ms': 0.5, 'samples_ms': [0.5] * 5}), \
             contextlib.redirect_stderr(io.StringIO()):
            result = benchmark.benchmark(sequential_only=True)
        self.assertEqual(result['scored_modes'], ['sequential_cpu'])
        self.assertEqual(result['metric'], 'bend_total_ms')
        self.assertEqual(result['bend_mode_totals_ms'], {'sequential_cpu': 400})
        self.assertEqual(timing.call_count, 4)
        self.assertFalse(any('benchmarks/gpu_driver.bend' in c.args[0] for c in run.call_args_list))
        self.assertNotIn('bend_parallel_cpu_total_ms', result)

    def test_sequential_only_rejects_gpu_request(self):
        with self.assertRaises(ValueError):
            benchmark.benchmark('required', sequential_only=True)

    def test_short_batches_trigger_calibration_not_candidate_failure(self):
        with patch.object(benchmark, 'benchmark_once', side_effect=[benchmark.BatchTooShort('short'), {'best_bend_total_ms': 5}]) as once, contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(benchmark.benchmark()['best_bend_total_ms'], 5)
        self.assertEqual([c.args[1] for c in once.call_args_list], [1048576, 2097152])

    def test_calibration_limit_fails_without_fabricating_score(self):
        with patch.object(benchmark, 'MAX_CORPUS_BYTES', 2 * 1048576), patch.object(benchmark, 'benchmark_once', side_effect=benchmark.BatchTooShort('short')) as once, contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, 'maximum batch size'):
                benchmark.benchmark()
        self.assertEqual(once.call_count, 2)

    def test_short_batch_still_checks_every_digest(self):
        with self.assertRaisesRegex(RuntimeError, 'digest'):
            benchmark.parse_native('BENCH_MS=5\nwrong', [bytes(32)])
        with self.assertRaises(benchmark.BatchTooShort):
            benchmark.parse_native('BENCH_MS=5\n' + bytes(32).hex(), [bytes(32)])

    def test_native_normalization_retains_raw_samples(self):
        with patch.object(benchmark, 'run', return_value='BENCH_MS=80\n' + bytes(32).hex()):
            value = benchmark.native_samples(Path('/unused'), {'SHA_BENCH_BYTES': str(8 * 1048576)}, [bytes(32)])
        self.assertEqual(value['median_ms'], 10)
        self.assertEqual(value['raw_samples_ms'], [80] * 5)

    def test_native_every_digest_checked(self):
        expected = [bytes.fromhex('ab' * 32), bytes.fromhex('cd' * 32)]
        good = 'BENCH_MS=100\n' + '\n'.join(x.hex() for x in reversed(expected))
        self.assertEqual(benchmark.parse_native(good, expected), 100)
        for bad in [good.replace('cd', 'ce', 1), good.splitlines()[0], good.replace('100', '0', 1)]:
            with self.assertRaises(RuntimeError):
                benchmark.parse_native(bad, expected)


if __name__ == '__main__':
    unittest.main()
