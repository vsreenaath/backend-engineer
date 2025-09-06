"""seed data

Revision ID: 0002_seed_data
Revises: 0001_initial
Create Date: 2025-09-06 19:24:00

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '0002_seed_data'
down_revision = '0001_initial'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Seed a superuser and a regular user
    op.execute(
        sa.text(
            """
            INSERT INTO users (id, email, hashed_password, full_name, is_active, is_superuser)
            VALUES 
                (1, 'admin@example.com', 'admin', 'Administrator', true, true),
                (2, 'user@example.com', 'user', 'Regular User', true, false)
            ON CONFLICT (id) DO NOTHING;
            """
        )
    )

    # Seed projects
    op.execute(
        sa.text(
            """
            INSERT INTO projects (id, title, description, owner_id)
            VALUES 
                (1, 'Internal Tools', 'Project for internal productivity tools', 1),
                (2, 'Website Redesign', 'Refresh public website UX and performance', 1)
            ON CONFLICT (id) DO NOTHING;
            """
        )
    )

    # Seed tasks
    op.execute(
        sa.text(
            """
            INSERT INTO tasks (id, title, description, status, project_id, assignee_id)
            VALUES 
                (1, 'Design database schema', 'Model entities for tasks and projects', 'ToDo', 1, 1),
                (2, 'Set up CI/CD', 'Automate build, test, and deploy', 'InProgress', 1, 1),
                (3, 'Implement landing page', 'Hero, features, and CTA sections', 'ToDo', 2, 2)
            ON CONFLICT (id) DO NOTHING;
            """
        )
    )


def downgrade() -> None:
    op.execute(sa.text("DELETE FROM tasks WHERE id IN (1,2,3)"))
    op.execute(sa.text("DELETE FROM projects WHERE id IN (1,2)"))
    op.execute(sa.text("DELETE FROM users WHERE id IN (1,2)"))
