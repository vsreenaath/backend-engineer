from typing import List, Optional

from sqlalchemy.orm import Session

from app.crud.base import CRUDBase
from app.models import Task, TaskStatus
from app.schemas.task import TaskCreate, TaskUpdate


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
        db_obj.status = status
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


task = CRUDTask(Task)
