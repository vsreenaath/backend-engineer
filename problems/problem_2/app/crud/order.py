from typing import List, Optional
from sqlalchemy.orm import Session

from problems.problem_2.app.models.order import Order, OrderItem, OrderStatus
from problems.problem_2.app.models.product import Product


def get(db: Session, order_id: int) -> Optional[Order]:
    return db.query(Order).filter(Order.id == order_id).first()


def list_orders(db: Session, skip: int = 0, limit: int = 100) -> List[Order]:
    return db.query(Order).offset(skip).limit(limit).all()


def create_order(db: Session, user_id: int, items: List[dict]) -> Order:
    # items: [{product_id, quantity}]
    order = Order(user_id=user_id, status=OrderStatus.PENDING, total_cents=0)
    db.add(order)
    db.flush()  # get order.id

    total = 0
    for it in items:
        product: Product = db.query(Product).filter(Product.id == it["product_id"]).first()
        if not product:
            raise ValueError(f"Product {it['product_id']} not found")
        qty = int(it["quantity"])
        if qty <= 0:
            raise ValueError("Quantity must be > 0")
        line_total = product.price_cents * qty
        total += line_total
        db.add(OrderItem(order_id=order.id, product_id=product.id, quantity=qty, unit_price_cents=product.price_cents))

    order.total_cents = total
    db.commit()
    db.refresh(order)
    return order


def set_status(db: Session, order: Order, status: OrderStatus) -> Order:
    order.status = status
    db.add(order)
    db.commit()
    db.refresh(order)
    return order
