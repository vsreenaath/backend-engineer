# Evaluation Guide

This folder contains guidance and helper commands to evaluate the repository.

## Goals

- Functional correctness of Problems 1, 2, 3
- Code quality, structure, and documentation
- Basic monitoring/metrics via Prometheus + Grafana
- API gateway (Nginx) routing to each service
- Endpoint tests and basic performance test (P3)

## How to run the stack

1) Start Docker Desktop
2) From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File ./setup-windows.ps1
```

This builds all services and applies migrations.

Optional extras (already added to compose):

- Gateway: http://localhost:8080
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)

## Run endpoint tests with coverage

Run from inside the `web` container to ensure dependencies are available:

```powershell
# Problem 1 tests + coverage
docker compose exec -e P1_BASE_URL=http://localhost:8000 -e POSTGRES_HOST=db web pytest -q problems/problem_1/tests/test_endpoints.py --cov=problems/problem_1/app -s

# Problem 2 tests (auth via P1) + coverage
docker compose exec -e P1_BASE_URL=http://web:8000 -e P2_BASE_URL=http://web_v2:8001 -e POSTGRES_HOST=db web pytest -q problems/problem_2/tests/test_endpoints.py --cov=problems/problem_2/app -s

# Problem 3 tests + coverage
docker compose exec -e P3_API_BASE_URL=http://web_v3:8002/api/p3 web pytest -q problems/problem_3/tests/test_endpoints.py --cov=problems/problem_3/app -s

# Summarize PASS/FAIL from log files
docker compose exec web python tests/summarize_logs.py
```

> Note: Log files are written inside the `web` container under `tests/logs/*.log`. Use `docker compose cp` to copy them out if required.

## Manual checks

- Problem 1 docs: http://localhost:8000/docs
- Problem 2 docs: http://localhost:8001/docs
- Problem 3 docs: http://localhost:8002/docs
- Gateway: http://localhost:8080 (try `/p1/docs`, `/p2/docs`, `/p3/docs`)
- Metrics endpoints: `/metrics` for each service
- Prometheus targets: http://localhost:9090/targets

## Performance (P3)

- Seed: `POST /api/p3/analytics/seed?rows=50000&unique_paths=200`
- Compare `top-paths/slow` vs `top-paths/optimized` and observe metrics.

## Known limitations

- CI/CD not executed here; a sample GitHub Actions workflow is provided under `.github/workflows/ci.yml`.
- Monitoring is basic; only default FastAPI metrics are exposed.
- No API gateway auth/rate-limiting configured.
