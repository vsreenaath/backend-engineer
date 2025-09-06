from typing import Any, List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import crud, models, schemas
from app.api import deps
from app.db.session import get_db
from app.models.task import TaskStatus

router = APIRouter()

@router.get("/", response_model=List[schemas.Task])
def read_tasks(
    db: Session = Depends(get_db),
    skip: int = 0,
    limit: int = 100,
    current_user: models.User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Retrieve tasks.
    """
    if crud.user.is_superuser(current_user):
        tasks = crud.task.get_multi(db, skip=skip, limit=limit)
    else:
        tasks = crud.task.get_multi_by_assignee(
            db=db, assignee_id=current_user.id, skip=skip, limit=limit
        )
    return tasks

@router.post("/", response_model=schemas.Task)
def create_task(
    *,
    db: Session = Depends(get_db),
    task_in: schemas.TaskCreate,
    current_user: models.User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Create new task.
    """
    # Verify the project exists and user has access
    project = crud.project.get(db, id=task_in.project_id)
    if not project:
        raise HTTPException(
            status_code=404,
            detail="The project does not exist in the system",
        )
    if not crud.user.is_superuser(current_user) and (project.owner_id != current_user.id):
        raise HTTPException(
            status_code=400, detail="Not enough permissions to create task in this project"
        )
    
    # If assignee_id is provided, verify the assignee exists
    if task_in.assignee_id:
        user = crud.user.get(db, id=task_in.assignee_id)
        if not user:
            raise HTTPException(
                status_code=404,
                detail="The assignee does not exist in the system",
            )
    
    task = crud.task.create(db, obj_in=task_in)
    return task

@router.put("/{task_id}", response_model=schemas.Task)
def update_task(
    *,
    db: Session = Depends(get_db),
    task_id: int,
    task_in: schemas.TaskUpdate,
    current_user: models.User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Update a task.
    """
    task = crud.task.get(db, id=task_id)
    if not task:
        raise HTTPException(
            status_code=404,
            detail="The task does not exist in the system",
        )
    
    # Get the project to check permissions
    project = crud.project.get(db, id=task.project_id)
    if not project:
        raise HTTPException(
            status_code=404,
            detail="The project for this task does not exist",
        )
    
    # Check if user is project owner or superuser
    is_owner = project.owner_id == current_user.id
    is_assignee = task.assignee_id == current_user.id
    
    if not (crud.user.is_superuser(current_user) or is_owner or is_assignee):
        raise HTTPException(
            status_code=400, detail="Not enough permissions to update this task"
        )
    
    # If updating assignee, verify the new assignee exists
    if task_in.assignee_id is not None:
        user = crud.user.get(db, id=task_in.assignee_id)
        if not user:
            raise HTTPException(
                status_code=404,
                detail="The assignee does not exist in the system",
            )
    
    task = crud.task.update(db, db_obj=task, obj_in=task_in)
    return task

@router.get("/{task_id}", response_model=schemas.TaskWithProject)
def read_task(
    *,
    db: Session = Depends(get_db),
    task_id: int,
    current_user: models.User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Get task by ID.
    """
    task = crud.task.get(db, id=task_id)
    if not task:
        raise HTTPException(
            status_code=404,
            detail="The task does not exist in the system",
        )
    
    # Get the project to check permissions
    project = crud.project.get(db, id=task.project_id)
    if not project:
        raise HTTPException(
            status_code=404,
            detail="The project for this task does not exist",
        )
    
    # Check if user is project owner, task assignee, or superuser
    is_owner = project.owner_id == current_user.id
    is_assignee = task.assignee_id == current_user.id
    
    if not (crud.user.is_superuser(current_user) or is_owner or is_assignee):
        raise HTTPException(
            status_code=400, detail="Not enough permissions to view this task"
        )
    
    return task

@router.delete("/{task_id}", response_model=schemas.Task)
def delete_task(
    *,
    db: Session = Depends(get_db),
    task_id: int,
    current_user: models.User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Delete a task.
    """
    task = crud.task.get(db, id=task_id)
    if not task:
        raise HTTPException(
            status_code=404,
            detail="The task does not exist in the system",
        )
    
    # Get the project to check permissions
    project = crud.project.get(db, id=task.project_id)
    if not project:
        raise HTTPException(
            status_code=404,
            detail="The project for this task does not exist",
        )
    
    # Only project owner or superuser can delete tasks
    if not (crud.user.is_superuser(current_user) or project.owner_id == current_user.id):
        raise HTTPException(
            status_code=400, detail="Not enough permissions to delete this task"
        )
    
    task = crud.task.remove(db=db, id=task_id)
    return task

@router.post("/{task_id}/status/{status}", response_model=schemas.Task)
def update_task_status(
    *,
    db: Session = Depends(get_db),
    task_id: int,
    status: TaskStatus,
    current_user: models.User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Update task status.
    """
    task = crud.task.get(db, id=task_id)
    if not task:
        raise HTTPException(
            status_code=404,
            detail="The task does not exist in the system",
        )
    
    # Get the project to check permissions
    project = crud.project.get(db, id=task.project_id)
    if not project:
        raise HTTPException(
            status_code=404,
            detail="The project for this task does not exist",
        )
    
    # Check if user is project owner, task assignee, or superuser
    is_owner = project.owner_id == current_user.id
    is_assignee = task.assignee_id == current_user.id
    
    if not (crud.user.is_superuser(current_user) or is_owner or is_assignee):
        raise HTTPException(
            status_code=400, detail="Not enough permissions to update this task"
        )
    
    task = crud.task.update_status(db, db_obj=task, status=status)
    return task

@router.post("/{task_id}/assign/{user_id}", response_model=schemas.Task)
def assign_task(
    *,
    db: Session = Depends(get_db),
    task_id: int,
    user_id: Optional[int] = None,
    current_user: models.User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Assign a task to a user.
    """
    task = crud.task.get(db, id=task_id)
    if not task:
        raise HTTPException(
            status_code=404,
            detail="The task does not exist in the system",
        )
    
    # Get the project to check permissions
    project = crud.project.get(db, id=task.project_id)
    if not project:
        raise HTTPException(
            status_code=404,
            detail="The project for this task does not exist",
        )
    
    # Only project owner or superuser can assign tasks
    if not (crud.user.is_superuser(current_user) or project.owner_id == current_user.id):
        raise HTTPException(
            status_code=400, detail="Not enough permissions to assign this task"
        )
    
    # If user_id is provided, verify the user exists
    if user_id is not None:
        user = crud.user.get(db, id=user_id)
        if not user:
            raise HTTPException(
                status_code=404,
                detail="The user does not exist in the system",
            )
    
    task = crud.task.update_assignee(db, db_obj=task, assignee_id=user_id)
    return task
