#!/usr/bin/env python3
"""Mandatory proof, contract, negative-proof, JS and native validation gate."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
CONTRACT = ROOT / "benchmarks" / "proof_contract.json"
EDITABLE = ("core.bend", "sha256.bend", "conformance.bend", "list_proofs.bend", "padding_proof.bend", "CORRECTNESS.bend", "packed.bend", "packed_proof.bend", "packed_array_proof.bend", "buffer.bend", "buffer_proof.bend", "legacy_model.bend", "core_model.bend")


def code_only(text):
    return "\n".join(line.split("#", 1)[0].rstrip() for line in text.splitlines())


def laws(text):
    # Freeze complete top-level law declarations, not proof bodies.
    return re.findall(r"^law [^\n]+(?:\n(?:[ \t]+[^\n]*|))*(?=\n\S|\Z)", code_only(text), re.M)


def audit(root=ROOT):
    contract = json.loads((root / "benchmarks" / "proof_contract.json").read_text())
    for name, expected in contract["frozen_sha256"].items():
        if hashlib.sha256((root / name).read_bytes()).hexdigest() != expected:
            raise RuntimeError(f"Frozen trust-boundary file changed: {name}")
    for name in EDITABLE:
        source = code_only((root / name).read_text())
        if re.search(r"@\s*unsafe\b|\?|\b(?:IO|File|Socket|Listener|Chan)\.", source):
            raise RuntimeError(f"Unsafe annotations, holes, or effects are forbidden in {name}")
        imports = re.findall(r"^\s*import (.+)$", source, re.M)
        if imports != contract["imports"][name]:
            raise RuntimeError(f"Frozen import graph changed: {name}")
        declarations = re.findall(r"^\s*(def|law|type)\s+([^\s(:]+)", source, re.M)
        definitions = [symbol for kind, symbol in declarations if kind == "def"]
        allowed = set(contract["public_proof_definitions"]) if name == "CORRECTNESS.bend" else set()
        if any("." in symbol and not (kind == "def" and symbol in allowed)
               for kind, symbol in declarations):
            raise RuntimeError(f"Overriding imported definitions is forbidden in {name}")
        if name == "CORRECTNESS.bend" and any(definitions.count(symbol) != 1 for symbol in allowed):
            raise RuntimeError("Every frozen public claim needs exactly one proof definition")
        for kind, symbol in declarations:
            if kind == "law" and definitions.count(symbol) != 1:
                raise RuntimeError(f"Supporting law must have exactly one proof definition: {name}:{symbol}")
    print("Trust boundary: frozen specification, public claims and imports intact; all revised supporting laws require proofs", flush=True)


def checked(command, cwd=ROOT, timeout=600, expect_failure=False):
    result = subprocess.run(command, cwd=cwd, text=True, capture_output=True,
                            env={**os.environ, "BEND_NO_TELEMETRY": "1", "PYTHONOPTIMIZE": "0"}, timeout=timeout)
    output = result.stdout + result.stderr
    if expect_failure:
        if result.returncode == 0 or "Error:" not in output or "All terms check." in output:
            raise RuntimeError(f"Invalid public implementation was not rejected by the universal proof:\n{output}")
    elif result.returncode:
        raise RuntimeError(f"Validation command failed: {command}\n{output}")
    return output


def public_mutations():
    variants = {
        'always_reject': 'None{}',
        'ignore_length': 'Buffer.sha256(words,0n)',
        'overwrite_first_word': 'Buffer.sha256(Array.set(U32,words,0,0),byte_length)',
    }
    for label, expression in variants.items():
        with tempfile.TemporaryDirectory(prefix='bend-sha256-negative-') as directory:
            root = Path(directory)
            for source in ROOT.glob('*.bend'):
                shutil.copyfile(source, root/source.name)
            p = root/'sha256.bend'
            source = p.read_text()
            anchor = 'Buffer.sha256(words,byte_length)'
            if source.count(anchor) != 1:
                raise RuntimeError('Public mutation anchor missing or ambiguous')
            p.write_text(source.replace(anchor, expression))
            checked(['bend', 'sha256.bend'], cwd=root)
            checked(['bend', 'CORRECTNESS.bend'], cwd=root, expect_failure=True)
            print(f'Universal proof rejected public array mutation: {label}', flush=True)


def main():
    if sys.flags.optimize:
        raise RuntimeError("Validation requires Python assertions enabled")
    version = checked(["bend", "--version"]).strip()
    if version != "bend 2.0.16":
        raise RuntimeError(f"Expected Bend 2.0.16, got {version}")
    audit()
    # This executes both CORRECTNESS and PROOF, plus all 182 cases on both backends.
    print(checked([sys.executable, "test_sha256.py", "--native", "--skip-mutations"]), end="", flush=True)
    public_mutations()
    print(checked([sys.executable, "tools/test_packed.py", "--native"]), end="", flush=True)
    print(checked([sys.executable, "tools/check_packed_mutations.py"]), end="", flush=True)
    print("RESEARCH VALIDATION PASSED: unchanged universal contract, checked proofs, 182 cases per API on JS/native, 3 rejected public array mutations, 142 packed cases on JS/native, 6 rejected packed/output mutations", flush=True)


if __name__ == "__main__":
    main()
