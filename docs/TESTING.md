# Testing Guide

This guide explains how to test each problem (P1, P2, P3) independently, using the provided endpoint tests and optional coverage reports.

We recommend running tests from inside the `web` container so all dependencies are available.

Quick start (one-click):

- Windows: `powershell -ExecutionPolicy Bypass -File .\\scripts\\test-all.ps1`
- Linux/macOS: `bash ./scripts/test-all.sh`

## Prerequisites

- Stack is up and migrations applied (see `docs/SETUP.md`).
- `docker compose ps` shows `web`, `web_v2`, `web_v3`, `db`, and `redis` running.

## Conventions

- Log files are written under `tests/logs/`:
  - `tests/logs/problem-1-tests.log`
  - `tests/logs/problem-2-tests.log`
  - `tests/logs/problem-3-tests.log`
- You can summarize the logs via `python tests/summarize_logs.py` inside the `web` container.

## Problem 1: RESTful API Development (port 8000)

- Base URL: `http://localhost:8000`
- Docs: `http://localhost:8000/docs`

Run the endpoint tests:

```powershell
# Windows PowerShell or any shell
# From repo root

docker compose exec -e P1_BASE_URL=http://web:8000 -e POSTGRES_HOST=db web \
  pytest -q problems/problem_1/tests/test_endpoints.py -s
```

Optional: coverage for P1 app only

```powershell
docker compose exec -e P1_BASE_URL=http://web:8000 -e POSTGRES_HOST=db web \
  pytest -q problems/problem_1/tests/test_endpoints.py --cov=problems/problem_1/app -s
```

## Problem 2: Microservice Architecture (port 8001)

- Base URL: `http://localhost:8001`
- Docs: `http://localhost:8001/docs`
- Requires Problem 1 authentication; tests will log in via P1.

Run the endpoint tests:

```powershell
# P1 and P2 internal URLs are used from within the containers

docker compose exec -e P1_BASE_URL=http://web:8000 -e P2_BASE_URL=http://web_v2:8001 -e POSTGRES_HOST=db web \
  pytest -q problems/problem_2/tests/test_endpoints.py -s
```

Optional: coverage for P2 app only

```powershell
docker compose exec -e P1_BASE_URL=http://web:8000 -e P2_BASE_URL=http://web_v2:8001 -e POSTGRES_HOST=db web \
  pytest -q problems/problem_2/tests/test_endpoints.py --cov=problems/problem_2/app -s
```

## Problem 3: Performance Optimization (port 8002)

- Base URL: `http://localhost:8002/api/p3`
- Docs: `http://localhost:8002/docs`

Run the endpoint tests:

```powershell
docker compose exec -e P3_API_BASE_URL=http://web_v3:8002/api/p3 web \
  pytest -q problems/problem_3/tests/test_endpoints.py -s
```

Optional: coverage for P3 app only

```powershell
docker compose exec -e P3_API_BASE_URL=http://web_v3:8002/api/p3 web \
  pytest -q problems/problem_3/tests/test_endpoints.py --cov=problems/problem_3/app -s
```

Optional: run P3 performance benchmarks:

```powershell
docker compose exec web \
  pytest -q problems/problem_3/app/tests/test_performance.py -s
```

## Summarize logs

After running tests, summarize PASS/FAIL counts across problems:

```powershell
docker compose exec web python tests/summarize_logs.py
```

## Add new endpoint tests

When you add new endpoints to any problem, create a new test file or extend an existing one under that problem's `tests/` directory. Tests are standard `pytest` tests and can use `httpx` for calling endpoints.

Example (Problem 1):

```python
from __future__ import annotations
import httpx
import os

BASE_URL = os.getenv("P1_BASE_URL", "http://localhost:8000")

def test_new_endpoint():
    with httpx.Client(base_url=BASE_URL, timeout=30) as client:
        r = client.get("/api/v1/your-new-endpoint")
        assert r.status_code == 200
        data = r.json()
        assert "expected_key" in data
```

Guidelines:

- Place tests under:
  - Problem 1: `problems/problem_1/tests/`
  - Problem 2: `problems/problem_2/tests/`
  - Problem 3: `problems/problem_3/tests/`
- Name files `test_*.py` so `pytest` discovers them automatically.
- Use the internal service URLs inside containers (see commands above) to avoid host networking issues.
- If your tests need authentication (e.g., P2 depends on P1), first log in using seeded credentials and pass the JWT in the `Authorization: Bearer <token>` header.

## Troubleshooting

- Ensure `db` is healthy before starting services: `docker compose ps`
- Rebuild a service after code changes: `docker compose up -d --build <service>`
- Common services:
  - `web`     -> Problem 1
  - `web_v2`  -> Problem 2
  - `web_v3`  -> Problem 3
  - `worker`  -> Problem 2 background worker
- Tail logs: `docker compose logs -f <service>`
- Apply migrations: `docker compose exec web alembic upgrade head`
