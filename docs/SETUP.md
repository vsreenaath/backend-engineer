# Local Setup Guide

This guide explains how to set up, run, and verify the Backend Engineer assessment locally.

***

### Prerequisites
- **Docker Desktop** (Windows/macOS) or **Docker Engine** (Linux) – version >= 20.10  
- **PowerShell** (Windows) or **Bash** (Linux/macOS)  
- **Git**

***

### Clone the Repository
```bash
git clone https://github.com/vsreenaath/backend-engineer.git
cd backend-engineer
```

***

### Start the Stack

You can use the provided setup scripts (recommended) or raw Docker Compose.

#### Option A: Setup Script (Recommended)

**Windows (PowerShell)**
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1
```

**Linux**
```bash
chmod +x ./scripts/setup-linux.sh
./scripts/setup-linux.sh
```

**macOS**
```bash
chmod +x ./scripts/setup-macos.sh
./scripts/setup-macos.sh
```

The setup scripts build Docker images, start containers, and apply database migrations automatically. Dockerfiles are now under `docker/` and the scripts will ensure `docker-compose.yml` points to the correct `docker/Dockerfile.*`.

#### Option B: Raw Docker Compose
```bash
# Build and start services
docker compose up -d --build

# Apply database migrations (inside the web service container)
docker compose exec web alembic upgrade head
```

***

### Step 2: Configure Environment
Copy the example environment file and adjust values as needed:

**Windows PowerShell**
```powershell
Copy-Item .env.example .env
```

**Linux/macOS**
```bash
cp .env.example .env
```

At minimum, ensure the following variables are set (defaults in `.env.example` work for local development):

- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`  
- `SECRET_KEY`, `ALGORITHM`, `ACCESS_TOKEN_EXPIRE_MINUTES`  
- `BACKEND_CORS_ORIGINS`  
- `REDIS_URL`  

***

### Verify Services
- Problem 1: [http://localhost:8000](http://localhost:8000) & [Docs](http://localhost:8000/docs)  
- Problem 2: [http://localhost:8001](http://localhost:8001) & [Docs](http://localhost:8001/docs)  
- Problem 3: [http://localhost:8002](http://localhost:8002) & [Docs](http://localhost:8002/docs)  
- pgAdmin: [http://localhost:5050](http://localhost:5050) (default: admin/admin)  
- Gateway: [http://localhost:8080](http://localhost:8080) (try `/p1/docs`, `/p2/docs`, `/p3/docs`)  
- Prometheus: [http://localhost:9090](http://localhost:9090)  
- Grafana: [http://localhost:3000](http://localhost:3000) (default: admin/admin)  

Each service also exposes a `/metrics` endpoint for Prometheus scraping.

***

### Initial Database Seed
On first run, PostgreSQL automatically executes any SQL files in `seeds/` via the `docker-entrypoint-initdb.d` mechanism. In this repo, `seeds/01_seed.sql` is a safe no-op used to validate initialization.

Application data is seeded by Alembic migration `alembic/versions/0002_seed_data.py`. All migrations are located in the `alembic/` directory. The setup scripts automatically run:
```bash
alembic upgrade head
```
to ensure the schema is up to date.

***

### Health Checks
Test that each service is running:
```bash
GET http://localhost:8000/health
GET http://localhost:8001/health
GET http://localhost:8002/health
```