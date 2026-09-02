#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-/opt/randy-2}"
SERVICE_USER="${SERVICE_USER:-}"
TXADMIN_PORT="${TXADMIN_PORT:-40120}"
OUTPUT="${1:-}"

[ -n "$OUTPUT" ] || { printf 'Usage: %s OUTPUT_PATH\n' "$0" >&2; exit 2; }
case "$PROJECT_ROOT" in /*) ;; *) printf 'PROJECT_ROOT must be absolute\n' >&2; exit 2 ;; esac
case "$PROJECT_ROOT" in *[[:space:]]*) printf 'PROJECT_ROOT must not contain whitespace\n' >&2; exit 2 ;; esac
[[ "$TXADMIN_PORT" =~ ^[0-9]+$ ]] && [ "$TXADMIN_PORT" -ge 1 ] && [ "$TXADMIN_PORT" -le 65535 ] \
  || { printf 'TXADMIN_PORT must be between 1 and 65535\n' >&2; exit 2; }

if [ -z "$SERVICE_USER" ]; then
  SERVICE_USER="$(stat -c '%U' "$PROJECT_ROOT")"
fi
[[ "$SERVICE_USER" =~ ^[A-Za-z_][A-Za-z0-9_-]*[$]?$ ]] \
  || { printf 'SERVICE_USER is invalid\n' >&2; exit 2; }

LAUNCHER="$PROJECT_ROOT/server-binaries/enhanced-129/run.sh"
DATA_PATH="$PROJECT_ROOT/txData"
[ -x "$LAUNCHER" ] || { printf 'Enhanced launcher is not executable: %s\n' "$LAUNCHER" >&2; exit 1; }
[ -d "$DATA_PATH" ] || { printf 'txData directory not found: %s\n' "$DATA_PATH" >&2; exit 1; }

umask 022
{
  printf '%s\n' '[Unit]'
  printf '%s\n' 'Description=Tarrant County RP txAdmin / FXServer'
  printf '%s\n' 'Wants=network-online.target'
  printf '%s\n' 'After=network-online.target'
  printf '\n%s\n' '[Service]'
  printf '%s\n' 'Type=simple'
  printf 'User=%s\n' "$SERVICE_USER"
  printf 'WorkingDirectory=%s\n' "$PROJECT_ROOT"
  printf 'Environment=TXHOST_TXA_PORT=%s\n' "$TXADMIN_PORT"
  printf 'Environment=TXHOST_DATA_PATH=%s\n' "$DATA_PATH"
  printf 'ExecStart=%s\n' "$LAUNCHER"
  printf '%s\n' 'Restart=on-failure' 'RestartSec=5' 'TimeoutStopSec=60' 'LimitNOFILE=65535'
  printf '\n%s\n' '[Install]'
  printf '%s\n' 'WantedBy=multi-user.target'
} > "$OUTPUT"

printf 'Rendered txAdmin unit: %s\n' "$OUTPUT"
