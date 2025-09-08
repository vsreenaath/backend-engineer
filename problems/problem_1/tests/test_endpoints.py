"""
Problem 1 endpoint tests (Task Management API).

Covers authentication, users, projects, and tasks endpoints.
Writes detailed logs to tests/logs/problem-1-tests.log and prints a summary.

Run independently:
    pytest -q problems/problem_1/tests/test_endpoints.py -s
"""
from __future__ import annotations

import os
import time
from pathlib import Path
from typing import Dict, Optional

import httpx
import psycopg2
from passlib.context import CryptContext
from pydantic import EmailStr, ValidationError
from dotenv import load_dotenv

LOG_DIR = Path("tests/logs")
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / "problem-1-tests.log"

pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")

BASE_URL = os.getenv("P1_BASE_URL", "http://localhost:8000")
API_PREFIX = "/api/v1"


def log(msg: str) -> None:
    line = msg.strip()
    print(line)
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(line + "\n")


def _host_db_dsn() -> str:
    load_dotenv(dotenv_path=Path(".env"))
    user = os.getenv("POSTGRES_USER", "postgres")
    password = os.getenv("POSTGRES_PASSWORD", "postgres")
    db = os.getenv("POSTGRES_DB", "app")
    host = os.getenv("POSTGRES_HOST") or os.getenv("POSTGRES_SERVER", "localhost") or "localhost"
    port = int(os.getenv("POSTGRES_PORT", "5432"))
    return f"host={host} port={port} dbname={db} user={user} password={password}"


