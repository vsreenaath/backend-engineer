#!/usr/bin/env bash
set -euo pipefail

# Run endpoint tests for Problems 1, 2, 3 from within containers
# and summarize logs. Optional coverage per-problem with -c/--coverage.

usage() {
  cat <<'USAGE'
Usage: scripts/test-all.sh [-c|--coverage]

Runs endpoint tests for Problems 1, 2, and 3 using docker compose exec,
then summarizes logs via tests/summarize_logs.py.

Options:
  -c, --coverage   Enable pytest coverage per problem
USAGE
}

COVERAGE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--coverage) COVERAGE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

set +e
ALL_OK=1

if [[ $COVERAGE -eq 1 ]]; then
  COV1=" --cov=problems/problem_1/app"
  COV2=" --cov=problems/problem_2/app"
  COV3=" --cov=problems/problem_3/app"
else
  COV1=""; COV2=""; COV3=""
fi

echo "[INFO] Running Problem 1 tests..."
docker compose exec -e P1_BASE_URL=http://web:8000 -e POSTGRES_HOST=db web \
  pytest -q problems/problem_1/tests/test_endpoints.py -s${COV1}
P1=$?
if [[ $P1 -ne 0 ]]; then echo "[FAIL] Problem 1 tests failed"; ALL_OK=0; else echo "[OK] Problem 1 passed"; fi

echo "[INFO] Running Problem 2 tests..."
docker compose exec -e P1_BASE_URL=http://web:8000 -e P2_BASE_URL=http://web_v2:8001 -e POSTGRES_HOST=db web \
  pytest -q problems/problem_2/tests/test_endpoints.py -s${COV2}
P2=$?
if [[ $P2 -ne 0 ]]; then echo "[FAIL] Problem 2 tests failed"; ALL_OK=0; else echo "[OK] Problem 2 passed"; fi

echo "[INFO] Running Problem 3 tests..."
docker compose exec -e P3_API_BASE_URL=http://web_v3:8002/api/p3 web \
  pytest -q problems/problem_3/tests/test_endpoints.py -s${COV3}
P3=$?
if [[ $P3 -ne 0 ]]; then echo "[FAIL] Problem 3 tests failed"; ALL_OK=0; else echo "[OK] Problem 3 passed"; fi

echo "[INFO] Summarizing logs..."
docker compose exec web python tests/summarize_logs.py || true

if [[ $ALL_OK -eq 1 ]]; then
  echo "[OK] All problem tests passed"
  exit 0
else
  echo "[FAIL] One or more problem tests failed"
  exit 1
fi
