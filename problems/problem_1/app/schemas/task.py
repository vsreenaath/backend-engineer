from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from .base import BaseSchema
from .user import User
from ..models.task import TaskStatus

# Shared properties
class TaskBase(BaseSchema):
    title: str = Field(..., min_length=3, max_length=100)
    description: Optional[str] = None
    status: TaskStatus = TaskStatus.TODO
    due_date: Optional[datetime] = None

# Properties to receive on task creation
class TaskCreate(TaskBase):
    project_id: int
    assignee_id: Optional[int] = None

# Properties to receive on task update
class TaskUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=3, max_length=100)
    description: Optional[str] = None
    status: Optional[TaskStatus] = None
    assignee_id: Optional[int] = None
    due_date: Optional[datetime] = None

# Properties shared by models stored in DB
class TaskInDBBase(TaskBase):
    id: int
    project_id: int
    assignee_id: Optional[int] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True

# Properties to return to client (with relationships)
class Task(TaskInDBBase):
    assignee: Optional[User] = None

# Properties stored in DB (with relationships)
class TaskInDB(TaskInDBBase):
    pass

# Properties to include in response with project info
class TaskWithProject(TaskInDBBase):
    project: "Project"

# Update forward refs for Project
from .project import Project  # noqa
TaskWithProject.update_forward_refs()
