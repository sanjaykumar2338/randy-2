#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
FXSERVER_RUN_SH=""
# shellcheck source=dotenv-utils.sh
. "$ROOT_DIR/scripts/dotenv-utils.sh"
# shellcheck source=fxserver-linux-artifact-validation.sh
. "$ROOT_DIR/scripts/fxserver-linux-artifact-validation.sh"

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
  DB_HOST="$(dotenv_default "$ENV_FILE" DB_HOST 127.0.0.1)"
  DB_PORT="$(dotenv_default "$ENV_FILE" DB_PORT 3306)"
  DB_NAME="$(dotenv_default "$ENV_FILE" DB_NAME tarrant_rp_dev)"
  DB_USER="$(dotenv_default "$ENV_FILE" DB_USER tarrant_rp)"
  DB_PASSWORD="$(dotenv_default "$ENV_FILE" DB_PASSWORD '')"
  FXSERVER_RUN_SH="$(project_path "$ROOT_DIR" "$(dotenv_default "$ENV_FILE" FXSERVER_RUN_SH '')")"

  if [ "${DB_PASSWORD:-CHANGE_ME}" = "CHANGE_ME" ] || [ -z "${DB_PASSWORD:-}" ]; then
    status_fail ".env exists but DB_PASSWORD is not configured"
  fi

  MYSQL_PWD="$DB_PASSWORD" "$MYSQL" --protocol=tcp --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" "$DB_NAME" \
    --batch --skip-column-names --execute "SELECT DATABASE(), CURRENT_USER();" >/dev/null \
    && status_ok "Database connectivity verified for $DB_USER@$DB_HOST/$DB_NAME" \
    || status_fail "Database connectivity failed for configured application user"

  SERVER_VERSION="$(MYSQL_PWD="$DB_PASSWORD" "$MYSQL" --protocol=tcp --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" "$DB_NAME" \
    --batch --skip-column-names --execute "SELECT VERSION();" 2>/dev/null || true)"
  if [[ "$SERVER_VERSION" == *MariaDB* ]] && version_ge_10_9 "$SERVER_VERSION"; then
    status_ok "MariaDB version satisfies Qbox minimum: $SERVER_VERSION"
  else
    status_warn "Qbox requires MariaDB 10.9.0+; this server reports ${SERVER_VERSION:-unknown}"
  fi

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
    if ARTIFACT_RESULT="$(validate_pinned_fxserver_linux_artifact "$ROOT_DIR" "$FXSERVER_RUN_SH")"; then
      IFS='|' read -r ARTIFACT_BUILD ARTIFACT_LAUNCHER ARTIFACT_VERIFICATION <<EOF
$ARTIFACT_RESULT
EOF
      status_ok "Pinned Enhanced Linux build $ARTIFACT_BUILD validated ($ARTIFACT_VERIFICATION): $ARTIFACT_LAUNCHER"
    else
      status_warn "Pinned Enhanced Linux artifact validation failed"
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
