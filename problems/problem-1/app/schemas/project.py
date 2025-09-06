from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from .base import BaseSchema
from .user import User

# Shared properties
class ProjectBase(BaseSchema):
    title: str = Field(..., min_length=3, max_length=100)
    description: Optional[str] = None

# Properties to receive on project creation
class ProjectCreate(ProjectBase):
    pass

# Properties to receive on project update
class ProjectUpdate(ProjectBase):
    title: Optional[str] = Field(None, min_length=3, max_length=100)

# Properties shared by models stored in DB
class ProjectInDBBase(ProjectBase):
    id: int
    owner_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True

# Properties to return to client (without relationships)
class Project(ProjectInDBBase):
    pass

# Properties stored in DB (with relationships)
class ProjectInDB(ProjectInDBBase):
    pass

# Properties to include in response with relationships
class ProjectWithTasks(ProjectInDBBase):
    tasks: List["Task"] = []

# Update forward refs for Task
from .task import Task  # noqa
ProjectWithTasks.update_forward_refs()
