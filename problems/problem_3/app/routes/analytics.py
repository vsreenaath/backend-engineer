"""Analytics endpoints for Problem 3.

Provides baseline slow and optimized endpoints for top paths analytics,
plus a data seeding endpoint for testing/benchmarking.
"""
from __future__ import annotations

from datetime import datetime
from random import choice, randint
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy import insert
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.db import get_session
from ..models.page_view import PageView
from ..services.analytics import TopPath, top_paths_optimized, top_paths_slow

router = APIRouter(prefix="/analytics", tags=["analytics"]) 


class TopPathOut(BaseModel):
    path: str
    count: int


def _parse_dt(dt: Optional[datetime]) -> Optional[datetime]:
    return dt


@router.get("/top-paths/slow", response_model=List[TopPathOut])
async def get_top_paths_slow(
    start: Optional[datetime] = Query(default=None),
    end: Optional[datetime] = Query(default=None),
    limit: int = Query(default=10, ge=1, le=100),
    session: AsyncSession = Depends(get_session),
):
    data: List[TopPath] = await top_paths_slow(
        session, start=_parse_dt(start), end=_parse_dt(end), limit=limit
    )
    return [TopPathOut(path=d.path, count=d.count) for d in data]


@router.get("/top-paths/optimized", response_model=List[TopPathOut])
async def get_top_paths_optimized(
    start: Optional[datetime] = Query(default=None),
    end: Optional[datetime] = Query(default=None),
    limit: int = Query(default=10, ge=1, le=100),
    session: AsyncSession = Depends(get_session),
):
    data: List[TopPath] = await top_paths_optimized(
        session, start=_parse_dt(start), end=_parse_dt(end), limit=limit
    )
    return [TopPathOut(path=d.path, count=d.count) for d in data]


class SeedResult(BaseModel):
    inserted: int = Field(..., ge=0)


@router.post("/seed", response_model=SeedResult)
async def seed_data(
    rows: int = Query(default=10_000, ge=1, le=1_000_000),
    unique_paths: int = Query(default=100, ge=1, le=10_000),
    session: AsyncSession = Depends(get_session),
):
    """Generate synthetic page view data for benchmarking.

    This uses a set of randomized paths and bulk insert to the database.
    """
    # Prepare randomized set of paths
    paths = [f"/page/{i}" for i in range(unique_paths)]
    countries = ["US", "IN", "GB", "DE", "CA", "AU"]

    # Build bulk rows
    payload = [
        {
            "path": choice(paths),
            "user_id": randint(1, 1000),
            "country": choice(countries),
        }
        for _ in range(rows)
    ]

    await session.execute(insert(PageView), payload)
    await session.commit()

    return SeedResult(inserted=rows)
