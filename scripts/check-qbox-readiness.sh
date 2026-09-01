#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
FAILURES=0

# shellcheck source=public-listing-validation.sh
. "$ROOT_DIR/scripts/public-listing-validation.sh"

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

ok() {
  printf '[ok] %s\n' "$1"
}

warn() {
  printf '[warn] %s\n' "$1"
}

fail() {
  printf '[fail] %s\n' "$1"
  FAILURES=$((FAILURES + 1))
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

  if [ "$major" -gt 10 ]; then
    return 0
  fi

  if [ "$major" -eq 10 ] && [ "$minor" -ge 9 ]; then
    return 0
  fi

  return 1
}

cd "$ROOT_DIR"

ok "Repository root: $ROOT_DIR"

case "$(uname -s)" in
  Darwin)
    fail "FXServer is not supported natively on this macOS host; use Windows/Linux for Week 1 runtime testing"
    ;;
  Linux)
    if [ -n "${FXSERVER_RUN_SH:-}" ] && [ -x "$FXSERVER_RUN_SH" ]; then
      ok "FXServer Linux run script exists: $FXSERVER_RUN_SH"
    elif [ -x "$ROOT_DIR/../server/run.sh" ]; then
      ok "FXServer Linux run script exists: $ROOT_DIR/../server/run.sh"
    else
      fail "FXServer Linux artifact not found; set FXSERVER_RUN_SH after installing the latest recommended artifact"
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    if [ -n "${FXSERVER_EXE:-}" ] && [ -f "$FXSERVER_EXE" ]; then
      ok "FXServer Windows executable exists: $FXSERVER_EXE"
    elif [ -f "$ROOT_DIR/../server/FXServer.exe" ]; then
      ok "FXServer Windows executable exists: $ROOT_DIR/../server/FXServer.exe"
    else
      fail "FXServer.exe not found; set FXSERVER_EXE after installing the latest recommended artifact"
    fi
    ;;
  *)
    fail "Unknown/unsupported FXServer host OS: $(uname -s)"
    ;;
esac

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
  ok ".env exists locally"
else
  fail ".env is missing; copy .env.example or run scripts/setup-dev-db.sh"
fi

MYSQL="$(find_mysql)" || MYSQL=""
if [ -n "$MYSQL" ]; then
  ok "MariaDB client: $("$MYSQL" --version)"
else
  fail "MariaDB client not found"
fi

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-tarrant_rp_dev}"
DB_USER="${DB_USER:-tarrant_rp}"

if [ -z "${DB_PASSWORD:-}" ] || [ "${DB_PASSWORD:-CHANGE_ME}" = "CHANGE_ME" ]; then
  fail "DB_PASSWORD is not configured in .env"
elif [ -n "$MYSQL" ]; then
  SERVER_VERSION="$(MYSQL_PWD="$DB_PASSWORD" "$MYSQL" --protocol=tcp --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" "$DB_NAME" \
    --batch --skip-column-names --execute "SELECT VERSION();" 2>/dev/null || true)"

  if [ -z "$SERVER_VERSION" ]; then
    fail "Could not connect to $DB_NAME as $DB_USER without root"
  else
    ok "Database connection verified for $DB_USER@$DB_HOST/$DB_NAME"
    if [[ "$SERVER_VERSION" != *MariaDB* ]]; then
      fail "Qbox requires MariaDB; server reports: $SERVER_VERSION"
    elif version_ge_10_9 "$SERVER_VERSION"; then
      ok "MariaDB version satisfies Qbox minimum: $SERVER_VERSION"
    else
      fail "MariaDB version is below Qbox minimum 10.9.0: $SERVER_VERSION"
    fi
  fi
fi

if git check-ignore -q .env >/dev/null 2>&1; then
  ok ".env is ignored by Git"
else
  fail ".env is not ignored by Git"
fi

if [ -d "resources/[qbx]/qbx_core" ]; then
  ok "qbx_core resource found"
else
  fail "qbx_core not found; deploy the official Qbox txAdmin recipe"
fi

if [ -d "resources/[ox]/ox_inventory" ]; then
  ok "ox_inventory resource found"
else
  fail "ox_inventory not found; deploy the official Qbox txAdmin recipe"
fi

if [ -d "resources/[qbx]/qbx_spawn" ]; then
  ok "qbx_spawn resource found"
else
  fail "qbx_spawn not found; deploy the official Qbox txAdmin recipe"
fi

SERVER_CONFIG="${FXSERVER_CONFIG:-}"
if [ -z "$SERVER_CONFIG" ]; then
  if [ -f "server.cfg" ]; then SERVER_CONFIG="server.cfg"; else SERVER_CONFIG="config/server.cfg"; fi
fi

if [ -f "$SERVER_CONFIG" ]; then
  ok "Local FXServer config exists"
  case "${APP_ENV:-development}" in
    staging|production)
      PUBLIC_LISTING_VISITED=""
      if loaded_config_disables_public_listing "$SERVER_CONFIG" "$ROOT_DIR"; then
        fail 'Public staging/production config must not activate sv_master1 ""; it disables Cfx server-list advertising'
      else
        ok "Loaded public config does not disable Cfx server-list advertising"
      fi
      ;;
  esac
else
  warn "Local FXServer config not found yet; txAdmin recipe will generate server.cfg"
fi

if [ -n "${TXADMIN_URL:-}" ] && command -v curl >/dev/null 2>&1; then
  if curl --fail --silent --show-error --max-time 5 "$TXADMIN_URL" >/dev/null 2>&1; then
    ok "txAdmin responded at $TXADMIN_URL"
  else
    warn "txAdmin did not respond at $TXADMIN_URL"
  fi
else
  warn "txAdmin URL check skipped"
fi

if [ "$FAILURES" -gt 0 ]; then
  printf 'Qbox readiness: FAIL (%s issue(s))\n' "$FAILURES"
  exit 1
fi

printf 'Qbox readiness: PASS\n'
