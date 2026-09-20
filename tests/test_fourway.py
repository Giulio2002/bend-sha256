"""A fast guard against accepting fabricated/partial benchmark results."""
import importlib.util
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('fourway',Path(__file__).resolve().parents[1]/'tools/benchmark_fourway.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)


class FourWayTests(unittest.TestCase):
    def test_checks_every_digest_not_only_the_first(self):
        with self.assertRaisesRegex(ValueError,'Digest mismatch'):
            module.parse_output('BENCH_MS=10\ncorrect\nwrong\n',['correct','second'])

    def test_rejects_missing_extra_and_nonfinite_measurements(self):
        for output in ['BENCH_MS=nan\na\n','BENCH_MS=inf\na\n','BENCH_MS=0\na\n','BENCH_MS=-1\na\n','BENCH_MS=10\n','BENCH_MS=10\na\nextra\n','a\n']:
            with self.subTest(output=output),self.assertRaises(ValueError):
                module.parse_output(output,['a'])

    def test_valid_timing_and_all_outputs(self):
        self.assertEqual(module.parse_output('BENCH_MS=10.125\na\nb\n',['a','b']),10.125)
