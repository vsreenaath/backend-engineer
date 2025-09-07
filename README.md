# Task Management API (Problem 1)

A FastAPI-based task management backend with JWT auth, Postgres, and Alembic migrations. Docker Compose spins up the full stack, including pgAdmin.

## Features
- Users, Projects, Tasks with role checks
- JWT authentication (password hashing via bcrypt)
- SQLAlchemy 2.x models with Alembic migrations
- Dockerized for Windows/Linux/macOS
- pgAdmin for DB visibility

## Tech Stack
- FastAPI, Uvicorn
- SQLAlchemy 2.x, Alembic
- Pydantic v1
- Postgres, pgAdmin
- Docker Compose

## Getting Started

### Prerequisites
- Docker Desktop (Windows/macOS) or Docker Engine (Linux)
- PowerShell (Windows) or Bash (Linux/macOS)

### 1) Clone the project
```bash
git clone https://github.com/vsreenaath/backend-engineer.git
cd backend-engineer
```

### 2) Run the setup

Windows:
```powershell
powershell -ExecutionPolicy Bypass -File setup-windows.ps1
```

Linux:
```bash
chmod +x setup-linux.sh
./setup-linux.sh
```

macOS:
```bash
chmod +x setup-macos.sh
./setup-macos.sh
```

This will:
- Copy `.env` and generate a fresh `SECRET_KEY`
- Build and start containers
- Apply Alembic migrations (or stamp the DB to head if already initialized)

### 3) Access the services
- API: http://localhost:8000
- Docs: http://localhost:8000/docs
- pgAdmin: http://localhost:5050 (default: `admin@admin.com` / `admin`)

## Authentication
1) Create a user via the API (this hashes the password):
   - `POST /api/v1/users` as a superuser, or adjust the seed to hash passwords.
2) Obtain a token:
   - `POST /api/v1/auth/login/access-token` with form fields `username` (email) and `password`.
3) Use `Authorization: Bearer <access_token>` for protected endpoints.

Note: Seeded demo users in `alembic/versions/0002_seed_data.py` and `seeds/01_seed.sql` use plain text `hashed_password` for demonstration only; they are not usable for login unless you change to hashed values or create new users via API.

## Project Layout
- `problems/problem_1/app/main.py` – FastAPI app factory and routing
- `problems/problem_1/app/api/` – API routers and dependencies
- `problems/problem_1/app/core/` – Settings, DB base, security (JWT, hashing)
- `problems/problem_1/app/models/` – SQLAlchemy models
- `problems/problem_1/app/crud/` – DB CRUD operations
- `problems/problem_1/app/schemas/` – Pydantic schemas
- `alembic/` – Migrations (run inside the web container)
- `seeds/` – First-run SQL seeding for Postgres

## Docker Cheat Sheet
- Start: `docker compose up -d --build`
- Logs: `docker compose logs -f`
- Stop: `docker compose down`
- Exec shell in web: `docker compose exec web bash`
- Apply migrations: `docker compose exec web alembic upgrade head`

## Troubleshooting
- If migrations fail due to existing tables, the setup scripts will stamp head and continue.
- If port conflicts occur, change `8000` (FastAPI) or `5432` (Postgres) in `docker-compose.yml`.
- Ensure Docker Desktop is running on Windows/macOS.

## License
MIT (or your preferred license)

---

# Problem 2: Microservice Architecture (API v2)

Design a microservice-style extension for an e-commerce system. This repo hosts a single FastAPI app acting as the API gateway while Problem 2 modules are isolated by domain and use Redis as a lightweight message queue. A background worker processes asynchronous events.

## Features (v2)
- User service: Reuses authentication and profiles from Problem 1.
- Product service: Catalog and inventory with stock adjustments.
- Order service: Create orders and items, reserve stock asynchronously, pay/cancel flows.
- Inter-service communication: Redis-backed queue with a Python worker to process events.
- Data consistency: Stock reservations occur atomically in the worker using row locks; compensation restores stock on cancel.

