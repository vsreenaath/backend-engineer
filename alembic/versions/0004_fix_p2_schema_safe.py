"""fix p2 schema safely if stamping skipped creation

Revision ID: 0004_fix_p2_schema_safe
Revises: 0003_problem2_models
Create Date: 2025-09-07 10:02:00

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '0004_fix_p2_schema_safe'
down_revision = '0003_problem2_models'
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()

    # Create enum type if missing
    conn.execute(
        sa.text(
            """
            DO $$ BEGIN
              IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'orderstatus') THEN
                CREATE TYPE orderstatus AS ENUM ('PENDING','RESERVED','CONFIRMED','PAID','CANCELLED','FAILED');
              END IF;
            END $$;
            """
        )
    )

    # Create products table if not exists
    conn.execute(
        sa.text(
            """
            CREATE TABLE IF NOT EXISTS products (
              id SERIAL PRIMARY KEY,
              sku VARCHAR NOT NULL UNIQUE,
              name VARCHAR NOT NULL,
              description TEXT NULL,
              price_cents INTEGER NOT NULL,
              stock INTEGER NOT NULL DEFAULT 0,
              created_at TIMESTAMPTZ DEFAULT NOW(),
              updated_at TIMESTAMPTZ NULL
            );
            """
        )
    )
    conn.execute(sa.text("CREATE INDEX IF NOT EXISTS ix_products_name ON products(name);"))

    # Create orders table if not exists
    conn.execute(
        sa.text(
            """
            CREATE TABLE IF NOT EXISTS orders (
              id SERIAL PRIMARY KEY,
              user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              status orderstatus NOT NULL DEFAULT 'PENDING',
              total_cents INTEGER NOT NULL DEFAULT 0,
              created_at TIMESTAMPTZ DEFAULT NOW(),
              updated_at TIMESTAMPTZ NULL
            );
            """
        )
    )

    # Create order_items table if not exists
    conn.execute(
        sa.text(
            """
            CREATE TABLE IF NOT EXISTS order_items (
              id SERIAL PRIMARY KEY,
              order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
              product_id INTEGER NOT NULL REFERENCES products(id),
              quantity INTEGER NOT NULL,
              unit_price_cents INTEGER NOT NULL
            );
            """
        )
    )


def downgrade() -> None:
    # Non-destructive downgrade; do nothing
    pass
