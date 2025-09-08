"""Model imports to register tables on the shared Base metadata.

Including the Problem 1 `User` model ensures the `users` table is part of the
metadata used by Problem 2 models, satisfying ForeignKey('users.id') resolution
when SQLAlchemy sorts tables during flush/DDL operations.
"""

# Problem 1 models (users table)
from problems.problem_1.app.models.user import User  # noqa: F401

# Problem 2 models
from .product import Product  # noqa: F401
from .order import Order, OrderItem, OrderStatus  # noqa: F401
