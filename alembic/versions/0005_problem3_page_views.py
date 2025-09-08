"""problem 3 page_views table

Revision ID: 0005_problem3_page_views
Revises: 0004_fix_p2_schema_safe
Create Date: 2025-09-07 18:58:00

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '0005_problem3_page_views'
down_revision = '0004_fix_p2_schema_safe'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'page_views',
        sa.Column('id', sa.Integer(), primary_key=True, nullable=False),
        sa.Column('path', sa.String(length=255), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=True),
        sa.Column('country', sa.String(length=2), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('NOW()'), nullable=False),
    )
    op.create_index('ix_page_views_path', 'page_views', ['path'], unique=False)
    op.create_index('ix_page_views_created_at', 'page_views', ['created_at'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_page_views_created_at', table_name='page_views')
    op.drop_index('ix_page_views_path', table_name='page_views')
    op.drop_table('page_views')
