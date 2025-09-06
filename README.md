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

### 1) Configure environment
Copy `.env.example` to `.env` (setup scripts do this automatically) and adjust values if needed.

### 2) Run the setup

Windows:
```powershell
powershell -ExecutionPolicy Bypass -File setup-windows.ps1
```

Linux:
```bash
bash ./setup-linux.sh
```

macOS:
```bash
bash ./setup-macos.sh
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
