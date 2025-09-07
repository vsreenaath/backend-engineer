from typing import List, Optional
from pydantic import BaseModel, Field
from datetime import datetime

from problems.problem_2.app.models.order import OrderStatus


class OrderItemCreate(BaseModel):
    product_id: int
    quantity: int = Field(..., gt=0)


class OrderCreate(BaseModel):
    items: List[OrderItemCreate]


class OrderItem(BaseModel):
    id: int
    product_id: int
    quantity: int
    unit_price_cents: int

    class Config:
        orm_mode = True


class Order(BaseModel):
    id: int
    user_id: int
    status: OrderStatus
    total_cents: int
    items: List[OrderItem] = Field(default_factory=list)
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True


class PaymentRequest(BaseModel):
    method: str = "card"
