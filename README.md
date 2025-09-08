# Backend Engineer Assessment

Quick links:

- See `docs/SETUP.md` for local setup instructions
- See `docs/TESTING.md` for how to run tests for Problems 1, 2, and 3
- See `docs/doc.md` for architecture and flow details
- See `docs/role.md` to know the use of each file and folder

This repository implements three problems as independent services running in Docker Compose:

- Problem 1 (Task Management) on port 8000
- Problem 2 (E-commerce v2) on port 8001
- Problem 3 (Performance Optimization) on port 8002

pgAdmin is available on port 5050.

## Prerequisites

- Docker Desktop (Windows/macOS) or Docker Engine (Linux)
- PowerShell (Windows) or Bash (Linux/macOS)

## Setup (common for all problems)

1) Clone the repository

```bash
git clone https://github.com/vsreenaath/backend-engineer.git
cd backend-engineer
```

2) Start Docker Desktop

3) Run the setup script (builds images, starts containers, applies migrations)

- Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1
```

- Linux

```bash
chmod +x ./scripts/setup-linux.sh
./scripts/setup-linux.sh
```

- macOS

```bash
chmod +x ./scripts/setup-macos.sh
./scripts/setup-macos.sh
```

4) Verify services

- Problem 1: http://localhost:8000 and http://localhost:8000/docs
- Problem 2: http://localhost:8001 and http://localhost:8001/docs
- Problem 3: http://localhost:8002 and http://localhost:8002/docs
- pgAdmin: http://localhost:5050 (default: admin@admin.com / admin)

## Services in Docker Compose

- `web` (Problem 1)
- `web_v2` (Problem 2)
- `web_v3` (Problem 3)
- `db` (Postgres)
- `redis` (Redis)
- `worker` (Background worker for Problem 2)
- `pgadmin`

---

# Problem 1: RESTful API Development (Task Management)

FastAPI app exposing `/api/v1` with JWT auth, projects and tasks.

### Authentication

- Login: `POST /api/v1/auth/login/access-token`

```bash
curl -s -X POST http://localhost:8000/api/v1/auth/login/access-token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'username=admin@example.com&password=<your-password>' | jq .
```

Use `Authorization: Bearer <access_token>` for protected endpoints.

### Users (admin only for user management)

- `GET /api/v1/users/me`
- `GET /api/v1/users`
- `POST /api/v1/users`
- `PUT /api/v1/users/{user_id}`
- `DELETE /api/v1/users/{user_id}`

### Projects

- `POST /api/v1/projects`
- `GET /api/v1/projects`
- `GET /api/v1/projects/{id}`
- `PUT /api/v1/projects/{id}`
- `DELETE /api/v1/projects/{id}`

### Tasks

- `POST /api/v1/tasks`
- `GET /api/v1/tasks`
- `GET /api/v1/tasks/{id}`
- `PUT /api/v1/tasks/{id}`
- `DELETE /api/v1/tasks/{id}`
- `POST /api/v1/tasks/{id}/status/{status}`
- `POST /api/v1/tasks/{id}/assign/{user_id}`

---

# Problem 2: Microservice Architecture (E-commerce v2)

FastAPI app exposing `/api/v2` and a background `worker` processing reserve/cancel events via Redis.

### Authentication

You can log in via Problem 1 or Problem 2:

- `POST /api/v1/auth/login/access-token` (P1)
- `POST /api/v2/auth/login/access-token` (P2)

### Products

- `POST /api/v2/products`
- `GET /api/v2/products`
- `GET /api/v2/products/{id}`
- `PATCH /api/v2/products/{id}`
- `DELETE /api/v2/products/{id}`
- `PATCH /api/v2/products/{id}/stock?delta=+N|-N`

### Orders

- `POST /api/v2/orders`
- `GET /api/v2/orders`
- `GET /api/v2/orders/{id}`
- `POST /api/v2/orders/{id}/pay`
- `POST /api/v2/orders/{id}/cancel`

---

# Problem 3: Performance Optimization (API p3)

Independent FastAPI app (port 8002) with slow vs optimized analytics endpoints.

### Endpoints (prefix `/api/p3`)

- `POST /api/p3/analytics/seed?rows=50000&unique_paths=200`
- `GET /api/p3/analytics/top-paths/slow?limit=10`
- `GET /api/p3/analytics/top-paths/optimized?limit=10`

### Quick start

```bash
curl -s -X POST "http://localhost:8002/api/p3/analytics/seed?rows=20000&unique_paths=150" | jq .
curl -s "http://localhost:8002/api/p3/analytics/top-paths/slow?limit=10" | jq .
curl -s "http://localhost:8002/api/p3/analytics/top-paths/optimized?limit=10" | jq .
```

---

# Testing & Logs

We provide independent endpoint tests for each problem that print results to console and write detailed logs to `tests/logs/`:

- Problem 1: `problems/problem_1/tests/test_endpoints.py`
- Problem 2: `problems/problem_2/tests/test_endpoints.py`
- Problem 3: `problems/problem_3/tests/test_endpoints.py`

Run individually:

```bash
pytest -q problems/problem_1/tests/test_endpoints.py -s
pytest -q problems/problem_2/tests/test_endpoints.py -s
pytest -q problems/problem_3/tests/test_endpoints.py -s
```

Log files are written to:

- `tests/logs/problem-1-tests.log`
- `tests/logs/problem-2-tests.log`
- `tests/logs/problem-3-tests.log`

Summarize results after running tests:

```bash
python tests/summarize_logs.py
```

---


# Useful Commands

- Start: `docker compose up -d --build`
- Logs: `docker compose logs -f`
- Stop: `docker compose down`
- Exec into web: `docker compose exec web bash`
- Apply migrations: `docker compose exec web alembic upgrade head`

---
