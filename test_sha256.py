#!/usr/bin/env python3
"""Check Bend proofs and compare JS/native execution with hashlib."""
import argparse
import ast
import hashlib
from pathlib import Path
import random
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent


def run(args, timeout=180):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"{args!r}\n{result.stdout}\n{result.stderr}")
    return result.stdout


def cases():
    standard = [
        (b"", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
        (b"abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
        (b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
         "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"),
        (b"abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmn"
         b"hijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu",
         "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1"),
    ]
    result = [(str(list(msg)), digest) for msg, digest in standard]
    rng = random.Random(256)
    # Every residue modulo 64, padding transitions, binary zero/high bytes.
    lengths = list(range(130)) + [191, 192, 193, 255, 256, 257, 511, 512, 513, 1024, 4096]
    messages = [bytes(rng.randrange(256) for _ in range(n)) for n in lengths]
    messages += [bytes(range(256)), b"\0" * 64, b"\xff" * 65]
    messages += [bytes(rng.randrange(256) for _ in range(rng.randrange(4097))) for _ in range(32)]
    result += [(str(list(msg)), hashlib.sha256(msg).hexdigest()) for msg in messages]
    # API deliberately consumes the low byte of each U32.
    result += [("[256, 511, 4294967295]", hashlib.sha256(bytes([0, 255, 255])).hexdigest())]
    result += [("repeat(Nat.mul(1000n, 1000n), Nil{})",
                "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")]
    return result


def verify(lines, expected, backend, width=64):
    actual = [s for s in lines.splitlines() if len(s) == width and all(c in "0123456789abcdef" for c in s)]
    if len(actual) != len(expected):
        raise RuntimeError(f"{backend}: expected {len(expected)} digests, got {len(actual)}: {lines[-500:]}")
    for i, (got, want) in enumerate(zip(actual, expected)):
        if got != want:
            raise RuntimeError(f"{backend} case {i}: {got} != {want}")
    print(f"{backend}: {len(expected)} SHA-256 cases passed")


def check_spec_independence():
    source = (ROOT / "fips.bend").read_text()
    imports = re.findall(r"^import (.+)$", source, re.MULTILINE)
    if imports != ["Base", "./state.bend as Types"]:
        raise RuntimeError(f"Unexpected specification imports: {imports}")
    refs = set(re.findall(r"Types\.([A-Za-z_][A-Za-z_0-9]*)", source))
    if refs != {"State", "H"}:
        raise RuntimeError(f"Unexpected shared specification symbols: {refs}")
    for path in ROOT.glob("*.bend"):
        code = "\n".join(line.split("#", 1)[0] for line in path.read_text().splitlines())
        if re.search(r"@unsafe|\?[A-Za-z_]|import\s+[\"]", code):
            raise RuntimeError(f"Unsafe code, holes or foreign imports: {path}")
    print("Specification independence: only Base and the neutral state datatype imported")


def check_legacy_mutations():
    # These run the UNIVERSAL proof gate, which contains no concrete test vectors.
    mutations = [
        ("round", "core.bend", "(t1 + t2 : U32)", "(t1 + t2 + 1 : U32)", "step_correct"),
        ("constant", "sha256.bend", "1116352408", "1116352409", "constants_correct"),
        ("padding marker", "core.bend", "128 <> List.append", "129 <> List.append", "pad_correct"),
        ("padding zeros", "core.bend", "Nat.sub(119n,", "Nat.sub(118n,", "pad_correct"),
        ("byte count", "core.bend", "byte_count(t, 1n+acc)", "byte_count(t, 2n+acc)", "count_acc"),
        ("length encoding", "core.bend", "Nat.mod(n, 32n)), 3n)", "Nat.mod(n, 32n)), 4n)", "length_correct"),
        ("byte order", "core.bend", "U32.shln((a .&. 255 : U32), 24n)", "U32.shln((a .&. 255 : U32), 16n)", "words_acc"),
        ("schedule index", "core.bend", "get(history, 6n)", "get(history, 7n)", "next_correct"),
        ("schedule sigma", "core.bend", "rotr(x, 17n)", "rotr(x, 16n)", "next_correct"),
        ("round sigma", "core.bend", "rotr(x, 2n)", "rotr(x, 1n)", "step_correct"),
        ("initial state", "core.bend", "1779033703", "1779033704", "hash_correct"),
        ("digest order", "core.bend", "[a, b, c, d, e, f, g, h]", "[b, a, c, d, e, f, g, h]", "digest_correct"),
        ("digest byte order", "sha256.bend", "U32.shrn(w, 24n)", "U32.shrn(w, 16n)", "digest_bytes_correct"),
        ("digest byte mask", "sha256.bend", "U32.and(w, 255) <> digest_bytes", "U32.and(w, 127) <> digest_bytes", "digest_bytes_correct"),
        ("digest byte omitted", "sha256.bend", "U32.and(w, 255) <> digest_bytes(tail)", "digest_bytes(tail)", "digest_bytes_correct"),
    ]
    for label, filename, old, new, location in mutations:
        with tempfile.TemporaryDirectory(prefix="bend-sha256-mutation-") as tmp:
            directory = Path(tmp)
            for file in ROOT.glob("*.bend"):
                shutil.copy(file, directory / file.name)
            target = directory / filename
            original = target.read_text()
            if original.count(old) != 1:
                raise RuntimeError(f"Legacy mutation anchor unavailable: {filename}: {old!r}; use the default structural mutation suite")
            target.write_text(original.replace(old, new, 1))
            result = subprocess.run(["bend", str(directory / "CORRECTNESS.bend")],
                                    text=True, capture_output=True, timeout=60)
            output = result.stdout + result.stderr
            if result.returncode == 0 or location not in output or "All terms check." in output:
                raise RuntimeError(f"Legacy mutation {label} was not rejected at {location}: {output[-2000:]}")
    print(f"Universal proof mutation checks: {len(mutations)} algorithm defects rejected without test vectors")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--native", action="store_true", help="Also build and test the native C backend")
    mutations = parser.add_mutually_exclusive_group()
    mutations.add_argument("--skip-mutations", action="store_true",
                           help="Skip mutations when an outer validation gate runs them")
    mutations.add_argument("--legacy-mutations", action="store_true",
                           help="Run historical text mutations instead; requires their original source anchors")
    args = parser.parse_args()
    check_spec_independence()
    universal = run(["bend", "CORRECTNESS.bend"])
    if "All terms check." not in universal or "unsafe" in universal.lower():
        raise RuntimeError(f"Universal proof did not check cleanly: {universal}")
    print("Universal correctness theorem: All terms check.")
    proof = run(["bend", "PROOF.bend"])
    if "All terms check." not in proof or "unsafe" in proof.lower():
        raise RuntimeError(f"Concrete proofs did not check cleanly: {proof}")
    print("Bend proofs: All terms check.")
    if args.legacy_mutations:
        check_legacy_mutations()
    elif not args.skip_mutations:
        from research_validate import public_mutations
        public_mutations()
    vectors = cases()
    source = "import Base\nimport ../legacy_model.bend as SHA\n\n"
    source += "def repeat(n: Nat, acc: List<&2, U32>) -> List<&2, U32>:\n"
    source += "  match n:\n    case 0n:\n      acc\n    case 1n+p:\n      repeat(p, 97 <> acc)\n\n"
    expressions = []
    for i, (data, _) in enumerate(vectors):
        if data.startswith("["):
            values = ast.literal_eval(data)
            chunks = []
            for j in range(0, len(values), 64):
                name = f"chunk_{i}_{j}"
                source += f"def {name}() -> List<&2, U32>:\n  {values[j:j+64]}\n\n"
                chunks.append(name + "()")
            expressions.append("List.concat(&2, U32, [" + ", ".join(chunks) + "])")
        else:
            expressions.append(data)
    source += "def main() -> IO(Unit):\n  do IO<Unit>:\n"
    for data in expressions:
        source += f"    IO.print(SHA.hex(SHA.sha256({data})))\n"
        source += f"    IO.print(SHA.hex(SHA.sha256_bytes({data})))\n"
    with tempfile.TemporaryDirectory(prefix=".test-", dir=ROOT) as tmp:
        driver = Path(tmp) / "vectors.bend"
        driver.write_text(source)
        expected = [digest for _, digest in vectors]
        byte_expected = ["".join(f"{b:08x}" for b in bytes.fromhex(d)) for d in expected]
        output = run(["bend", str(driver)], timeout=300)
        verify(output, expected, "JS words")
        verify(output, byte_expected, "JS bytes (32 octets, each 0..255)", 256)
        if args.native:
            binary = Path(tmp) / "vectors"
            run(["bend", str(driver), "-o", str(binary)], timeout=300)
            output = run([str(binary)], timeout=300)
            verify(output, expected, "Native words")
            verify(output, byte_expected, "Native bytes (32 octets, each 0..255)", 256)


if __name__ == "__main__":
    main()
