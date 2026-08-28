#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SERVER_DATA_PATH="${1:-$REPOSITORY_ROOT/runtime/qbox-server-data}"
ENV_FILE="${2:-$REPOSITORY_ROOT/.env}"
SERVER_CONFIG="$SERVER_DATA_PATH/server.cfg"

if [[ ! -f "$ENV_FILE" ]]; then
  printf 'Ignored environment file was not found: %s\n' "$ENV_FILE" >&2
  exit 1
fi
if [[ ! -f "$SERVER_CONFIG" ]]; then
  printf 'Runtime server.cfg was not found: %s\n' "$SERVER_CONFIG" >&2
  exit 1
fi

read_setting() {
  local key="$1"
  awk -v key="$key" '
    index($0, key "=") == 1 {
      value = substr($0, length(key) + 2)
      sub(/\r$/, "", value)
      print value
      found = 1
      exit
    }
    END { if (!found) exit 1 }
  ' "$ENV_FILE"
}

APP_ENV="$(read_setting APP_ENV)"
SERVER_NAME="$(read_setting SERVER_NAME)"
SERVER_DESCRIPTION="$(read_setting SERVER_DESCRIPTION)"
SERVER_TAGS="$(read_setting SERVER_TAGS)"

case "$APP_ENV" in
  development|staging|production) ;;
  *) printf 'APP_ENV must be development, staging, or production.\n' >&2; exit 1 ;;
esac

for value in "$SERVER_NAME" "$SERVER_DESCRIPTION" "$SERVER_TAGS"; do
  if [[ -z "$value" || "$value" == *'"'* ]]; then
    printf 'Runtime identity values must be non-empty and cannot contain double quotes.\n' >&2
    exit 1
  fi
done
if [[ ",$SERVER_TAGS," != *",$APP_ENV,"* && ",$SERVER_TAGS," != *", $APP_ENV,"* ]]; then
  printf 'SERVER_TAGS must contain APP_ENV (%s).\n' "$APP_ENV" >&2
  exit 1
fi
if [[ "$APP_ENV" != development && ",$SERVER_TAGS," == *development* ]]; then
  printf 'Non-development SERVER_TAGS cannot contain development.\n' >&2
  exit 1
fi

TEMP_CONFIG="$(mktemp "$SERVER_DATA_PATH/server.cfg.identity.XXXXXXXX")"
cleanup() {
  rm -f -- "$TEMP_CONFIG"
}
trap cleanup EXIT

awk \
  -v server_name="$SERVER_NAME" \
  -v server_description="$SERVER_DESCRIPTION" \
  -v server_tags="$SERVER_TAGS" \
  -v app_env="$APP_ENV" '
  /^[[:space:]]*sv_hostname[[:space:]]/ {
    print "sv_hostname \"" server_name "\""; hostname_count++; next
  }
  /^[[:space:]]*sets[[:space:]]+sv_projectName[[:space:]]/ {
    print "sets sv_projectName \"" server_name "\""; name_count++; next
  }
  /^[[:space:]]*sets[[:space:]]+sv_projectDesc[[:space:]]/ {
    print "sets sv_projectDesc \"" server_description "\""; description_count++; next
  }
  /^[[:space:]]*sets[[:space:]]+tags[[:space:]]/ {
    print "sets tags \"" server_tags "\""; tags_count++; next
  }
  /^[[:space:]]*setr[[:space:]]+tarrant_environment[[:space:]]/ { next }
  {
    print
    if ($0 ~ /^[[:space:]]*exec[[:space:]]+staff\.cfg[[:space:]]*$/) {
      print "setr tarrant_environment \"" app_env "\""
      environment_count++
    }
  }
  END {
    if (hostname_count != 1 || name_count != 1 || description_count != 1 || tags_count != 1 || environment_count != 1) {
      exit 42
    }
  }
  ' "$SERVER_CONFIG" > "$TEMP_CONFIG" || {
    printf 'Runtime server.cfg does not have the expected Phase 1 layout.\n' >&2
    exit 1
  }

mv -- "$TEMP_CONFIG" "$SERVER_CONFIG"
trap - EXIT
printf '[ok] Applied %s runtime identity to %s\n' "$APP_ENV" "$SERVER_CONFIG"
