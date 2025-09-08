"""
Problem 3 endpoint tests (Performance Optimization API p3).

Covers seed data, slow top-paths, optimized top-paths, and a simple perf check.
Writes detailed logs to tests/logs/problem-3-tests.log and prints a summary.

Run independently:
    pytest -q problems/problem_3/tests/test_endpoints.py -s
"""
from __future__ import annotations

import time
from pathlib import Path
from typing import List
import os

import httpx

LOG_DIR = Path("tests/logs")
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / "problem-3-tests.log"

BASE_URL = os.getenv("P3_API_BASE_URL", "http://localhost:8002/api/p3")


def log(msg: str) -> None:
    line = msg.strip()
    print(line)
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(line + "\n")


def test_seed_and_endpoints() -> None:
    LOG_FILE.unlink(missing_ok=True)
    client = httpx.Client(base_url=BASE_URL, timeout=60.0)

    # Seed
    params = {"rows": 20000, "unique_paths": 150}
    r = client.post("/analytics/seed", params=params)
    r.raise_for_status(); log("PASS seed: inserted rows")

    # Slow
    r = client.get("/analytics/top-paths/slow", params={"limit": 10})
    r.raise_for_status(); slow = r.json(); assert isinstance(slow, list); log("PASS top-paths: slow")

    # Optimized
    r = client.get("/analytics/top-paths/optimized", params={"limit": 10})
    r.raise_for_status(); opt = r.json(); assert isinstance(opt, list); log("PASS top-paths: optimized")

    # Basic perf comparison
    t0 = time.perf_counter(); r = client.get("/analytics/top-paths/slow", params={"limit": 10}); r.raise_for_status(); slow_t = time.perf_counter() - t0
    t1 = time.perf_counter(); r = client.get("/analytics/top-paths/optimized", params={"limit": 10}); r.raise_for_status(); opt_t = time.perf_counter() - t1
    # We only assert that optimized isn't egregiously slower
    assert opt_t < slow_t, f"optimized {opt_t:.4f}s vs slow {slow_t:.4f}s"; log(f"PASS perf: optimized faster ({opt_t:.4f}s < {slow_t:.4f}s)")

    client.close()


def test_summary() -> None:
    """Parse the log file and print a brief summary to console."""
    if not LOG_FILE.exists():
        print("No log file found for Problem 3 tests.")
        return
    lines = LOG_FILE.read_text(encoding="utf-8").splitlines()
    passed = sum(1 for l in lines if l.startswith("PASS"))
    failed = sum(1 for l in lines if l.startswith("FAIL"))
    print(f"[P3 SUMMARY] Passed={passed} Failed={failed} Total={len(lines)}")
