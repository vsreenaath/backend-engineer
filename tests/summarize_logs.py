"""
Summarize endpoint test logs for Problems 1, 2, and 3.

Usage:
    python tests/summarize_logs.py

This script reads:
  - tests/logs/problem-1-tests.log
  - tests/logs/problem-2-tests.log
  - tests/logs/problem-3-tests.log
and prints per-problem pass/fail counts and a grand total.
"""
from __future__ import annotations

from pathlib import Path
from typing import Tuple

LOG_DIR = Path("tests/logs")
FILES = [
    ("Problem 1", LOG_DIR / "problem-1-tests.log"),
    ("Problem 2", LOG_DIR / "problem-2-tests.log"),
    ("Problem 3", LOG_DIR / "problem-3-tests.log"),
]


def summarize_file(path: Path) -> Tuple[int, int, int]:
    if not path.exists():
        return (0, 0, 0)
    lines = path.read_text(encoding="utf-8").splitlines()
    passed = sum(1 for l in lines if l.startswith("PASS"))
    failed = sum(1 for l in lines if l.startswith("FAIL"))
    total = len(lines)
    return (passed, failed, total)


def main() -> None:
    grand_pass = grand_fail = grand_total = 0
    print("\n=== Test Logs Summary ===")
    for name, p in FILES:
        pcount, fcount, tcount = summarize_file(p)
        grand_pass += pcount
        grand_fail += fcount
        grand_total += tcount
        status = "OK" if fcount == 0 and tcount > 0 else ("NO LOG" if tcount == 0 else "HAS FAILURES")
        print(f"- {name:<10}  Passed={pcount:<3}  Failed={fcount:<3}  Total={tcount:<3}  [{status}]  -> {p}")
    print(f"\nGrand Total: Passed={grand_pass} Failed={grand_fail} Total={grand_total}")


if __name__ == "__main__":
    main()
