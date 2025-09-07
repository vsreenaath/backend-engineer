from fastapi import APIRouter

from problems.problem_2.app.api.v2.endpoints import products, orders, auth

api_router_v2 = APIRouter()
api_router_v2.include_router(auth.router, tags=["auth"])
api_router_v2.include_router(products.router, tags=["products"])
api_router_v2.include_router(orders.router, tags=["orders"])
