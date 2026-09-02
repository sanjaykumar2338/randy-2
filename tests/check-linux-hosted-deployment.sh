#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

# shellcheck source=../scripts/dotenv-utils.sh
. "$ROOT_DIR/scripts/dotenv-utils.sh"
# shellcheck source=../scripts/fxserver-linux-artifact-validation.sh
. "$ROOT_DIR/scripts/fxserver-linux-artifact-validation.sh"

ENV_FIXTURE="$TMP_DIR/test.env"
printf '%s\n' 'SERVER_NAME=Tarrant County RP - Staging' 'DB_PASSWORD=not-a-real-secret' > "$ENV_FIXTURE"
[ "$(dotenv_get "$ENV_FIXTURE" SERVER_NAME)" = 'Tarrant County RP - Staging' ]
[ "$(dotenv_get "$ENV_FIXTURE" DB_PASSWORD)" = 'not-a-real-secret' ]

PROJECT_FIXTURE="$TMP_DIR/project"
mkdir -p "$PROJECT_FIXTURE/config" "$PROJECT_FIXTURE/server-binaries/enhanced-linux-139/alpine/opt/cfx-server" "$PROJECT_FIXTURE/txData"
cp "$ROOT_DIR/config/fxserver-linux-artifact.json" "$PROJECT_FIXTURE/config/fxserver-linux-artifact.json"
printf '#!/usr/bin/env bash\n' > "$PROJECT_FIXTURE/server-binaries/enhanced-linux-139/run.sh"
printf '#!/usr/bin/env bash\n' > "$PROJECT_FIXTURE/server-binaries/enhanced-linux-139/alpine/opt/cfx-server/cfx-server"
printf '%s\n' 'build=139' 'channel=enhanced' > "$PROJECT_FIXTURE/server-binaries/enhanced-linux-139/INSTALL-MANIFEST.txt"
chmod +x "$PROJECT_FIXTURE/server-binaries/enhanced-linux-139/run.sh" "$PROJECT_FIXTURE/server-binaries/enhanced-linux-139/alpine/opt/cfx-server/cfx-server"
ln -s enhanced-linux-139 "$PROJECT_FIXTURE/server-binaries/enhanced-129"

if [ -L "$PROJECT_FIXTURE/server-binaries/enhanced-129" ]; then
  artifact_result="$(validate_pinned_fxserver_linux_artifact "$PROJECT_FIXTURE" "$PROJECT_FIXTURE/server-binaries/enhanced-129/run.sh")"
  [ "$artifact_result" = "139|$PROJECT_FIXTURE/server-binaries/enhanced-129/run.sh|verified" ]
else
  # Git Bash without Windows symlink privileges cannot reproduce a Unix link;
  # Linux/CI exercises the exact compatibility-link branch.
  rm -rf -- "$PROJECT_FIXTURE/server-binaries/enhanced-129"
  cp -R "$PROJECT_FIXTURE/server-binaries/enhanced-linux-139" "$PROJECT_FIXTURE/server-binaries/enhanced-129"
  artifact_result="$(validate_pinned_fxserver_linux_artifact "$PROJECT_FIXTURE" "$PROJECT_FIXTURE/server-binaries/enhanced-linux-139/run.sh")"
  [ "$artifact_result" = "139|$PROJECT_FIXTURE/server-binaries/enhanced-linux-139/run.sh|verified" ]
  printf 'Linux compatibility-symlink assertion skipped: host cannot create symbolic links\n'
fi

# A complete-looking arbitrary run.sh must not bypass the pinned-directory check.
mkdir -p "$PROJECT_FIXTURE/server-binaries/arbitrary/alpine/opt/cfx-server"
printf '#!/usr/bin/env bash\n' > "$PROJECT_FIXTURE/server-binaries/arbitrary/run.sh"
printf '#!/usr/bin/env bash\n' > "$PROJECT_FIXTURE/server-binaries/arbitrary/alpine/opt/cfx-server/cfx-server"
chmod +x "$PROJECT_FIXTURE/server-binaries/arbitrary/run.sh" "$PROJECT_FIXTURE/server-binaries/arbitrary/alpine/opt/cfx-server/cfx-server"
if validate_pinned_fxserver_linux_artifact "$PROJECT_FIXTURE" "$PROJECT_FIXTURE/server-binaries/arbitrary/run.sh" >/dev/null 2>&1; then
  printf 'Arbitrary Linux artifact unexpectedly passed validation\n' >&2
  exit 1
fi

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
grep -Fq 'validate_pinned_fxserver_linux_artifact' "$ROOT_DIR/scripts/check-qbox-readiness.sh"
grep -Fq 'validate_pinned_fxserver_linux_artifact' "$ROOT_DIR/scripts/check-env.sh"
if grep -Fq '. "$ENV_FILE"' "$ROOT_DIR/scripts/check-qbox-readiness.sh"; then
  printf 'Readiness script still executes .env\n' >&2
  exit 1
fi

printf 'Linux hosted deployment checks: PASS\n'
