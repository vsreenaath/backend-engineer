"""Configuration helpers for Problem 3.

We reuse Problem 1's settings for environment variables, and derive
an async DATABASE_URL for SQLAlchemy AsyncEngine.
"""
from __future__ import annotations

from typing import Optional
from urllib.parse import urlparse, urlunparse

from problems.problem_1.app.core.config import settings as p1_settings


class P3Settings:
    """Problem 3 settings derived from Problem 1 settings."""

    APP_NAME: str = "Performance Optimization API (Problem 3)"
    APP_VERSION: str = p1_settings.APP_VERSION

    DATABASE_URL: str = p1_settings.DATABASE_URL
    REDIS_URL: Optional[str] = getattr(p1_settings, "REDIS_URL", None)
    BACKEND_CORS_ORIGINS = p1_settings.BACKEND_CORS_ORIGINS

    @property
    def ASYNC_DATABASE_URL(self) -> str:
        """Return an asyncpg URL based on the sync DATABASE_URL.

        Converts postgresql:// to postgresql+asyncpg://
        """
        parsed = urlparse(self.DATABASE_URL)
        if parsed.scheme.startswith("postgresql+"):
            return self.DATABASE_URL
        if parsed.scheme == "postgresql":
            new_scheme = "postgresql+asyncpg"
            return urlunparse((
                new_scheme,
                parsed.netloc,
                parsed.path,
                parsed.params,
                parsed.query,
                parsed.fragment,
            ))
        # Fallback: assume already async-compatible
        return self.DATABASE_URL


settings = P3Settings()
