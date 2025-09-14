from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

# Reuse Problem 1 components
from app.core import security
from app.core.config import settings
from app.crud import user as crud_user
from app.db.session import get_db
from app.api.deps import get_current_user
from app import schemas as p1_schemas

router = APIRouter()


@router.post("/auth/login/access-token", response_model=p1_schemas.Token)
def login_access_token(
    db: Session = Depends(get_db), form_data: OAuth2PasswordRequestForm = Depends()
) -> Any:
    user = crud_user.authenticate(db, email=form_data.username, password=form_data.password)
    if not user:
        raise HTTPException(status_code=400, detail="Incorrect email or password")
    if not crud_user.is_active(user):
        raise HTTPException(status_code=400, detail="Inactive user")

    access_token = security.create_access_token(user.id)
    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/users/me", response_model=p1_schemas.User)
def read_users_me(current_user=Depends(get_current_user)) -> Any:
    return current_user


@router.post("/auth/signup", response_model=p1_schemas.User)
def signup(
    *,
    db: Session = Depends(get_db),
    user_in: p1_schemas.UserCreate,
) -> Any:
    """
    Public signup endpoint for Problem 2 service, reusing Problem 1 models.
    Always creates a standard user (non-superuser).
    """
    if crud_user.get_by_email(db, email=user_in.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The user with this email already exists in the system.",
        )
    safe_user = p1_schemas.UserCreate(
        email=user_in.email,
        password=user_in.password,
        full_name=user_in.full_name,
        is_superuser=False,
    )
    user = crud_user.create(db, obj_in=safe_user)
    return user
