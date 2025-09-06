-- Initial seed data for first-time database initialization
-- This runs only when the Postgres data directory is empty

-- Users
INSERT INTO users (id, email, hashed_password, full_name, is_active, is_superuser)
VALUES 
    (1, 'admin@example.com', 'admin', 'Administrator', true, true),
    (2, 'user@example.com', 'user', 'Regular User', true, false)
ON CONFLICT (id) DO NOTHING;

-- Projects
INSERT INTO projects (id, title, description, owner_id)
VALUES
    (1, 'Internal Tools', 'Project for internal productivity tools', 1),
    (2, 'Website Redesign', 'Refresh public website UX and performance', 1)
ON CONFLICT (id) DO NOTHING;

-- Tasks
-- Note: Enum values must match app.models.task.TaskStatus values
INSERT INTO tasks (id, title, description, status, project_id, assignee_id)
VALUES
    (1, 'Design database schema', 'Model entities for tasks and projects', 'ToDo', 1, 1),
    (2, 'Set up CI/CD', 'Automate build, test, and deploy', 'InProgress', 1, 1),
    (3, 'Implement landing page', 'Hero, features, and CTA sections', 'ToDo', 2, 2)
ON CONFLICT (id) DO NOTHING;
