-- Example-only MariaDB/MySQL initialization for local development.
-- Replace CHANGE_ME_STRONG_LOCAL_PASSWORD before running manually.
-- Prefer scripts/setup-dev-db.sh on this workstation so secrets stay in .env.

CREATE DATABASE IF NOT EXISTS `tarrant_rp_dev`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'tarrant_rp'@'localhost'
  IDENTIFIED BY 'CHANGE_ME_STRONG_LOCAL_PASSWORD';

CREATE USER IF NOT EXISTS 'tarrant_rp'@'127.0.0.1'
  IDENTIFIED BY 'CHANGE_ME_STRONG_LOCAL_PASSWORD';

GRANT ALL PRIVILEGES ON `tarrant_rp_dev`.* TO 'tarrant_rp'@'localhost';
GRANT ALL PRIVILEGES ON `tarrant_rp_dev`.* TO 'tarrant_rp'@'127.0.0.1';

FLUSH PRIVILEGES;
