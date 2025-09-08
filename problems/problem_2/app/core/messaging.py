from typing import Any, Dict
import json
import os
import redis

# Reuse settings from Problem 1 (use fully-qualified import to avoid PATH issues)
from problems.problem_1.app.core.config import settings

_redis_client = None


def get_redis_client() -> redis.Redis:
    global _redis_client
    if _redis_client is None:
        url = settings.REDIS_URL
        _redis_client = redis.from_url(url, decode_responses=True)
    return _redis_client


def publish_event(stream: str, payload: Dict[str, Any]) -> None:
    """
    Publish a JSON-encoded event to a Redis list (acting as a lightweight queue).
    We use LPUSH + BRPOP in the worker for simplicity.
    """
    client = get_redis_client()
    client.lpush(stream, json.dumps(payload))
