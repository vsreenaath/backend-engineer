"""expand tasks.status check constraint

Revision ID: 0006_tasks_status_check_expand
Revises: 0005_problem3_page_views
Create Date: 2025-09-08 18:15:00

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '0006_tasks_status_check_expand'
down_revision = '0005_problem3_page_views'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Expand allowed values to include both enum values and names
    with op.batch_alter_table('tasks') as batch_op:
        batch_op.drop_constraint('ck_tasks_status', type_='check')
        batch_op.create_check_constraint(
            'ck_tasks_status',
            "status IN ('ToDo','InProgress','Done','TODO','IN_PROGRESS','DONE')"
        )


def downgrade() -> None:
    # Revert to only enum values
    with op.batch_alter_table('tasks') as batch_op:
        batch_op.drop_constraint('ck_tasks_status', type_='check')
        batch_op.create_check_constraint(
            'ck_tasks_status',
            "status IN ('ToDo','InProgress','Done')"
        )
