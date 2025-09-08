import json
import time
from sqlalchemy.orm import Session

from problems.problem_1.app.core.database import SessionLocal
from problems.problem_1.app.models.user import User  # noqa: F401 ensure users table registered
from problems.problem_2.app.core.messaging import get_redis_client
from problems.problem_2.app.models.order import OrderStatus
from problems.problem_2.app.models.product import Product
from problems.problem_2.app.crud.order import get as get_order, set_status

QUEUE_RESERVE = "queue:reserve_stock"
QUEUE_CANCEL = "queue:cancel_order"


def reserve_stock(db: Session, order_id: int):
    order = get_order(db, order_id)
    if not order or order.status != OrderStatus.PENDING:
        return

    # Lock products sequentially and ensure availability
    ok = True
    for item in order.items:
        product = db.query(Product).filter(Product.id == item.product_id).with_for_update().first()
        if not product or product.stock < item.quantity:
            ok = False
            break

    if ok:
        for item in order.items:
            product = db.query(Product).filter(Product.id == item.product_id).with_for_update().first()
            product.stock -= item.quantity
            db.add(product)
        db.commit()
        set_status(db, order, OrderStatus.RESERVED)
    else:
        set_status(db, order, OrderStatus.FAILED)


def compensate_cancel(db: Session, order_id: int):
    order = get_order(db, order_id)
    if not order:
        return
    if order.status in {OrderStatus.RESERVED, OrderStatus.CONFIRMED}:
        for item in order.items:
            product = db.query(Product).filter(Product.id == item.product_id).with_for_update().first()
            if product:
                product.stock += item.quantity
                db.add(product)
        db.commit()


def main():
    r = get_redis_client()
    print("[worker] started")
    while True:
        # Block for events from either queue
        res = r.brpop([QUEUE_RESERVE, QUEUE_CANCEL], timeout=1)
        if not res:
            continue
        queue, raw = res
        try:
            payload = json.loads(raw)
        except Exception:
            continue
        order_id = payload.get("order_id")
        with SessionLocal() as db:
            if queue == QUEUE_RESERVE:
                reserve_stock(db, order_id)
            elif queue == QUEUE_CANCEL:
                compensate_cancel(db, order_id)
        time.sleep(0.01)


if __name__ == "__main__":
    main()
