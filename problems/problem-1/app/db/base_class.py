# this is the base class that all SQLAlchemy models will inherit from
from typing import Any

from sqlalchemy.ext.declarative import as_declarable, declared_attr

@as_declarative()
class Base:
    id: Any
    __name__: str
    
    # Generate __tablename__ automatically
    @declared_attr
    def __tablename__(cls) -> str:
        return cls.__name__.lower()
