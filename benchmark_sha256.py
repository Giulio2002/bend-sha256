#!/usr/bin/env python3
"""Compare native Bend with the fastest measured Python SHA-256 backend.

Compilation, input generation/loading/chunking, process startup, hex formatting,
and output are outside the timed region. Both sides retain every 32-byte digest.
Bend's public list API allocation and Python's digest allocation remain timed.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import random
import shutil
import ssl
import statistics
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent
SIZES = (64, 1024, 16384, 65536)
CORPUS_BYTES = 1024 * 1024
SAMPLES = 5
SEED = 2562026


def run(command, *, env=None, timeout=300):
    result = subprocess.run(command, cwd=ROOT, env=env, text=True,
                            capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"Command failed: {command}\n{result.stdout}\n{result.stderr}")
    return result.stdout


def python_backends():
    from Crypto.Hash import SHA256
    from cryptography.hazmat.primitives import hashes

    def cryptography_sha256(data):
        context = hashes.Hash(hashes.SHA256())
        context.update(data)
        return context.finalize()

    return {
        "hashlib": lambda data: hashlib.sha256(data).digest(),
        "pycryptodome": lambda data: SHA256.new(data).digest(),
        "cryptography": cryptography_sha256,
    }


def parse_native(output, expected):
    lines = output.splitlines()
    if not lines or not lines[0].startswith("BENCH_MS="):
        raise RuntimeError("Native benchmark did not emit its timing record")
    elapsed = int(lines[0].removeprefix("BENCH_MS="))
    if elapsed < 20:
        raise RuntimeError("Native batch below 20 ms; millisecond timer cannot resolve this workload reliably")
    # The accumulator returns messages in reverse order. Check EVERY digest.
    wanted = [digest.hex() for digest in reversed(expected)]
    if lines[1:] != wanted:
        raise RuntimeError("Native digest count/order/content mismatch; no score is valid")
    return elapsed


def measure_python(function, messages, expected):
    # Calibration repeats the entire batch to measure >=50 ms with a high-resolution clock.
    loops = 1
    while True:
        start = time.perf_counter_ns()
        for _ in range(loops):
            result = [function(message) for message in messages]
        elapsed = (time.perf_counter_ns() - start) / 1e6
        if result != expected:
            raise RuntimeError("Python reference digest mismatch")
        if elapsed >= 50:
            break
        loops *= 2
    samples = []
    for _ in range(SAMPLES):
        start = time.perf_counter_ns()
        for _ in range(loops):
            result = [function(message) for message in messages]
        elapsed = (time.perf_counter_ns() - start) / 1e6 / loops
        if result != expected:
            raise RuntimeError("Python reference digest mismatch")
        samples.append(elapsed)
    return {"median_ms": statistics.median(samples), "samples_ms": samples,
            "batches_per_sample": loops}


def gpu_hardware():
    if platform.system() == "Darwin":
        displays = json.loads(run(["system_profiler", "SPDisplaysDataType", "-json"]))
        devices = [{"name": item.get("sppci_model", item.get("_name")),
                    "cores": item.get("sppci_cores"),
                    "metal": item.get("spdisplays_mtlgpufamilysupport")}
                   for item in displays.get("SPDisplaysDataType", [])]
        return {"available": any(d["metal"] for d in devices), "backend": "Metal", "devices": devices}
    cuda = Path(os.environ.get("CUDA_HOME", "/usr/local/cuda"))
    if shutil.which("nvidia-smi") and (cuda / "include/nvrtc.h").exists():
        name = run(["nvidia-smi", "--query-gpu=name,driver_version", "--format=csv,noheader"]).strip()
        return {"available": True, "backend": "CUDA", "devices": [{"name": name}]}
    return {"available": False, "backend": None, "devices": [],
            "reason": "No supported Metal device or NVIDIA CUDA toolkit detected"}


def native_samples(binary, native_env, expected, *options):
    command = [str(binary), *options]
    parse_native(run(command, env=native_env), expected)
    samples = [parse_native(run(command, env=native_env), expected) for _ in range(SAMPLES)]
    return {"median_ms": statistics.median(samples), "samples_ms": samples}


def benchmark(gpu_mode="off"):
    backends = python_backends()  # Require all three, never silently skip a missing competitor.
    env = {**os.environ, "BEND_NO_TELEMETRY": "1"}
    version = run(["bend", "--version"], env=env).strip()
    if version != "bend 2.0.5":
        raise RuntimeError(f"Expected pinned Bend 2.0.5, got {version!r}")
    hardware = gpu_hardware() if gpu_mode != "off" else {"available": False, "reason": "Disabled explicitly"}
    if gpu_mode == "required" and not hardware["available"]:
        raise RuntimeError("GPU required but unavailable: " + hardware.get("reason", "No Metal device"))
    report = {
        "schema": 2, "scored_modes": ["sequential_cpu", "parallel_cpu"], "metric": "best_bend_total_ms", "samples_per_workload": SAMPLES,
        "seed": SEED, "corpus_bytes_per_workload": CORPUS_BYTES,
        "environment": {"python": sys.version, "platform": platform.platform(),
                        "machine": platform.machine(), "bend": version,
                        "openssl_hashlib": ssl.OPENSSL_VERSION,
                        "hashlib_constructor": repr(hashlib.sha256),
                        "pycryptodome": importlib.metadata.version("pycryptodome"),
                        "cryptography": importlib.metadata.version("cryptography")},
        "timing": "Hash batch and retain digests; exclude build, loading, chunking, startup, formatting and output",
        "gpu": {**hardware, "status": "pending" if hardware["available"] else "skipped",
                "forced_mode": "--gpu on", "implementation": "The same proved SHA.sha256, parallel message tree",
                "timing": "Host-observed batch completion, including GPU dispatch and synchronization"},
        "workloads": [],
    }
    with tempfile.TemporaryDirectory(prefix="bend-sha256-bench-") as directory:
        temp = Path(directory)
        module_cache = temp / "clang-module-cache"
        module_cache.mkdir()
        env["CLANG_MODULE_CACHE_PATH"] = str(module_cache)
        binary = temp / "native"
        print("Building native Bend benchmark (outside timing)", file=sys.stderr, flush=True)
        run(["bend", "benchmarks/driver.bend", "-o", str(binary)], env=env)
        gpu_binary = temp / "gpu-native"
        print("Building native Bend parallel benchmark (outside timing)", file=sys.stderr, flush=True)
        run(["bend", "benchmarks/gpu_driver.bend", "-o", str(gpu_binary)], env=env)
        corpus = random.Random(SEED).randbytes(CORPUS_BYTES)
        data_file = temp / "corpus.bin"
        data_file.write_bytes(corpus)
        report["corpus_sha256"] = hashlib.sha256(corpus).hexdigest()
        for size in SIZES:
            messages = [corpus[offset:offset + size] for offset in range(0, len(corpus), size)]
            expected = [hashlib.sha256(message).digest() for message in messages]
            native_env = {**env, "SHA_BENCH_INPUT": str(data_file), "SHA_BENCH_SIZE": str(size)}
            native = native_samples(binary, native_env, expected)["samples_ms"]
            references = {name: measure_python(function, messages, expected)
                          for name, function in backends.items()}
            winner = min(references, key=lambda key: references[key]["median_ms"])
            bend_ms = statistics.median(native)
            python_ms = references[winner]["median_ms"]
            item = {"message_bytes": size, "messages": len(messages), "bend_ms": bend_ms,
                    "bend_samples_ms": native, "python": references,
                    "fastest_python": winner, "fastest_python_ms": python_ms,
                    "bend_over_python": bend_ms / python_ms,
                    "bend_mib_per_second": CORPUS_BYTES / 1048576 / (bend_ms / 1000)}
            parallel_env = {**native_env, "SHA_BENCH_DEPTH": str(len(messages).bit_length() - 1)}
            item["bend_parallel_cpu"] = native_samples(gpu_binary, parallel_env, expected, "--gpu", "off")
            print(f"{size:>6} B | Bend parallel CPU {item['bend_parallel_cpu']['median_ms']} ms",
                  file=sys.stderr, flush=True)
            if hardware["available"]:
                item["bend_gpu"] = native_samples(gpu_binary, parallel_env, expected, "--gpu", "on")
                print(f"{size:>6} B | Bend parallel CPU {item['bend_parallel_cpu']['median_ms']} ms "
                      f"| Bend {hardware['backend']} GPU {item['bend_gpu']['median_ms']} ms",
                      file=sys.stderr, flush=True)
            report["workloads"].append(item)
            print(f"{size:>6} B | Bend {bend_ms:8.3f} ms | {winner:12} {python_ms:8.3f} ms "
                  f"| Bend/Python time ratio {bend_ms / python_ms:.2f}x", file=sys.stderr, flush=True)
    totals = {name: sum(row["python"][name]["median_ms"] for row in report["workloads"])
              for name in backends}
    winner = min(totals, key=totals.get)
    report.update(bend_total_ms=sum(row["bend_ms"] for row in report["workloads"]),
                  python_totals_ms=totals, fastest_python=winner,
                  fastest_python_total_ms=totals[winner])
    report["bend_over_python"] = report["bend_total_ms"] / totals[winner]
    report["winner"] = "bend" if report["bend_total_ms"] < totals[winner] else winner
    if hardware["available"]:
        report["gpu"]["status"] = "measured"
        report["bend_gpu_total_ms"] = sum(row["bend_gpu"]["median_ms"] for row in report["workloads"])
    report["bend_parallel_cpu_total_ms"] = sum(row["bend_parallel_cpu"]["median_ms"] for row in report["workloads"])
    # Optional GPU diagnostics never contribute to the optimization score.
    bend_totals = {"sequential_cpu": report["bend_total_ms"],
                   "parallel_cpu": report["bend_parallel_cpu_total_ms"]}
    report["bend_mode_totals_ms"] = bend_totals
    report["best_bend_mode"] = min(bend_totals, key=bend_totals.get)
    report["best_bend_total_ms"] = bend_totals[report["best_bend_mode"]]
    report["best_bend_over_python"] = report["best_bend_total_ms"] / totals[winner]
    report["winner"] = "bend_" + report["best_bend_mode"] if report["best_bend_total_ms"] < totals[winner] else winner
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Also save the complete JSON report")
    parser.add_argument("--gpu", choices=("auto", "required", "off"), default="off",
                        help="Optional GPU diagnostic only; default off. Scoring always uses CPU modes only")
    args = parser.parse_args()
    report = benchmark(args.gpu)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    print(json.dumps(report, allow_nan=False))  # Autoresearch reads the final stdout line.


if __name__ == "__main__":
    main()
