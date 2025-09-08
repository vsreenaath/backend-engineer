"""Analytics services for Problem 3.

Implements both a slow baseline and an optimized version of an endpoint
that returns the most viewed paths within an optional time window.

- Slow: loads rows and aggregates in Python.
- Optimized: uses SQL aggregation, proper indexes, connection pooling,
             and Redis caching.
"""
from __future__ import annotations

from collections import Counter
from dataclasses import asdict, dataclass
from datetime import datetime
from typing import List, Optional, Sequence

from sqlalchemy import Select, desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.page_view import PageView
from .cache import cache_get, cache_set


@dataclass
class TopPath:
    path: str
    count: int


def _build_cache_key(prefix: str, start: Optional[datetime], end: Optional[datetime], limit: int) -> str:
    s = start.isoformat() if start else ""
    e = end.isoformat() if end else ""
    return f"p3:{prefix}:{s}:{e}:{limit}"


async def top_paths_slow(
    session: AsyncSession,
    *,
    start: Optional[datetime] = None,
    end: Optional[datetime] = None,
    limit: int = 10,
) -> List[TopPath]:
    """Baseline slow implementation: loads rows and aggregates in Python."""
    stmt: Select = select(PageView)
    if start:
        stmt = stmt.where(PageView.created_at >= start)
    if end:
        stmt = stmt.where(PageView.created_at <= end)

    # This can be extremely slow with large datasets
    result = await session.execute(stmt)
    rows: Sequence[PageView] = result.scalars().all()

    counter: Counter[str] = Counter(pv.path for pv in rows)
    top = counter.most_common(limit)
    return [TopPath(path=p, count=c) for p, c in top]


async def top_paths_optimized(
    session: AsyncSession,
    *,
    start: Optional[datetime] = None,
    end: Optional[datetime] = None,
    limit: int = 10,
    cache_ttl: int = 30,
) -> List[TopPath]:
    """Optimized implementation with SQL aggregation and Redis caching."""
    cache_key = _build_cache_key("top_paths", start, end, limit)
    cached = await cache_get(cache_key)
    if cached is not None:
        # cached is list of dicts
        return [TopPath(**item) for item in cached]

    stmt = select(PageView.path, func.count(PageView.id).label("cnt"))
    if start:
        stmt = stmt.where(PageView.created_at >= start)
    if end:
        stmt = stmt.where(PageView.created_at <= end)
    stmt = stmt.group_by(PageView.path).order_by(desc("cnt")).limit(limit)

    result = await session.execute(stmt)
    rows = result.all()

    data = [TopPath(path=r[0], count=int(r[1])) for r in rows]
    await cache_set(cache_key, [asdict(d) for d in data], ttl_seconds=cache_ttl)
    return data
