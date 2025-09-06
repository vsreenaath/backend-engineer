# Task Management API (Problem 1)

A FastAPI-based task management backend with JWT auth, Postgres, and Alembic migrations.  
Docker Compose spins up the full stack, including pgAdmin.

---

## Features
- Users, Projects, Tasks with role checks  
- JWT authentication (password hashing via bcrypt)  
- SQLAlchemy 2.x models with Alembic migrations  
- Dockerized for Windows/Linux/macOS  
- pgAdmin for DB visibility  

---

## Tech Stack
- FastAPI, Uvicorn  
- SQLAlchemy 2.x, Alembic  
- Pydantic v1  
- Postgres, pgAdmin  
- Docker Compose  

---

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

**Windows**

```powershell
powershell -ExecutionPolicy Bypass -File setup-windows.ps1
```

**Linux**

```bash
chmod +x setup-linux.sh
./setup-linux.sh
```

**macOS**

```bash
chmod +x setup-macos.sh
./setup-macos.sh
```

This will:

* Copy `.env` and generate a fresh `SECRET_KEY`
* Build and start containers
* Apply Alembic migrations (or stamp the DB to head if already initialized)

### 3) Access the services

* API: [http://localhost:8000](http://localhost:8000)
* Docs (Swagger UI): [http://localhost:8000/docs](http://localhost:8000/docs)
* pgAdmin: [http://localhost:5050](http://localhost:5050)

  * Default login: `admin@admin.com` / `admin`

---

## Authentication

### Seeded Users

The project comes with **initial seed data**:

| Email               | Password | Role      |
| ------------------- | -------- | --------- |
| `admin@example.com` | `admin`  | Superuser |
| `user@example.com`  | `user`   | Regular   |

⚠️ These passwords are stored as plain text in the seed for demo purposes.
For production, always hash passwords (or create new users via API).

---

## 🧪 Testing the API

You can test endpoints in three ways:

### 1. Swagger UI

* Open [http://localhost:8000/docs](http://localhost:8000/docs)
* Click **“Authorize”** and paste your JWT token
* Try endpoints interactively

### 2. HTTP Client (cURL)

Example flow with seeded users:

```bash
# 1. Login with admin
curl -X POST "http://localhost:8000/api/v1/auth/login/access-token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@example.com&password=admin"

# Response will contain access_token
# {
#   "access_token": "<token>",
#   "token_type": "bearer"
# }

# 2. Use token to fetch projects
curl -X GET "http://localhost:8000/api/v1/projects" \
  -H "Authorization: Bearer <token>"
```

### 3. API Client (Postman / Insomnia)

* Base URL: `http://localhost:8000`
* Login via `/api/v1/auth/login/access-token` with seeded user credentials
* Set **Authorization → Bearer Token** with your JWT
* Test `/users`, `/projects`, `/tasks` endpoints

---

## Example Seeded Data

The first run seeds the database with:

**Projects**

* `Internal Tools` (owner: admin)
* `Website Redesign` (owner: admin)

**Tasks**

* `Design database schema` – ToDo – assigned to admin
* `Set up CI/CD` – InProgress – assigned to admin
* `Implement landing page` – ToDo – assigned to user

---

## Project Layout

* `problems/problem_1/app/main.py` – FastAPI app factory and routing
* `problems/problem_1/app/api/` – API routers and dependencies
* `problems/problem_1/app/core/` – Settings, DB base, security (JWT, hashing)
* `problems/problem_1/app/models/` – SQLAlchemy models
* `problems/problem_1/app/crud/` – DB CRUD operations
* `problems/problem_1/app/schemas/` – Pydantic schemas
* `alembic/` – Migrations (run inside the web container)
* `seeds/` – First-run SQL seeding for Postgres

---

## Docker Cheat Sheet

* Start: `docker compose up -d --build`
* Logs: `docker compose logs -f`
* Stop: `docker compose down`
* Exec shell in web: `docker compose exec web bash`
* Apply migrations: `docker compose exec web alembic upgrade head`

---

## Troubleshooting

* If migrations fail due to existing tables, the setup scripts will stamp head and continue.
* If port conflicts occur, change `8000` (FastAPI) or `5432` (Postgres) in `docker-compose.yml`.
* Ensure Docker Desktop is running on Windows/macOS.

---

```

---

👉 This version is **ready for submission**:  
- Clear **setup instructions**  
- Includes **seed credentials**  
- Shows **sample cURL flow**  
- Documents **projects & tasks from seed data**  


Perfect 👍 Here’s a **second section** you can drop right into your README after the **Testing the API** section.
It shows a **step-by-step workflow example** using cURL with both seeded users and custom ones.

````markdown
---

## 🔄 Example Workflow (End-to-End)

This section walks through a typical flow: **register → login → create project → add task → fetch tasks**.  
You can test this with seeded users or create your own.

---

### 1. Register a New User (optional)
```bash
curl -X POST "http://localhost:8000/api/v1/users" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newuser@example.com",
    "password": "secret",
    "full_name": "New User"
  }'
````

---

### 2. Login to Get Token

```bash
curl -X POST "http://localhost:8000/api/v1/auth/login/access-token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=newuser@example.com&password=secret"
```

➡️ Or use seeded admin:

* `username=admin@example.com`
* `password=admin`

The response contains a JWT token:

```json
{
  "access_token": "<token>",
  "token_type": "bearer"
}
```

Save this token for the next steps.

---

### 3. Create a Project

```bash
curl -X POST "http://localhost:8000/api/v1/projects" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Demo Project",
    "description": "API testing project"
  }'
```

---

### 4. Create a Task in the Project

```bash
curl -X POST "http://localhost:8000/api/v1/tasks" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Write documentation",
    "description": "Prepare detailed README",
    "status": "ToDo",
    "project_id": 1,
    "assignee_id": 1
  }'
```

---

### 5. List All Tasks

```bash
curl -X GET "http://localhost:8000/api/v1/tasks" \
  -H "Authorization: Bearer <token>"
```

Response example:

```json
[
  {
    "id": 1,
    "title": "Design database schema",
    "status": "ToDo",
    "project_id": 1,
    "assignee_id": 1
  },
  {
    "id": 2,
    "title": "Write documentation",
    "status": "ToDo",
    "project_id": 1,
    "assignee_id": 1
  }
]
```

---

✅ With these steps, you can verify **the full lifecycle** of the app:

* User creation
* Authentication with JWT
* Project creation
* Task assignment
* Task retrieval

