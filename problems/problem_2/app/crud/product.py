from typing import List, Optional
from sqlalchemy.orm import Session

from problems.problem_2.app.models.product import Product
from problems.problem_2.app.models.order import OrderItem


def get(db: Session, product_id: int) -> Optional[Product]:
    return db.query(Product).filter(Product.id == product_id).first()


def get_by_sku(db: Session, sku: str) -> Optional[Product]:
    return db.query(Product).filter(Product.sku == sku).first()


def list_products(db: Session, skip: int = 0, limit: int = 100) -> List[Product]:
    return db.query(Product).offset(skip).limit(limit).all()


def create(db: Session, sku: str, name: str, price_cents: int, stock: int = 0, description: Optional[str] = None) -> Product:
    obj = Product(sku=sku, name=name, price_cents=price_cents, stock=stock, description=description)
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


def update(db: Session, product: Product, **fields) -> Product:
    for k, v in fields.items():
        if v is not None:
            setattr(product, k, v)
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


def delete(db: Session, product: Product) -> None:
    # Remove dependent order items first to satisfy FK constraints
    db.query(OrderItem).filter(OrderItem.product_id == product.id).delete(synchronize_session=False)
    db.delete(product)
    db.commit()


def adjust_stock(db: Session, product: Product, delta: int) -> Product:
    product.stock = (product.stock or 0) + delta
    if product.stock < 0:
        raise ValueError("Stock cannot be negative")
    db.add(product)
    db.commit()
    db.refresh(product)
    return product
