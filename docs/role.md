# Repository Roles – Files and Folders

This document describes the purpose of each important file and folder in this repository.

## Top-Level
- `README.md` – Quick start and high-level overview of the project.
- `docs/doc.md` – System architecture, data/control flows, and ASCII diagrams explaining end-to-end behavior.
- `docker-compose.yml` – Orchestrates containers (Postgres, FastAPI services for each problem, Redis, worker, gateway, monitoring tools) and wires environment variables.
- `requirements.txt` – Python dependencies for all services.
- `.env.example` – Example environment variables. Copy to `.env` and adjust values.
- `alembic.ini` – Alembic configuration. URL is set dynamically from `env.py`.
- `docker/Dockerfile.windows` / `docker/Dockerfile.macos` / `docker/Dockerfile.ubuntu` – Base images and build steps for running services on different host OS setups.

## Setup Scripts
- `scripts/setup-windows.ps1` – One-click Windows setup: build images, start services, wait for DB, run migrations, print endpoints.
- `scripts/setup-linux.sh` / `scripts/setup-macos.sh` – Shell equivalents for Linux/macOS.
- `scripts/clean-all.ps1` – Destructive cleanup (stops/removes containers, network, and volumes). Accepts `-Force` and `-RemoveImages`.
- `scripts/clean-all.sh` – Shell equivalent of the destructive cleanup script.
- `scripts/test-all.ps1` – Runs all endpoint tests for Problems 1–3 inside containers and prints a summary. Supports `-Coverage`.
- `scripts/test-all.sh` – Shell equivalent of the one-click tester.

## Database and Migrations
- `alembic/` – Database migrations shared by all problems.
  - `env.py` – Alembic environment configuration; pulls DB URL from environment so it works in containers.
  - `versions/` – Ordered migrations defining schema and data seeding.
    - `0001_initial.py` – Creates base tables (`users`, `projects`, `tasks`). Uses `VARCHAR` + `CHECK` constraints for task status to avoid ENUM conflicts.
    - `0002_seed_data.py` – Seeds initial users, projects, tasks and aligns sequences to `MAX(id)`.
    - `0003_problem2_models.py` – E-commerce models (`products`, `orders`, `order_items`) using `VARCHAR` + `CHECK` for order status.
    - `0004_fix_p2_schema_safe.py` – Safe adjustments for Problem 2 schema where needed.
    - `0005_problem3_page_views.py` – Adds `page_views` for Problem 3.
    - `0006_tasks_status_check_expand.py` – Expands `tasks.status` check constraint to accept multiple canonical forms.

- `seeds/`
  - `01_seed.sql` – Safe no-op to satisfy Postgres init-hook. Real seeding is handled by Alembic.

## Problems
- `problems/` – Contains independent sub-projects, each with its own `app/` (service code) and `tests/`.

### Problem 1 – Task Management API
- `problems/problem_1/app/` – FastAPI app implementing JWT auth, users, projects, tasks.
  - `api/` – FastAPI routers and endpoints (e.g., `api/v1/endpoints/projects.py`, `tasks.py`).
  - `crud/` – CRUD abstractions using SQLAlchemy (e.g., `crud/task.py`, `crud/project.py`).
  - `models/` – SQLAlchemy models (e.g., `models/task.py`, `models/project.py`, `models/user.py`).
  - `schemas/` – Pydantic schemas for request/response validation.
  - `db/` – DB session and base class definitions used by the app.
  - `core/` – App configuration and common utilities (settings, security, etc.).
  - `main.py` – FastAPI application entrypoint (imported by `uvicorn`).
- `problems/problem_1/tests/` – Pytest-based endpoint tests for Problem 1.

### Problem 2 – E-commerce API + Worker
- `problems/problem_2/app/` – FastAPI app for products and orders.
  - `api/` – Endpoints for products/orders.
  - `crud/`, `models/`, `schemas/` – Similar responsibilities as Problem 1, adapted to e-commerce domain.
  - `main.py` – FastAPI entrypoint exposed on port 8001.
- `problems/problem_2/worker.py` – Background worker consuming messages (via Redis) for stock reservation and order status transitions.
- `problems/problem_2/tests/` – Endpoint tests for placing orders, reserving stock, etc.

### Problem 3 – Performance-focused API
- `problems/problem_3/app/` – Minimal, optimized endpoints (e.g., `page_views`).
  - `main.py` – FastAPI entrypoint exposed on port 8002.
- `problems/problem_3/tests/` – Endpoint tests focused on performance use cases.

## Gateway and Monitoring
- `gateway/nginx.conf` – NGINX reverse proxy mapping `/p1`, `/p2`, `/p3` to the corresponding service containers; helpful for a single entrypoint.
- `monitoring/prometheus.yml` – Prometheus scrape configuration.
- `monitoring/grafana/` – Grafana provisioning (datasources and dashboards) for pre-configured observability.

## Utilities and Docs
- `tests/summarize_logs.py` – Summarizes per-problem test logs in CI-like output.
- `docs/SETUP.md` – Step-by-step OS-specific setup instructions.
- `docs/TESTING.md` – How to run tests, add new endpoint tests, and interpret logs.
- `evaluation/README.md` – Notes used for assessment/evaluation instructions.
- `examples/p1-examples.md` – Reference usage examples for Problem 1.

## Images and Services (from docker-compose)
- `db` – Postgres 14 with a persistent volume (`postgres_data`).
- `web` – Problem 1 FastAPI service (port 8000).
- `web_v2` – Problem 2 FastAPI service (port 8001).
- `web_v3` – Problem 3 FastAPI service (port 8002).
- `worker` – Problem 2 background worker consuming Redis messages.
- `redis` – Redis used by Problem 2 for queuing and caching.
- `pgadmin` – Optional DB admin UI at `http://localhost:5050`.
- `gateway` – NGINX reverse proxy at `http://localhost:8080`.
- `prometheus` – Metrics collection at `http://localhost:9090`.
- `grafana` – Metrics dashboards at `http://localhost:3000`.

## Typical Developer Flow
1. Start stack using OS-specific setup script (e.g., `setup-windows.ps1`).
2. Migrations auto-apply; initial data seeded via Alembic.
3. Run tests using one-click scripts (`scripts/test-all.ps1` / `.sh`).
4. Make changes in `problems/<problem_n>/app/` and re-run tests.
5. Use `scripts/clean-all` to reset if needed.
