from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator

from problems.problem_2.app.api import api_router_v2
from problems.problem_2.app import models as _models  # noqa: F401 ensure User table registered
from problems.problem_1.app.core.config import settings

app = FastAPI(
    title="E-commerce API (Problem 2)",
    version=settings.APP_VERSION,
    docs_url="/docs",
    redoc_url=None,
)

# CORS (reuse settings)
if settings.BACKEND_CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[str(o) for o in settings.BACKEND_CORS_ORIGINS],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# Mount v2 router (keeps /api/v2 prefix)
app.include_router(api_router_v2, prefix="/api/v2")


@app.get("/health", tags=["health"])
async def health_check():
    return {"status": "ok", "service": "problem_2", "version": settings.APP_VERSION}


@app.get("/", include_in_schema=False)
async def root():
    return {
        "service": "E-commerce API (Problem 2)",
        "version": settings.APP_VERSION,
        "docs": "/docs",
        "health": "/health",
        "api_base": "/api/v2",
    }

# Metrics
Instrumentator().instrument(app).expose(app)
