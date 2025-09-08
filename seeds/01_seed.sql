-- Backend Engineer DB Init Hook
--
-- Note: Application data seeding is handled by Alembic migrations,
-- specifically `alembic/versions/0002_seed_data.py`.
-- This SQL file exists only to satisfy Postgres' docker-entrypoint init hook
-- and is intentionally a no-op, so first-run initialization does not fail.

-- Ensure session is valid and return a trivial result
SELECT 1;
