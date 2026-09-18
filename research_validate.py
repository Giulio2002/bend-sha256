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
EDITABLE = ("core.bend", "sha256.bend", "conformance.bend", "list_proofs.bend", "padding_proof.bend")


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
        if re.search(r"@|\?|\b(?:IO|File|Socket|Listener|Chan)\.", source):
            raise RuntimeError(f"Unsafe annotations, holes, or effects are forbidden in {name}")
        imports = re.findall(r"^\s*import (.+)$", source, re.M)
        if imports != contract["imports"][name]:
            raise RuntimeError(f"Frozen import graph changed: {name}")
        if [law.strip() for law in laws(source)] != contract["laws"][name]:
            raise RuntimeError(f"Law declarations changed: {name}")
        names = re.findall(r"^\s*(?:def|law|type)\s+([^\s(:]+)", source, re.M)
        if any("." in name for name in names):
            raise RuntimeError(f"Overriding imported definitions is forbidden in {name}")
    print("Trust boundary: frozen specification, theorem, gate, imports and law statements intact", flush=True)


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
    # Rewrite the PUBLIC wrapper, independent of internal implementation text.
    variants = {
        "zero_digest": "[0, 0, 0, 0, 0, 0, 0, 0]",
        "prepended_byte": "sha256_original(0 <> bytes)",
        "reversed_digest": "List.reverse(&2, U32, sha256_original(bytes))",
    }
    for label, expression in variants.items():
        with tempfile.TemporaryDirectory(prefix="bend-sha256-negative-") as directory:
            root = Path(directory)
            for source in ROOT.glob("*.bend"):
                shutil.copyfile(source, root / source.name)
            target = root / "sha256.bend"
            original, count = re.subn(r"^def sha256\(", "def sha256_original(", target.read_text(), count=1, flags=re.M)
            if count != 1:
                raise RuntimeError("Cannot locate public sha256 definition for negative proof check")
            target.write_text(original + "\n\ndef sha256(bytes: List<&2, U32>) -> List<&2, U32>:\n  " + expression + "\n")
            # Ensure the mutant is executable/type-correct. Rejection must come
            # from the universal theorem, not a typo in our injected source.
            (root / "mutation_probe.bend").write_text(
                'import Base\nimport ./sha256.bend as SHA\n\ndef main() -> IO(Unit):\n  IO.print(SHA.hex(SHA.sha256([97, 98, 99])))\n')
            checked(["bend", "mutation_probe.bend"], cwd=root)
            checked(["bend", "CORRECTNESS.bend"], cwd=root, expect_failure=True)
            print(f"Universal proof rejected public mutation: {label}", flush=True)


def main():
    if sys.flags.optimize:
        raise RuntimeError("Validation requires Python assertions enabled")
    version = checked(["bend", "--version"]).strip()
    if version != "bend 2.0.5":
        raise RuntimeError(f"Expected Bend 2.0.5, got {version}")
    audit()
    # This executes both CORRECTNESS and PROOF, plus all 182 cases on both backends.
    print(checked([sys.executable, "test_sha256.py", "--native", "--skip-mutations"]), end="", flush=True)
    public_mutations()
    print("RESEARCH VALIDATION PASSED: unchanged universal contract, checked proofs, 182 cases per API on JS/native, 3 rejected public mutations", flush=True)


if __name__ == "__main__":
    main()
