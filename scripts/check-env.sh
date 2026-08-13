#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

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

status_ok() {
  printf '[ok] %s\n' "$1"
}

status_warn() {
  printf '[warn] %s\n' "$1"
}

status_fail() {
  printf '[fail] %s\n' "$1" >&2
  exit 1
}

cd "$ROOT_DIR"

status_ok "Repository root: $ROOT_DIR"
status_ok "OS: $(uname -s) $(uname -m)"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  && status_ok "Git repository detected" \
  || status_fail "Not inside a Git repository"

command -v git >/dev/null 2>&1 \
  && status_ok "Git: $(git --version)" \
  || status_fail "Git is not installed"

if command -v node >/dev/null 2>&1; then
  status_ok "Node.js: $(node --version)"
else
  status_warn "Node.js not found; Qbox/asset tooling may need it later"
fi

if command -v npm >/dev/null 2>&1; then
  status_ok "npm: $(npm --version)"
else
  status_warn "npm not found"
fi

if command -v docker >/dev/null 2>&1; then
  status_ok "Docker: $(docker --version)"
else
  status_warn "Docker not found"
fi

MYSQL="$(find_mysql)" || status_fail "MariaDB/MySQL client not found"
status_ok "MariaDB/MySQL client: $("$MYSQL" --version)"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a

  DB_HOST="${DB_HOST:-127.0.0.1}"
  DB_PORT="${DB_PORT:-3306}"
  DB_NAME="${DB_NAME:-tarrant_rp_dev}"
  DB_USER="${DB_USER:-tarrant_rp}"

  if [ "${DB_PASSWORD:-CHANGE_ME}" = "CHANGE_ME" ] || [ -z "${DB_PASSWORD:-}" ]; then
    status_fail ".env exists but DB_PASSWORD is not configured"
  fi

  MYSQL_PWD="$DB_PASSWORD" "$MYSQL" --protocol=tcp --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" "$DB_NAME" \
    --batch --skip-column-names --execute "SELECT DATABASE(), CURRENT_USER();" >/dev/null \
    && status_ok "Database connectivity verified for $DB_USER@$DB_HOST/$DB_NAME" \
    || status_fail "Database connectivity failed for configured application user"

  if MYSQL_PWD="$DB_PASSWORD" "$MYSQL" --protocol=tcp --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" \
    --batch --skip-column-names --execute "SHOW DATABASES LIKE 'test';" | grep -q '^test$'; then
    status_warn "The app user can see the default test schema, likely from MariaDB/XAMPP public test grants"
  fi
else
  status_warn ".env not found; run scripts/setup-dev-db.sh or copy .env.example"
fi

case "$(uname -s)" in
  Darwin)
    status_warn "FXServer does not have a native macOS server setup path in the Cfx.re docs; use Windows/Linux for server runtime"
    ;;
  Linux)
    if [ -n "${FXSERVER_RUN_SH:-}" ] && [ -x "$FXSERVER_RUN_SH" ]; then
      status_ok "FXServer run script configured: $FXSERVER_RUN_SH"
    else
      status_warn "FXServer artifacts not configured; set FXSERVER_RUN_SH after installing the latest recommended Linux artifact"
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    status_warn "On Windows, run FXServer.exe from the downloaded latest recommended artifact outside Git"
    ;;
  *)
    status_warn "Unknown OS for FXServer startup; use a supported Windows/Linux host"
    ;;
esac

status_ok "Environment check complete"
