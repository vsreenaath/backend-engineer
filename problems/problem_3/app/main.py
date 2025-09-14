from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator

from .core.config import settings
from .routes.analytics import router as analytics_router
from .routes.auth import router as auth_router

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    docs_url="/docs",
    redoc_url=None,
)

# CORS from Problem 1 settings
if settings.BACKEND_CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[str(o) for o in settings.BACKEND_CORS_ORIGINS],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# Routers
app.include_router(analytics_router, prefix="/api/p3")
app.include_router(auth_router, prefix="/api/p3")


@app.get("/health", tags=["health"])
async def health_check():
    return {"status": "ok", "service": "problem_3", "version": settings.APP_VERSION}

# Metrics
Instrumentator().instrument(app).expose(app)