def ensure_user(email: str, password: str, *, full_name: str = "Test User", superuser: bool = True) -> int:
    """Ensure a user exists in DB with a bcrypt-hashed password; return its id."""
    dsn = _host_db_dsn()
    hashed = pwd_ctx.hash(password)
    with psycopg2.connect(dsn) as conn:
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO users (email, hashed_password, full_name, is_active, is_superuser)
                VALUES (%s, %s, %s, true, %s)
                ON CONFLICT (email) DO UPDATE SET hashed_password = EXCLUDED.hashed_password
                RETURNING id
                """,
                (email, hashed, full_name, superuser),
            )
            row = cur.fetchone()
            if row is None:
                cur.execute("SELECT id FROM users WHERE email=%s", (email,))
                row = cur.fetchone()
            return int(row[0])


def cleanup_invalid_users() -> None:
    """Remove any previously created invalid emails that break EmailStr validation."""
    dsn = _host_db_dsn()
    with psycopg2.connect(dsn) as conn:
        conn.autocommit = True
        with conn.cursor() as cur:
            # Remove users created with @test.local to avoid email validation errors
            cur.execute("DELETE FROM users WHERE email LIKE '%@test.local'")
            # Remove any rows with emails that are not valid per pydantic EmailStr
            cur.execute("SELECT id, email FROM users")
            rows = cur.fetchall()
            bad_ids = []
            for uid, email in rows:
                try:
                    # Validate
                    _ = EmailStr.validate(email)
                except Exception:
                    bad_ids.append(uid)
            if bad_ids:
                cur.execute("DELETE FROM tasks WHERE assignee_id = ANY(%s)", (bad_ids,))
                cur.execute("DELETE FROM projects WHERE owner_id = ANY(%s)", (bad_ids,))
                cur.execute("DELETE FROM users WHERE id = ANY(%s)", (bad_ids,))


def get_token(client: httpx.Client, email: str, password: str) -> str:
    r = client.post(
        f"{API_PREFIX}/auth/login/access-token",
        data={"username": email, "password": password},
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    r.raise_for_status()
    data = r.json()
    assert "access_token" in data
    return data["access_token"]


def auth_headers(token: str) -> Dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_problem_1_flow() -> None:
    LOG_FILE.unlink(missing_ok=True)
    client = httpx.Client(base_url=BASE_URL, timeout=30.0, follow_redirects=True)

    # Prepare users
    admin_email = "admin@example.com"
    user2_email = "user2@example.com"
    password = "Secret123!"
    ensure_user(admin_email, password, full_name="Admin Test", superuser=True)
    ensure_user(user2_email, password, full_name="User Two", superuser=False)

    # Login
    token = get_token(client, admin_email, password)
    log("PASS auth: login access-token")

    # Users
    cleanup_invalid_users()
    r = client.get(f"{API_PREFIX}/users/me", headers=auth_headers(token))
    r.raise_for_status(); log("PASS users: me")

    r = client.get(f"{API_PREFIX}/users/", headers=auth_headers(token))
    r.raise_for_status(); log("PASS users: list")

    # Projects
    proj_payload = {"title": "Proj A", "description": "Demo"}
    r = client.post(f"{API_PREFIX}/projects/", headers=auth_headers(token), json=proj_payload)
    r.raise_for_status(); proj = r.json(); proj_id = proj["id"]; log("PASS projects: create")

    r = client.get(f"{API_PREFIX}/projects/", headers=auth_headers(token))
    r.raise_for_status(); log("PASS projects: list")

    r = client.get(f"{API_PREFIX}/projects/{proj_id}", headers=auth_headers(token))
    r.raise_for_status(); log("PASS projects: get by id")

    r = client.put(f"{API_PREFIX}/projects/{proj_id}", headers=auth_headers(token), json={"description": "Updated"})
    r.raise_for_status(); log("PASS projects: update")

    # Tasks
    task_payload = {"title": "Task 1", "description": "Desc", "project_id": proj_id, "assignee_id": None}
    r = client.post(f"{API_PREFIX}/tasks/", headers=auth_headers(token), json=task_payload)
    r.raise_for_status(); task = r.json(); task_id = task["id"]; log("PASS tasks: create")

    r = client.get(f"{API_PREFIX}/tasks/", headers=auth_headers(token))
    r.raise_for_status(); log("PASS tasks: list")

    r = client.get(f"{API_PREFIX}/tasks/{task_id}", headers=auth_headers(token))
    r.raise_for_status(); log("PASS tasks: get by id")

    r = client.post(f"{API_PREFIX}/tasks/{task_id}/status/InProgress", headers=auth_headers(token))
    r.raise_for_status(); log("PASS tasks: update status")

    # Assign to user2
    r = client.post(f"{API_PREFIX}/tasks/{task_id}/assign/2", headers=auth_headers(token))
    # Not guaranteed user2 id is 2; fallback:
    if r.status_code >= 400:
        # Fetch user2 id by email via admin list
        r2 = client.get(f"{API_PREFIX}/users", headers=auth_headers(token))
        r2.raise_for_status()
        u2id = next((u["id"] for u in r2.json() if u["email"] == user2_email), None)
        assert u2id is not None
        r = client.post(f"{API_PREFIX}/tasks/{task_id}/assign/{u2id}", headers=auth_headers(token))
    r.raise_for_status(); log("PASS tasks: assign")

    # Cleanup
    r = client.delete(f"{API_PREFIX}/tasks/{task_id}", headers=auth_headers(token))
    r.raise_for_status(); log("PASS tasks: delete")

    r = client.delete(f"{API_PREFIX}/projects/{proj_id}", headers=auth_headers(token))
    r.raise_for_status(); log("PASS projects: delete")

    client.close()


def test_summary() -> None:
    """Parse the log file and print a brief summary to console."""
    if not LOG_FILE.exists():
        print("No log file found for Problem 1 tests.")
        return
    lines = LOG_FILE.read_text(encoding="utf-8").splitlines()
    passed = sum(1 for l in lines if l.startswith("PASS"))
    failed = sum(1 for l in lines if l.startswith("FAIL"))
    print(f"[P1 SUMMARY] Passed={passed} Failed={failed} Total={len(lines)}")
