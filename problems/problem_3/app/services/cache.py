"""Redis cache utilities for Problem 3.

Uses redis.asyncio client from the redis package.
"""
from __future__ import annotations

import asyncio
import json
from typing import Any, Optional

from redis.asyncio import Redis

from ..core.config import settings

_redis_singleton: Optional[Redis] = None
_redis_lock = asyncio.Lock()


async def get_redis() -> Redis:
    """Return a singleton Redis client using the REDIS_URL from settings."""
    global _redis_singleton
    if _redis_singleton is None:
        async with _redis_lock:
            if _redis_singleton is None:
                if not settings.REDIS_URL:
                    raise RuntimeError("REDIS_URL is not configured")
                _redis_singleton = Redis.from_url(settings.REDIS_URL, decode_responses=True)
    return _redis_singleton


async def cache_get(key: str) -> Optional[Any]:
    """Get a JSON value from Redis cache."""
    r = await get_redis()
    data = await r.get(key)
    if data is None:
        return None
    try:
        return json.loads(data)
    except json.JSONDecodeError:
        return data


async def cache_set(key: str, value: Any, ttl_seconds: int = 60) -> None:
    """Set a JSON-serializable value into Redis with TTL."""
    r = await get_redis()
    payload = json.dumps(value, default=str)
    await r.set(key, payload, ex=ttl_seconds)
