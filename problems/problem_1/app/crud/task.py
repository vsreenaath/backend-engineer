from typing import List, Optional, Any, Dict

from sqlalchemy.orm import Session

from app.crud.base import CRUDBase
from app.models import Task, TaskStatus
from app.schemas.task import TaskCreate, TaskUpdate
from fastapi.encoders import jsonable_encoder


class CRUDTask(CRUDBase[Task, TaskCreate, TaskUpdate]):
    def get_multi_by_owner(
        self, db: Session, *, owner_id: int, skip: int = 0, limit: int = 100
    ) -> List[Task]:
        return (
            db.query(self.model)
            .filter(Task.owner_id == owner_id)
            .offset(skip)
            .limit(limit)
            .all()
        )

    def get_multi_by_project(
        self, db: Session, *, project_id: int, skip: int = 0, limit: int = 100
    ) -> List[Task]:
        return (
            db.query(self.model)
            .filter(Task.project_id == project_id)
            .offset(skip)
            .limit(limit)
            .all()
        )

    def get_multi_by_assignee(
        self, db: Session, *, assignee_id: int, skip: int = 0, limit: int = 100
    ) -> List[Task]:
        return (
            db.query(self.model)
            .filter(Task.assignee_id == assignee_id)
            .offset(skip)
            .limit(limit)
            .all()
        )

    def update_status(
        self, db: Session, *, db_obj: Task, status: TaskStatus
    ) -> Task:
        # Persist enum value as canonical string
        db_obj.status = status.value if hasattr(status, 'value') else str(status)
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    def update_assignee(
        self, db: Session, *, db_obj: Task, assignee_id: Optional[int] = None
    ) -> Task:
        db_obj.assignee_id = assignee_id
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    def create(self, db: Session, *, obj_in: TaskCreate) -> Task:
        data: Dict[str, Any] = jsonable_encoder(obj_in)
        # Normalize status to match DB CHECK constraint
        mapping = {
            'TODO': 'ToDo',
            'IN_PROGRESS': 'InProgress',
            'DONE': 'Done',
            'ToDo': 'ToDo',
            'InProgress': 'InProgress',
            'Done': 'Done',
        }
        status_val = data.get('status')
        if hasattr(status_val, 'value'):
            data['status'] = status_val.value
        elif isinstance(status_val, str):
            data['status'] = mapping.get(status_val, status_val)
        db_obj = self.model(**data)
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj


task = CRUDTask(Task)
