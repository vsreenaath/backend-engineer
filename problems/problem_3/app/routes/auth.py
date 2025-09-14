from typing import Any, Optional, Union
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status, Body
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from jose import jwt, JWTError
from pydantic import BaseModel, ValidationError
from passlib.context import CryptContext

# Use Problem 1 settings and User model explicitly without importing modules that rely on top-level 'app'
from problems.problem_1.app.core.config import settings as p1_settings
from problems.problem_1.app.core.database import get_db
from problems.problem_1.app.models.user import User as P1User

router = APIRouter(prefix="/auth", tags=["auth"]) 

reusable_oauth2 = OAuth2PasswordBearer(tokenUrl="/api/p3/auth/login/access-token")


class Token(BaseModel):
    access_token: str
    token_type: str


class TokenPayload(BaseModel):
    sub: Optional[int] = None


class UserOut(BaseModel):
    id: int
    email: str
    is_active: bool
    is_superuser: bool
    full_name: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True


# Local security helpers (avoid importing P1 security which depends on 'app')
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(subject: Union[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=p1_settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode = {"exp": expire, "sub": str(subject)}
    return jwt.encode(to_encode, p1_settings.SECRET_KEY, algorithm=p1_settings.ALGORITHM)


@router.post("/login/access-token", response_model=Token)
def login_access_token(
    db: Session = Depends(get_db),
    form_data: OAuth2PasswordRequestForm = Depends(),
) -> Any:
    user = db.query(P1User).filter(P1User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Incorrect email or password")
    if not user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")

    access_token = create_access_token(user.id)
    return {"access_token": access_token, "token_type": "bearer"}


def _get_current_user(
    db: Session = Depends(get_db), token: str = Depends(reusable_oauth2)
) -> Any:
    try:
        payload = jwt.decode(token, p1_settings.SECRET_KEY, algorithms=[p1_settings.ALGORITHM])
        token_data = TokenPayload(**payload)
    except (JWTError, ValidationError):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Could not validate credentials")
    user_obj = db.query(P1User).filter(P1User.id == token_data.sub).first()
    if not user_obj:
        raise HTTPException(status_code=404, detail="User not found")
    if not user_obj.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return user_obj


@router.get("/users/me", response_model=UserOut)
def read_users_me(current_user=Depends(_get_current_user)) -> Any:
    return current_user


@router.post("/signup", response_model=UserOut)
def signup(
    *,
    db: Session = Depends(get_db),
    user_in: dict = Body(...),
) -> Any:
    """
    Public signup endpoint for Problem 3 service.
    Always creates a standard (non-superuser) user.
    """
    # user_in is expected to be a dict-like with at least email, password, full_name
    email = user_in.get('email')
    password = user_in.get('password')
    full_name = user_in.get('full_name')

    existing = db.query(P1User).filter(P1User.email == email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The user with this email already exists in the system.",
        )
    db_user = P1User(
        email=email,
        hashed_password=get_password_hash(password),
        full_name=full_name,
        is_superuser=False,
        is_active=True,
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user
