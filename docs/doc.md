# Backend Engineer Assessment – Architecture and Flow

This document explains the repository architecture, service layout, control and data flows per problem, and how to develop and test effectively. ASCII flowcharts are included to aid understanding.


## Repository Overview

Top-level directories:

- `problems/`
  - `problem_1/` Task management API (FastAPI)
  - `problem_2/` E-commerce API + background worker (FastAPI + Redis worker)
  - `problem_3/` Performance-focused API (FastAPI)
- `alembic/` Database migrations (shared across services)
- `docs/` Setup and testing guides
- `monitoring/` Prometheus and Grafana config
- `gateway/` NGINX reverse proxy configuration
- `seeds/` First-run Postgres init hook (safe no-op)
- `scripts/` One-click test runners

Key files:

- `docker-compose.yml` – Orchestrates DB, APIs, worker, gateway, monitoring
- `requirements.txt` – Python deps
- `scripts/setup-*.sh` / `scripts/setup-windows.ps1` – OS-specific setup
- `scripts/test-all.sh` / `scripts/test-all.ps1` – One-click test runners


## Services and Ports

- `db` (Postgres 14) – 5432
- `web` (Problem 1) – 8000
- `web_v2` (Problem 2) – 8001
- `web_v3` (Problem 3) – 8002
- `gateway` (NGINX) – 8080; proxies to `/p1`, `/p2`, `/p3`
- `redis` – 6379
- `pgadmin` – 5050
- `prometheus` – 9090
- `grafana` – 3000

Environment variables are provided via `.env` and expanded by Compose (see `.env.example`).


## Database and Migrations

- Alembic manages schema across all problems: `alembic/versions/*.py`.
- First-run Postgres init hook loads `seeds/01_seed.sql`, which is intentionally a no-op (prevents init failures). All application seeding is handled in Alembic migrations, specifically `0002_seed_data.py`.
- We seed initial users, projects, tasks with explicit IDs and then align sequences to `MAX(id)` to avoid duplicate key issues on insert.
- To avoid cross-run ENUM conflicts, statuses in migrations are stored as `VARCHAR` with `CHECK` constraints instead of Postgres ENUM types.

Tables (high-level):

- Problem 1: `users`, `projects`, `tasks`
- Problem 2: `products`, `orders`, `order_items`
- Problem 3: `page_views` (see `0005_problem3_page_views`)


## Problem 1 – Task Management API

- Auth with JWT
- Entities: Users, Projects, Tasks
- Ownership/permissions enforced in endpoints and CRUD
- Task status stored as string, validated by DB CHECK constraint. App uses a Python enum for clarity in code.

### Control Flow – Login + Project + Task
```
Client
  |  POST /api/v1/auth/login/access-token (username, password)
  v
web (FastAPI)
  |  Validate credentials (DB), issue JWT
  v
Client (stores JWT)
  |  POST /api/v1/projects (Authorization: Bearer <token>)
  v
web (create_with_owner)
  |  INSERT INTO projects (owner_id=token.user_id)
  v
DB (projects)
  |  POST /api/v1/tasks (Authorization: Bearer <token>)
  v
web (permissions + create)
  |  INSERT INTO tasks (project_id, assignee_id, status='ToDo')
  v
DB (tasks)
```

### Data Flow (Read/Write)
```
[Client] -> HTTP (JSON) -> [web] -> SQLAlchemy -> [Postgres]
```


## Problem 2 – E-commerce + Worker

- API for managing products and orders
- Background worker processes order events, reserves stock, and handles compensation
- Communication via Redis (queue/messages)

### Control & Data Flow – Place Order
```
Client
  |  POST /api/v2/orders (web_v2)
  v
web_v2 (FastAPI)
  |  Validate order; enqueue reservation event -> [Redis]
  v
Redis (queue)
  |  Worker consumes message
  v
worker (problems/problem_2/worker.py)
  |  DB transaction: lock stock, reserve, update order status
  |  On failure: rollback + send compensation (cancel/reserve release)
  v
DB (products, orders, order_items)
```

### Data Flow (Read/Write)
```
[Client] -> [web_v2] -> [Redis] -> [worker] -> [Postgres]
```


## Problem 3 – Performance endpoints

- Optimized endpoints under `web_v3` (port 8002)
- Example table: `page_views` (analytics-like recording)

### Control Flow – Record Page View
```
Client
  |  POST /api/p3/page-views
  v
web_v3 (FastAPI)
  |  Minimal validation + batched/efficient insert
  v
DB (page_views)
```


## Monitoring and Gateway

- `gateway/nginx.conf` routes `/p1`, `/p2`, `/p3` to corresponding services and exposes `/metrics` where applicable.
- Prometheus scrapes metrics; Grafana dashboards read from Prometheus.


## Development and Testing

- Run stack (example on Windows):
  - `powershell -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1`
- One-click tests:
  - Windows: `powershell -ExecutionPolicy Bypass -File .\scripts\test-all.ps1`
  - Linux/macOS: `bash ./scripts/test-all.sh`
- Add new endpoint tests: see `docs/TESTING.md` for pytest + httpx examples and logging conventions.


## Troubleshooting Tips

- Postgres init errors due to SQL in `docker-entrypoint-initdb.d`:
  - We keep `seeds/01_seed.sql` as a no-op. App data is seeded by Alembic.
- Migrations stamped without schema creation:
  - `docker compose exec web alembic stamp base`
  - `docker compose exec web alembic upgrade head`
- Duplicate key after seed with explicit IDs:
  - Ensure sequences are aligned (handled by migration `0002_seed_data.py`).
- ENUM conflicts across reruns:
  - Schema uses `VARCHAR` + `CHECK` constraints for statuses to avoid ENUM re-creation issues.


## Quick Reference

- Problem 1 (Task Management) – http://localhost:8000 (docs at `/docs`)
- Problem 2 (E-commerce) – http://localhost:8001 (docs at `/docs`)
- Problem 3 (Performance) – http://localhost:8002 (docs at `/docs`)
- Through Gateway – http://localhost:8080 (`/p1`, `/p2`, `/p3`)
- PgAdmin – http://localhost:5050
- Prometheus – http://localhost:9090
- Grafana – http://localhost:3000

---
This document should give new contributors a clear, end-to-end picture of how the repo is structured, how services interact, and how data flows through the system.
