"""PageView model for Problem 3.

Represents a simple analytics event for a page view.
"""
from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from problems.problem_1.app.core.database import Base


class PageView(Base):
    """ORM model for page_views table."""

    __tablename__ = "page_views"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    path: Mapped[str] = mapped_column(String(255), index=True, nullable=False)
    user_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    country: Mapped[Optional[str]] = mapped_column(String(2), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default="NOW()"
    )
