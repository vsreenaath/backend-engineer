"""problem 2 models

Revision ID: 0003_problem2_models
Revises: 0002_seed_data
Create Date: 2025-09-07 09:50:00

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '0003_problem2_models'
down_revision = '0002_seed_data'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create orderstatus enum
    order_status = sa.Enum('PENDING', 'RESERVED', 'CONFIRMED', 'PAID', 'CANCELLED', 'FAILED', name='orderstatus')
    order_status.create(op.get_bind(), checkfirst=True)

    # Create products table
    op.create_table(
        'products',
        sa.Column('id', sa.Integer(), primary_key=True, nullable=False),
        sa.Column('sku', sa.String(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('price_cents', sa.Integer(), nullable=False),
        sa.Column('stock', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('NOW()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index('ix_products_sku', 'products', ['sku'], unique=True)
    op.create_index('ix_products_name', 'products', ['name'], unique=False)

    # Create orders table
    op.create_table(
        'orders',
        sa.Column('id', sa.Integer(), primary_key=True, nullable=False),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('status', order_status, nullable=False, server_default='PENDING'),
        sa.Column('total_cents', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('NOW()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
    )

    # Create order_items table
    op.create_table(
        'order_items',
        sa.Column('id', sa.Integer(), primary_key=True, nullable=False),
        sa.Column('order_id', sa.Integer(), sa.ForeignKey('orders.id', ondelete='CASCADE'), nullable=False),
        sa.Column('product_id', sa.Integer(), sa.ForeignKey('products.id'), nullable=False),
        sa.Column('quantity', sa.Integer(), nullable=False),
        sa.Column('unit_price_cents', sa.Integer(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table('order_items')
    op.drop_table('orders')
    op.drop_index('ix_products_name', table_name='products')
    op.drop_index('ix_products_sku', table_name='products')
    op.drop_table('products')
    order_status = sa.Enum('PENDING', 'RESERVED', 'CONFIRMED', 'PAID', 'CANCELLED', 'FAILED', name='orderstatus')
    order_status.drop(op.get_bind(), checkfirst=True)
