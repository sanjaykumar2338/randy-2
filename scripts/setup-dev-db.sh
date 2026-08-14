#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
ENV_EXAMPLE="$ROOT_DIR/.env.example"

find_mysql() {
  if [ -n "${MYSQL_BIN:-}" ] && [ -x "$MYSQL_BIN" ]; then
    printf '%s\n' "$MYSQL_BIN"
  elif command -v mariadb >/dev/null 2>&1; then
    command -v mariadb
  elif command -v mysql >/dev/null 2>&1; then
    command -v mysql
  elif [ -x /Applications/XAMPP/xamppfiles/bin/mariadb ]; then
    printf '%s\n' /Applications/XAMPP/xamppfiles/bin/mariadb
  elif [ -x /Applications/XAMPP/xamppfiles/bin/mysql ]; then
    printf '%s\n' /Applications/XAMPP/xamppfiles/bin/mysql
  else
    return 1
  fi
}

require_name() {
  local label="$1"
  local value="$2"
  if [[ ! "$value" =~ ^[A-Za-z0-9_]+$ ]]; then
    printf 'Invalid %s "%s"; use only letters, numbers, and underscores.\n' "$label" "$value" >&2
    exit 1
  fi
}

version_ge_10_9() {
  local raw="$1"
  local core major minor patch
  core="${raw%%-*}"
  core="${core%%+*}"
  IFS=. read -r major minor patch <<EOF
$core
EOF
  major="${major:-0}"
  minor="${minor:-0}"
  patch="${patch:-0}"

  [[ "$major" =~ ^[0-9]+$ ]] || return 1
  [[ "$minor" =~ ^[0-9]+$ ]] || return 1
  [[ "$patch" =~ ^[0-9]+$ ]] || patch=0

  [ "$major" -gt 10 ] || { [ "$major" -eq 10 ] && [ "$minor" -ge 9 ]; }
}

update_env_var() {
  local key="$1"
  local value="$2"
  local tmp
  tmp="$(mktemp)"

  if [ -f "$ENV_FILE" ] && grep -q "^${key}=" "$ENV_FILE"; then
    awk -v key="$key" -v value="$value" '
      BEGIN { replaced = 0 }
      $0 ~ "^" key "=" { print key "=" value; replaced = 1; next }
      { print }
      END { if (!replaced) print key "=" value }
    ' "$ENV_FILE" > "$tmp"
  else
    [ -f "$ENV_FILE" ] && cp "$ENV_FILE" "$tmp"
    printf '%s=%s\n' "$key" "$value" >> "$tmp"
  fi

  mv "$tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

mysql_admin() {
  if [ -n "${MYSQL_ADMIN_PASSWORD:-}" ]; then
    MYSQL_PWD="$MYSQL_ADMIN_PASSWORD" "$MYSQL" --protocol=tcp --host="${MYSQL_ADMIN_HOST:-127.0.0.1}" --port="${MYSQL_ADMIN_PORT:-3306}" --user="${MYSQL_ADMIN_USER:-root}" "$@"
  else
    "$MYSQL" --protocol=tcp --host="${MYSQL_ADMIN_HOST:-127.0.0.1}" --port="${MYSQL_ADMIN_PORT:-3306}" --user="${MYSQL_ADMIN_USER:-root}" "$@"
  fi
}

MYSQL="$(find_mysql)" || {
  printf 'MariaDB/MySQL client not found. Install MariaDB/MySQL or set MYSQL_BIN.\n' >&2
  exit 1
}

if [ ! -f "$ENV_FILE" ]; then
  umask 077
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  printf 'Created local .env from .env.example.\n'
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-tarrant_rp_dev}"
DB_USER="${DB_USER:-tarrant_rp}"
DB_PASSWORD="${DB_PASSWORD:-CHANGE_ME}"

require_name "database name" "$DB_NAME"
require_name "database user" "$DB_USER"

if [ "$DB_PASSWORD" = "CHANGE_ME" ] || [ -z "$DB_PASSWORD" ]; then
  if command -v openssl >/dev/null 2>&1; then
    DB_PASSWORD="$(openssl rand -base64 36 | tr -d '\n')"
  elif [ -x /Applications/XAMPP/xamppfiles/bin/openssl ]; then
    DB_PASSWORD="$(/Applications/XAMPP/xamppfiles/bin/openssl rand -base64 36 | tr -d '\n')"
  else
    printf 'OpenSSL not found; set DB_PASSWORD manually in .env and re-run.\n' >&2
    exit 1
  fi
fi

if [[ "$DB_PASSWORD" == *"'"* ]]; then
  printf 'DB_PASSWORD contains a single quote, which this setup script will not embed in SQL. Use a different local password.\n' >&2
  exit 1
fi

update_env_var "DB_HOST" "$DB_HOST"
update_env_var "DB_PORT" "$DB_PORT"
update_env_var "DB_NAME" "$DB_NAME"
update_env_var "DB_USER" "$DB_USER"
update_env_var "DB_PASSWORD" "$DB_PASSWORD"

mysql_admin <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';

CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';

GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL

MYSQL_PWD="$DB_PASSWORD" "$MYSQL" --protocol=tcp --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" "$DB_NAME" \
  --batch --skip-column-names --execute "SELECT DATABASE(), CURRENT_USER();" >/dev/null

SERVER_VERSION="$(MYSQL_PWD="$DB_PASSWORD" "$MYSQL" --protocol=tcp --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" "$DB_NAME" \
  --batch --skip-column-names --execute "SELECT VERSION();" 2>/dev/null || true)"
if [[ "$SERVER_VERSION" != *MariaDB* ]] || ! version_ge_10_9 "$SERVER_VERSION"; then
  printf 'Warning: Qbox runtime requires MariaDB 10.9.0+; this server reports "%s".\n' "${SERVER_VERSION:-unknown}"
fi

PUBLIC_TEST_GRANTS="$(mysql_admin --batch --skip-column-names --execute "SELECT COUNT(*) FROM mysql.db WHERE User = '' AND Db IN ('test', 'test\\\\_%');" 2>/dev/null || true)"
if [ "${PUBLIC_TEST_GRANTS:-0}" != "0" ]; then
  printf 'Warning: this MariaDB server has default anonymous/public grants on the test schema. Remove them during local DB hardening if this host is shared.\n'
fi

printf 'Database ready: %s\n' "$DB_NAME"
printf 'Application user verified without root: %s@%s\n' "$DB_USER" "$DB_HOST"
printf 'Local credentials are stored in ignored file: .env\n'