## Services in Compose
- `web`: FastAPI app (exposes `/api/v2/...` in addition to `/api/v1/...`).
- `db`: Postgres.
- `redis`: Redis for queueing.
- `worker`: Python process that consumes events from Redis and updates DB (stock reservations and compensation).

## Environment
- `REDIS_URL=redis://redis:6379/0` (added to `.env.example`).

## Endpoints (v2)
All responses are JSON. Protected endpoints require `Authorization: Bearer <token>`.

- Auth (wraps P1 logic)
  - `POST /api/v2/auth/login/access-token` → `{ access_token, token_type }`
  - `GET /api/v2/users/me` → current user

- Products
  - `POST /api/v2/products` (auth required)
  - `GET /api/v2/products`
  - `GET /api/v2/products/{id}`
  - `PATCH /api/v2/products/{id}` (auth required)
  - `DELETE /api/v2/products/{id}` (auth required)
  - `PATCH /api/v2/products/{id}/stock?delta=+N|-N` (auth required)

- Orders
  - `POST /api/v2/orders` (auth required) → Creates order with items, status `PENDING`, publishes `reserve_stock` event.
  - `GET /api/v2/orders` (auth required)
  - `GET /api/v2/orders/{id}` (auth required)
  - `POST /api/v2/orders/{id}/pay` (auth required) → Allowed when `RESERVED`/`CONFIRMED`.
  - `POST /api/v2/orders/{id}/cancel` (auth required) → Publishes compensation event; sets `CANCELLED` (if not finalized).

## Sample curl commands
Assuming `TOKEN` holds a valid bearer token.

```bash
# 1) Login (reuses P1 users and hashing)
curl -s -X POST http://localhost:8000/api/v2/auth/login/access-token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'username=admin@example.com&password=<your-password>'

# 2) Create a product
curl -s -X POST http://localhost:8000/api/v2/products \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"sku":"SKU-1001","name":"T-Shirt","price_cents":1999,"stock":10}'

# 3) List products
curl -s http://localhost:8000/api/v2/products | jq .

# 4) Create an order with 2 units of product 1
curl -s -X POST http://localhost:8000/api/v2/orders \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"items":[{"product_id":1,"quantity":2}]}'

# 5) Check order status (worker may take a moment to process)
curl -s http://localhost:8000/api/v2/orders/1 -H "Authorization: Bearer $TOKEN" | jq .

# 6) Pay order
curl -s -X POST http://localhost:8000/api/v2/orders/1/pay -H "Authorization: Bearer $TOKEN" | jq .

# 7) Cancel order (tests compensation path)
curl -s -X POST http://localhost:8000/api/v2/orders/1/cancel -H "Authorization: Bearer $TOKEN" | jq .
```

## Implementation Notes
- Models (P2): `problems/problem_2/app/models/` → `Product`, `Order`, `OrderItem`, `OrderStatus`.
- CRUD (P2): `problems/problem_2/app/crud/` → product and order helpers.
- Schemas (P2): `problems/problem_2/app/schemas/`.
- API (P2): `problems/problem_2/app/api/v2/endpoints/` → `products.py`, `orders.py`, `auth.py`.
- Messaging (P2): `problems/problem_2/app/core/messaging.py` uses Redis lists as a queue.
- Worker: `problems/problem_2/worker.py` consumes `queue:reserve_stock` and `queue:cancel_order`.
- Main app mounts v2 router in `problems/problem_1/app/main.py`.
- Alembic imports P2 models in `alembic/env.py`; migration `0003_problem2_models.py` adds P2 tables.

## Notes on Data Consistency
- Orders start `PENDING`; worker reserves stock atomically (row locks) and moves to `RESERVED` or `FAILED`.
- Cancel path compensates by incrementing stock when appropriate.
- Payment endpoint validates allowed transitions.
