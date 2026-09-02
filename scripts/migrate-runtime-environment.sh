#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVIRONMENT="${1:-}"
SERVER_DATA_PATH="${2:-$ROOT_DIR/runtime/qbox-server-data}"

case "$ENVIRONMENT" in
  development|staging|production) ;;
  *) printf 'Usage: %s development|staging|production [server-data-path]\n' "$0" >&2; exit 2 ;;
esac

SERVER_DATA_PATH="$(cd "$SERVER_DATA_PATH" && pwd -P)"
SERVER_CONFIG="$SERVER_DATA_PATH/server.cfg"
BASE_CONFIG="$SERVER_DATA_PATH/base.cfg"
LEGACY_PRIVATE_CONFIG="$SERVER_DATA_PATH/development.cfg"
PRIVATE_CONFIG_NAME="$ENVIRONMENT.private.cfg"
PRIVATE_CONFIG="$SERVER_DATA_PATH/$PRIVATE_CONFIG_NAME"

for required in "$SERVER_CONFIG" "$BASE_CONFIG"; do
  [ -f "$required" ] || { printf 'Required runtime config is missing: %s\n' "$required" >&2; exit 1; }
done

if [ ! -f "$PRIVATE_CONFIG" ]; then
  [ -f "$LEGACY_PRIVATE_CONFIG" ] || {
    printf 'Neither the target private config nor the legacy private config exists.\n' >&2
    exit 1
  }
  umask 077
  PRIVATE_TEMP="$(mktemp "$SERVER_DATA_PATH/.${PRIVATE_CONFIG_NAME}.XXXXXXXX")"
  awk '
    /^[[:space:]]*set[[:space:]]+mysql_connection_string[[:space:]]+/ { print; mysql++; next }
    /^[[:space:]]*sv_licenseKey[[:space:]]+/ { print; license++; next }
    END { if (mysql != 1 || license != 1) exit 3 }
  ' "$LEGACY_PRIVATE_CONFIG" > "$PRIVATE_TEMP" || {
    rm -f -- "$PRIVATE_TEMP"
    printf 'Legacy private config must contain exactly one database directive and one license directive.\n' >&2
    exit 1
  }
  mv -- "$PRIVATE_TEMP" "$PRIVATE_CONFIG"
  chmod 600 "$PRIVATE_CONFIG"
fi

grep -Eq '^[[:space:]]*set[[:space:]]+mysql_connection_string[[:space:]]+' "$PRIVATE_CONFIG" || {
  printf 'Target private config has no database directive.\n' >&2; exit 1;
}
grep -Eq '^[[:space:]]*sv_licenseKey[[:space:]]+' "$PRIVATE_CONFIG" || {
  printf 'Target private config has no license directive.\n' >&2; exit 1;
}
if grep -Eq '^[[:space:]]*setr[[:space:]]+tarrant_environment[[:space:]]+' "$PRIVATE_CONFIG"; then
  printf 'Target private config contains an environment marker.\n' >&2
  exit 1
fi

BASE_TEMP="$(mktemp "$SERVER_DATA_PATH/.base.cfg.XXXXXXXX")"
awk '!/^[[:space:]]*setr[[:space:]]+tarrant_environment[[:space:]]+/' "$BASE_CONFIG" > "$BASE_TEMP"
chmod --reference="$BASE_CONFIG" "$BASE_TEMP"
mv -- "$BASE_TEMP" "$BASE_CONFIG"

SERVER_TEMP="$(mktemp "$SERVER_DATA_PATH/.server.cfg.XXXXXXXX")"
awk -v private_config="$PRIVATE_CONFIG_NAME" -v environment="$ENVIRONMENT" '
  /^[[:space:]]*exec[[:space:]]+(development\.cfg|development\.private\.cfg|staging\.private\.cfg|production\.private\.cfg)[[:space:]]*$/ {
    if (!private_written++) print "exec " private_config
    next
  }
  /^[[:space:]]*setr[[:space:]]+tarrant_environment[[:space:]]+/ { next }
  { print }
  /^[[:space:]]*exec[[:space:]]+staff\.cfg[[:space:]]*$/ {
    print "setr tarrant_environment \"" environment "\""
    environment_written++
  }
  END { if (private_written != 1 || environment_written != 1) exit 4 }
' "$SERVER_CONFIG" > "$SERVER_TEMP" || {
  rm -f -- "$SERVER_TEMP"
  printf 'server.cfg does not have the expected private-config/include layout.\n' >&2
  exit 1
}
chmod --reference="$SERVER_CONFIG" "$SERVER_TEMP"
mv -- "$SERVER_TEMP" "$SERVER_CONFIG"

grep -Eq "^[[:space:]]*exec[[:space:]]+$PRIVATE_CONFIG_NAME[[:space:]]*$" "$SERVER_CONFIG"
! grep -Eq '^[[:space:]]*exec[[:space:]]+development\.cfg[[:space:]]*$' "$SERVER_CONFIG"
! grep -Eq '^[[:space:]]*setr[[:space:]]+tarrant_environment[[:space:]]+"development"' "$BASE_CONFIG"

printf '[ok] Runtime now loads %s and applies tarrant_environment %s.\n' "$PRIVATE_CONFIG_NAME" "$ENVIRONMENT"
printf '[ok] Credential values were preserved without being displayed; the legacy file was retained but is no longer loaded.\n'
