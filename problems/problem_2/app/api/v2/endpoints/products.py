from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status, Response
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db

from problems.problem_2.app import schemas
from problems.problem_2.app.crud import product as product_crud

router = APIRouter()


@router.post("/products", response_model=schemas.Product)
def create_product(
    payload: schemas.ProductCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> Any:
    if product_crud.get_by_sku(db, payload.sku):
        raise HTTPException(status_code=400, detail="SKU already exists")
    return product_crud.create(
        db,
        sku=payload.sku,
        name=payload.name,
        price_cents=payload.price_cents,
        stock=payload.stock,
        description=payload.description,
    )


@router.get("/products", response_model=List[schemas.Product])
def list_products_endpoint(db: Session = Depends(get_db)) -> Any:
    return product_crud.list_products(db)


@router.get("/products/{product_id}", response_model=schemas.Product)
def get_product(product_id: int, db: Session = Depends(get_db)) -> Any:
    prod = product_crud.get(db, product_id)
    if not prod:
        raise HTTPException(status_code=404, detail="Product not found")
    return prod


@router.patch("/products/{product_id}", response_model=schemas.Product)
def update_product(product_id: int, payload: schemas.ProductUpdate, db: Session = Depends(get_db), current_user=Depends(get_current_user)) -> Any:
    prod = product_crud.get(db, product_id)
    if not prod:
        raise HTTPException(status_code=404, detail="Product not found")
    return product_crud.update(db, prod, **payload.dict(exclude_unset=True))


@router.delete("/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT, response_class=Response)
def delete_product(product_id: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)) -> Response:
    prod = product_crud.get(db, product_id)
    if not prod:
        raise HTTPException(status_code=404, detail="Product not found")
    product_crud.delete(db, prod)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.patch("/products/{product_id}/stock", response_model=schemas.Product)
def adjust_stock(product_id: int, delta: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)) -> Any:
    prod = product_crud.get(db, product_id)
    if not prod:
        raise HTTPException(status_code=404, detail="Product not found")
    try:
        return product_crud.adjust_stock(db, prod, delta)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
