from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db

from problems.problem_2.app import schemas
from problems.problem_2.app import crud
from problems.problem_2.app.core.messaging import publish_event
from problems.problem_2.app.models.order import OrderStatus

router = APIRouter()


@router.post("/orders", response_model=schemas.Order)
def create_order(
    payload: schemas.OrderCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> Any:
    order = crud.create_order(db, user_id=current_user.id, items=[i.dict() for i in payload.items])
    # publish reserve event
    publish_event("queue:reserve_stock", {"order_id": order.id})
    return order


@router.get("/orders", response_model=List[schemas.Order])
def list_orders(db: Session = Depends(get_db), current_user=Depends(get_current_user)) -> Any:
    return crud.list_orders(db)


@router.get("/orders/{order_id}", response_model=schemas.Order)
def get_order(order_id: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)) -> Any:
    order = crud.get(db, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@router.post("/orders/{order_id}/pay", response_model=schemas.Order)
def pay_order(order_id: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)) -> Any:
    order = crud.get(db, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    if order.status not in {OrderStatus.RESERVED, OrderStatus.CONFIRMED}:
        raise HTTPException(status_code=400, detail="Order not ready for payment")
    return crud.set_status(db, order, OrderStatus.PAID)


@router.post("/orders/{order_id}/cancel", response_model=schemas.Order)
def cancel_order(order_id: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)) -> Any:
    order = crud.get(db, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    if order.status in {OrderStatus.PAID, OrderStatus.CANCELLED}:
        raise HTTPException(status_code=400, detail="Cannot cancel finalized order")
    # Compensate via event (worker will restock if necessary)
    publish_event("queue:cancel_order", {"order_id": order.id})
    return crud.set_status(db, order, OrderStatus.CANCELLED)
