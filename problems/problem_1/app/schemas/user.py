from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime
from .base import BaseSchema
from app.models.user import User as UserModel

# Shared properties
class UserBase(BaseSchema):
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    is_active: Optional[bool] = True
    is_superuser: bool = False

# Properties to receive via API on creation
class UserCreate(UserBase):
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=100)

# Properties to receive via API on update
class UserUpdate(UserBase):
    password: Optional[str] = Field(None, min_length=6, max_length=100)

# Properties shared by models stored in DB
class UserInDBBase(UserBase):
    id: int
    email: str
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True

# Additional properties to return via API
class User(UserInDBBase):
    pass

# Additional properties stored in DB
class UserInDB(UserInDBBase):
    hashed_password: str

# Token schemas
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenPayload(BaseModel):
    sub: Optional[int] = None
