from typing import List, Optional

from sqlalchemy.orm import Session

from app.crud.base import CRUDBase
from app.models import Project, User
from app.schemas.project import ProjectCreate, ProjectUpdate


class CRUDProject(CRUDBase[Project, ProjectCreate, ProjectUpdate]):
    def get_multi_by_owner(
        self, db: Session, *, owner_id: int, skip: int = 0, limit: int = 100
    ) -> List[Project]:
        return (
            db.query(self.model)
            .filter(Project.owner_id == owner_id)
            .offset(skip)
            .limit(limit)
            .all()
        )

    def create_with_owner(
        self, db: Session, *, obj_in: ProjectCreate, owner_id: int
    ) -> Project:
        obj_in_data = obj_in.dict()
        db_obj = self.model(**obj_in_data, owner_id=owner_id)
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    def get_multi_by_collaborator(
        self, db: Session, *, user_id: int, skip: int = 0, limit: int = 100
    ) -> List[Project]:
        return (
            db.query(Project)
            .join(Project.tasks)
            .filter(Project.owner_id == user_id)
            .offset(skip)
            .limit(limit)
            .all()
        )


project = CRUDProject(Project)
