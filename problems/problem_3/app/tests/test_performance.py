from __future__ import annotations

import time
from typing import List

import httpx
import pytest

BASE_URL = "http://localhost:8002/api/p3"


@pytest.fixture(scope="session")
def client() -> httpx.Client:
    return httpx.Client(base_url=BASE_URL, timeout=60.0)


def test_seed_data(client: httpx.Client) -> None:
    # Seed a moderate dataset for benchmarks
    params = {"rows": 50000, "unique_paths": 200}
    resp = client.post("/analytics/seed", params=params)
    resp.raise_for_status()
    data = resp.json()
    assert data["inserted"] == params["rows"]


def test_top_paths_slow_basic(client: httpx.Client) -> None:
    resp = client.get("/analytics/top-paths/slow", params={"limit": 10})
    resp.raise_for_status()
    results: List[dict] = resp.json()
    assert isinstance(results, list)
    assert len(results) <= 10
    assert all("path" in r and "count" in r for r in results)


def test_top_paths_optimized_basic(client: httpx.Client) -> None:
    resp = client.get("/analytics/top-paths/optimized", params={"limit": 10})
    resp.raise_for_status()
    results: List[dict] = resp.json()
    assert isinstance(results, list)
    assert len(results) <= 10
    assert all("path" in r and "count" in r for r in results)


@pytest.mark.benchmark(group="p3_top_paths")
def test_benchmark_slow(benchmark: pytest.BenchmarkFixture, client: httpx.Client) -> None:
    def fetch():
        r = client.get("/analytics/top-paths/slow", params={"limit": 10})
        r.raise_for_status()
        return r.json()

    results = benchmark(fetch)
    assert isinstance(results, list)


@pytest.mark.benchmark(group="p3_top_paths")
def test_benchmark_optimized(benchmark: pytest.BenchmarkFixture, client: httpx.Client) -> None:
    def fetch():
        r = client.get("/analytics/top-paths/optimized", params={"limit": 10})
        r.raise_for_status()
        return r.json()

    results = benchmark(fetch)
    assert isinstance(results, list)


def test_manual_compare(client: httpx.Client) -> None:
    # Simple manual comparison to ensure optimized is faster than slow
    t0 = time.perf_counter()
    rs = client.get("/analytics/top-paths/slow", params={"limit": 10})
    rs.raise_for_status()
    slow_time = time.perf_counter() - t0

    t1 = time.perf_counter()
    ro = client.get("/analytics/top-paths/optimized", params={"limit": 10})
    ro.raise_for_status()
    opt_time = time.perf_counter() - t1

    # Optimized should be at least 1.5x faster in typical environments
    assert opt_time < slow_time * 0.67, f"optimized {opt_time:.4f}s vs slow {slow_time:.4f}s" 
