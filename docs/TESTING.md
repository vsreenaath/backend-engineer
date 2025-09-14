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
docker compose exec -e P3_API_BASE_URL=http://gateway/p3/api/p3 web \
  pytest -q problems/problem_3/tests/test_endpoints.py -s
```

Optional: coverage for P3 app only

```powershell
docker compose exec -e P3_API_BASE_URL=http://gateway/p3/api/p3 web \
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

### Running Tests in Docker

- Bring up services: `docker compose up -d --build db redis web web_v2 web_v3 gateway`
- Apply migrations: `docker compose exec web alembic upgrade head`
- Run all endpoint tests with summaries:
  - Windows: `powershell -ExecutionPolicy Bypass -File .\\scripts\\test-all.ps1`
  - Linux/macOS: `bash ./scripts/test-all.sh`
- Summarize logs (inside `web`): `docker compose exec web python tests/summarize_logs.py`

### Endpoint Testing Order (Updated)

These sequences cover signup, authentication, data creation, actions, and cleanup.

#### Problem 1 (http://localhost:8000)

```bash
BASE=http://localhost:8000
EMAIL=p1_$(date +%s)@example.com
PASS=Secret123!
curl -s -X POST "$BASE/api/v1/auth/signup" -H "Content-Type: application/json" -d '{"email":"'"$EMAIL"'","password":"'"$PASS"'","full_name":"P1 User"}'
TOKEN=$(curl -s -X POST "$BASE/api/v1/auth/login/access-token" -H "Content-Type: application/x-www-form-urlencoded" -d "username=$EMAIL&password=$PASS" | jq -r .access_token)
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/users/me"
PROJECT_ID=$(curl -s -X POST "$BASE/api/v1/projects/" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"title":"Demo Project","description":"Docs demo"}' | jq -r .id)
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/projects/"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/projects/$PROJECT_ID"
curl -s -X PUT "$BASE/api/v1/projects/$PROJECT_ID" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"title":"Demo Project Updated"}'
TASK_ID=$(curl -s -X POST "$BASE/api/v1/tasks/" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"title":"Demo Task","project_id":'"$PROJECT_ID"'}' | jq -r .id)
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/tasks/"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/tasks/$TASK_ID"
curl -s -X POST "$BASE/api/v1/tasks/$TASK_ID/status/IN_PROGRESS" -H "Authorization: Bearer $TOKEN"
curl -s -X DELETE "$BASE/api/v1/tasks/$TASK_ID" -H "Authorization: Bearer $TOKEN"
curl -s -X DELETE "$BASE/api/v1/projects/$PROJECT_ID" -H "Authorization: Bearer $TOKEN"
```

#### Problem 2 (http://localhost:8001)

```bash
BASE=http://localhost:8001
EMAIL=p2_$(date +%s)@example.com
PASS=Secret123!
curl -s -X POST "$BASE/api/v2/auth/signup" -H "Content-Type: application/json" -d '{"email":"'"$EMAIL"'","password":"'"$PASS"'","full_name":"P2 User"}'
TOKEN=$(curl -s -X POST "$BASE/api/v2/auth/login/access-token" -H "Content-Type: application/x-www-form-urlencoded" -d "username=$EMAIL&password=$PASS" | jq -r .access_token)
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/v2/users/me"
PRODUCT_ID=$(curl -s -X POST "$BASE/api/v2/products" -H "Content-Type: application/json" -d '{"sku":"SKU-1001","name":"Gadget","description":"A cool gadget","price_cents":9999,"stock":50}' | jq -r .id)
curl -s "$BASE/api/v2/products"
curl -s "$BASE/api/v2/products/$PRODUCT_ID"
curl -s -X PATCH "$BASE/api/v2/products/$PRODUCT_ID" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"name":"Gadget Pro","price_cents":10999}'
curl -s -X PATCH "$BASE/api/v2/products/$PRODUCT_ID/stock?delta=-2" -H "Authorization: Bearer $TOKEN"
ORDER_ID=$(curl -s -X POST "$BASE/api/v2/orders" -H "Content-Type: application/json" -d '{"items":[{"product_id":'"$PRODUCT_ID"',"quantity":1}]}' | jq -r .id)
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/v2/orders"
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/v2/orders/$ORDER_ID"
curl -s -X POST "$BASE/api/v2/orders/$ORDER_ID/pay" -H "Authorization: Bearer $TOKEN"
curl -s -X POST "$BASE/api/v2/orders/$ORDER_ID/cancel" -H "Authorization: Bearer $TOKEN"
curl -s -X DELETE "$BASE/api/v2/products/$PRODUCT_ID"
```

#### Problem 3 (http://localhost:8002/api/p3)

```bash
BASE=http://localhost:8002/api/p3
EMAIL=p3_$(date +%s)@example.com
PASS=Secret123!
curl -s -X POST "$BASE/auth/signup" -H "Content-Type: application/json" -d '{"email":"'"$EMAIL"'","password":"'"$PASS"'","full_name":"P3 User"}'
TOKEN=$(curl -s -X POST "$BASE/auth/login/access-token" -H "Content-Type: application/x-www-form-urlencoded" -d "username=$EMAIL&password=$PASS" | jq -r .access_token)
curl -s -H "Authorization: Bearer $TOKEN" "$BASE/auth/users/me"
curl -s -X POST "$BASE/analytics/seed?rows=1000&unique_paths=20"
curl -s "$BASE/analytics/top-paths/slow?limit=10"
curl -s "$BASE/analytics/top-paths/optimized?limit=10"
```

### Example curl Commands

- Use Linux/macOS examples above. For Windows PowerShell, translate JSON payloads with `ConvertTo-Json` and read tokens with `ConvertFrom-Json`.

### Adding New Test Cases

- Place new tests under the corresponding `problems/<problem_n>/tests/` folder.
- Reuse helpers and internal service URLs shown above.
- Keep tests independent by generating unique emails or resource identifiers (timestamps).
