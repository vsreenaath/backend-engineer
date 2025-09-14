"""
Problem 2 endpoint tests (E-commerce API v2).

Covers authentication (via Problem 1), products, and orders endpoints.
Writes detailed logs to tests/logs/problem-2-tests.log and prints a summary.

Run independently:
    pytest -q problems/problem_2/tests/test_endpoints.py -s
"""
from __future__ import annotations

import os
import time
from pathlib import Path
from typing import Dict

import httpx
import psycopg2
from passlib.context import CryptContext
from dotenv import load_dotenv

LOG_DIR = Path("tests/logs")
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / "problem-2-tests.log"

pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")

BASE_URL_P1 = os.getenv("P1_BASE_URL", "http://localhost:8000")
BASE_URL_P2 = os.getenv("P2_BASE_URL", "http://localhost:8001")
API_V1 = "/api/v1"
API_V2 = "/api/v2"


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


def ensure_user(email: str, password: str, *, full_name: str = "P2 User", superuser: bool = True) -> int:
    """Ensure a user exists in DB with a bcrypt-hashed password; return id."""
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


def get_token(client: httpx.Client, email: str, password: str) -> str:
    r = client.post(
        f"{API_V1}/auth/login/access-token",
        data={"username": email, "password": password},
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    r.raise_for_status()
    data = r.json()
    assert "access_token" in data
    return data["access_token"]


def auth_headers(token: str) -> Dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_auth_signup_and_login_smoke() -> None:
    c2 = httpx.Client(base_url=BASE_URL_P2, timeout=30.0)

    # Unique email per run
    email = f"p2_smoke_{int(time.time())}@example.com"
    password = "Secret123!"

    # Signup via P2
    r = c2.post(f"{API_V2}/auth/signup", json={"email": email, "password": password, "full_name": "P2 Smoke"})
    r.raise_for_status(); user = r.json(); assert user["email"] == email; log("PASS auth: signup (P2 smoke)")

    # Login via P2
    r = c2.post(
        f"{API_V2}/auth/login/access-token",
        data={"username": email, "password": password},
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    r.raise_for_status(); token = r.json()["access_token"]; assert token; log("PASS auth: login (P2 smoke)")

    # /users/me
    r = c2.get(f"{API_V2}/users/me", headers=auth_headers(token))
    r.raise_for_status(); me = r.json(); assert me["email"] == email; log("PASS users: me (P2 smoke)")

    c2.close()


def test_problem_2_products_and_orders() -> None:
    LOG_FILE.unlink(missing_ok=True)
    c1 = httpx.Client(base_url=BASE_URL_P1, timeout=30.0)
    c2 = httpx.Client(base_url=BASE_URL_P2, timeout=30.0)

    # Prepare user and login via P1
    email = "p2admin@test.local"
    password = "Secret123!"
    ensure_user(email, password, full_name="P2 Admin", superuser=True)
    token = get_token(c1, email, password)
    log("PASS auth: login via P1 for P2 access")

    # Create a product
    unique_sku = f"SKU-INT-{int(time.time())}"
    prod_payload = {
        "sku": unique_sku,
        "name": "Widget",
        "price_cents": 1999,
        "stock": 10,
        "description": "Test widget",
    }
    r = c2.post(f"{API_V2}/products", headers=auth_headers(token), json=prod_payload)
    r.raise_for_status(); prod = r.json(); prod_id = prod["id"]; log("PASS products: create")

    # List products
    r = c2.get(f"{API_V2}/products")
    r.raise_for_status(); log("PASS products: list")

    # Get product by id
    r = c2.get(f"{API_V2}/products/{prod_id}")
    r.raise_for_status(); log("PASS products: get by id")

    # Update product
    r = c2.patch(f"{API_V2}/products/{prod_id}", headers=auth_headers(token), json={"name": "Widget Pro"})
    r.raise_for_status(); log("PASS products: update")

    # Adjust stock
    r = c2.patch(f"{API_V2}/products/{prod_id}/stock", headers=auth_headers(token), params={"delta": -2})
    r.raise_for_status(); log("PASS products: adjust stock -2")

    # Orders flow
    order_payload = {"items": [{"product_id": prod_id, "quantity": 2}]}
    r = c2.post(f"{API_V2}/orders", headers=auth_headers(token), json=order_payload)
    r.raise_for_status(); order = r.json(); order_id = order["id"]; log("PASS orders: create")

    # List orders
    r = c2.get(f"{API_V2}/orders", headers=auth_headers(token))
    r.raise_for_status(); log("PASS orders: list")

    # Poll order status until not PENDING
    final_status = None
    for _ in range(30):  # up to ~15s
        r = c2.get(f"{API_V2}/orders/{order_id}", headers=auth_headers(token))
        r.raise_for_status(); order = r.json(); status = order["status"]
        if status not in ("PENDING",):
            final_status = status
            break
        time.sleep(0.5)
    assert final_status is not None; log(f"PASS orders: processed status={final_status}")

    # Try to pay if allowed
    if final_status in ("RESERVED", "CONFIRMED"):
        r = c2.post(f"{API_V2}/orders/{order_id}/pay", headers=auth_headers(token))
        r.raise_for_status(); log("PASS orders: pay")
    else:
        log("PASS orders: skip pay (not in RESERVED/CONFIRMED)")

    # Cancel (should still return 200 unless already finalized/invalid)
    r = c2.post(f"{API_V2}/orders/{order_id}/cancel", headers=auth_headers(token))
    # Accept 200 or 400 depending on state; ensure endpoint reachable
    assert r.status_code in (200, 400); log("PASS orders: cancel (reachable)")

    # Cleanup
    r = c2.delete(f"{API_V2}/products/{prod_id}", headers=auth_headers(token))
    assert r.status_code in (204, 404); log("PASS products: delete or already deleted")

    c1.close(); c2.close()


def test_summary() -> None:
    """Parse the log file and print a brief summary to console."""
    if not LOG_FILE.exists():
        print("No log file found for Problem 2 tests.")
        return
    lines = LOG_FILE.read_text(encoding="utf-8").splitlines()
    passed = sum(1 for l in lines if l.startswith("PASS"))
    failed = sum(1 for l in lines if l.startswith("FAIL"))
    print(f"[P2 SUMMARY] Passed={passed} Failed={failed} Total={len(lines)}")
