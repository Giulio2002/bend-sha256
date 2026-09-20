"""Keep proof-only list models out of the production dependency graph."""
import re
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ArrayRuntimeTests(unittest.TestCase):
    def test_public_dependency_graph_has_no_list_storage_or_proof_models(self):
        pending = [ROOT / 'sha256.bend']
        seen = set()
        while pending:
            p = pending.pop().resolve()
            if p in seen:
                continue
            seen.add(p)
            code = '\n'.join(line.split('#', 1)[0] for line in p.read_text().splitlines())
            self.assertNotRegex(code, r'\b(?:List|Nil|Cons)\b', p.name)
            for name in re.findall(r'^import (\S+)', code, re.M):
                if name != 'Base':
                    pending.append(p.parent / name)
        self.assertEqual({p.name for p in seen},
                         {'sha256.bend', 'buffer.bend', 'packed.bend', 'core.bend', 'state.bend'})
