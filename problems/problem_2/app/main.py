from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from problems.problem_2.app.api import api_router_v2
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
