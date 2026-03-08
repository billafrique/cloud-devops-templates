-- ─────────────────────────────────────────────────────────────────
-- 01-init.sql
-- Runs ONCE automatically on first MySQL container boot
-- Creates the application database and grants access to app user
-- The app user credentials come from /opt/infra/.env at runtime
-- Flyway handles all table creation and migrations after this
-- ─────────────────────────────────────────────────────────────────

-- Create the database
CREATE DATABASE IF NOT EXISTS billafrique_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Grant the app user full access to billafrique_db
-- MYSQL_USER is created automatically by the MySQL Docker image
-- using the value from MYSQL_USER in /opt/infra/.env
GRANT ALL PRIVILEGES ON billafrique_db.* TO 'billafrique_user'@'%';

FLUSH PRIVILEGES;
