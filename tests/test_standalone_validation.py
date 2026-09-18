"""Regression checks for standalone validation under optimized Python."""
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]


class StandaloneValidationTests(unittest.TestCase):
    def test_invalid_output_is_rejected_with_and_without_optimization(self):
        for mode in ([], ['-O'], ['-OO']):
            for output in ('0' * 64, ''):
                with self.subTest(mode=mode, output=output):
                    script = f"import test_sha256 as t; t.verify({output!r}, ['f'*64], 'regression')"
                    result = subprocess.run([sys.executable, *mode, '-c', script],
                                            cwd=ROOT, capture_output=True, text=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('RuntimeError', result.stderr)
                    self.assertNotIn('cases passed', result.stdout)

    def test_valid_output_passes_under_optimization(self):
        result = subprocess.run([sys.executable, '-O', '-c',
                                 "import test_sha256 as t; t.verify('f'*64, ['f'*64], 'regression')"],
                                cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('1 SHA-256 cases passed', result.stdout)

    def test_mutation_options_are_mutually_exclusive(self):
        result = subprocess.run([sys.executable, 'test_sha256.py', '--skip-mutations', '--legacy-mutations'],
                                cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('not allowed', result.stderr)
