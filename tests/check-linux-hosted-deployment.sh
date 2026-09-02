#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

# shellcheck source=../scripts/dotenv-utils.sh
. "$ROOT_DIR/scripts/dotenv-utils.sh"

ENV_FIXTURE="$TMP_DIR/test.env"
printf '%s\n' 'SERVER_NAME=Tarrant County RP - Staging' 'DB_PASSWORD=not-a-real-secret' > "$ENV_FIXTURE"
[ "$(dotenv_get "$ENV_FIXTURE" SERVER_NAME)" = 'Tarrant County RP - Staging' ]
[ "$(dotenv_get "$ENV_FIXTURE" DB_PASSWORD)" = 'not-a-real-secret' ]

PROJECT_FIXTURE="$TMP_DIR/project"
mkdir -p "$PROJECT_FIXTURE/server-binaries/enhanced-129" "$PROJECT_FIXTURE/txData"
printf '#!/usr/bin/env bash\n' > "$PROJECT_FIXTURE/server-binaries/enhanced-129/run.sh"
chmod +x "$PROJECT_FIXTURE/server-binaries/enhanced-129/run.sh"
PROJECT_ROOT="$PROJECT_FIXTURE" SERVICE_USER=fivem TXADMIN_PORT=40120 \
  bash "$ROOT_DIR/scripts/render-txadmin-systemd.sh" "$TMP_DIR/txadmin.service" >/dev/null

grep -Fxq 'Environment=TXHOST_TXA_PORT=40120' "$TMP_DIR/txadmin.service"
grep -Fxq "Environment=TXHOST_DATA_PATH=$PROJECT_FIXTURE/txData" "$TMP_DIR/txadmin.service"
grep -Fxq "ExecStart=$PROJECT_FIXTURE/server-binaries/enhanced-129/run.sh" "$TMP_DIR/txadmin.service"
if grep -Eq '(^|[[:space:]])\+set[[:space:]]+(txAdminPort|txDataPath|serverProfile)([[:space:]]|$)' "$TMP_DIR/txadmin.service"; then
  printf 'Deprecated txAdmin ConVar found in generated service\n' >&2
  exit 1
fi

grep -Fq 'QBOX_RESOURCES_DIR' "$ROOT_DIR/scripts/check-qbox-readiness.sh"
if grep -Fq '. "$ENV_FILE"' "$ROOT_DIR/scripts/check-qbox-readiness.sh"; then
  printf 'Readiness script still executes .env\n' >&2
  exit 1
fi

printf 'Linux hosted deployment checks: PASS\n'
