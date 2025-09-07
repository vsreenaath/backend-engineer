from typing import Optional
from pydantic import BaseModel, Field
from datetime import datetime


class ProductBase(BaseModel):
    sku: str = Field(..., min_length=1)
    name: str
    description: Optional[str] = None
    price_cents: int = Field(..., ge=0)
    stock: int = Field(0, ge=0)


class ProductCreate(ProductBase):
    pass


class ProductUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price_cents: Optional[int] = Field(None, ge=0)
    stock: Optional[int] = Field(None, ge=0)


class ProductInDBBase(ProductBase):
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True


class Product(ProductInDBBase):
    pass
