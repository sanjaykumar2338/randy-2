#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="${1:-$ROOT_DIR/config/fxserver-linux-artifact.json}"
DESTINATION_PATH="${2:-}"

for command_name in python3 curl sha256sum tar mktemp; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Required command is unavailable: %s\n' "$command_name" >&2
    exit 1
  }
done

[ -f "$MANIFEST_PATH" ] || { printf 'Artifact manifest is missing.\n' >&2; exit 1; }

read_manifest_value() {
  python3 - "$MANIFEST_PATH" "$1" <<'PY'
import json, pathlib, sys
document = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
value = document[sys.argv[2]]
if not isinstance(value, (str, int)):
    raise SystemExit("manifest value has an invalid type")
print(value)
PY
}

BUILD="$(read_manifest_value build)"
ARCHIVE_NAME="$(read_manifest_value archiveName)"
OFFICIAL_SOURCE="$(read_manifest_value officialSource)"
EXPECTED_SHA256="$(read_manifest_value archiveSha256)"
LAUNCHER="$(read_manifest_value launcher)"
EXECUTABLE="$(read_manifest_value executable)"

[[ "$BUILD" =~ ^[0-9]+$ ]]
[[ "$EXPECTED_SHA256" =~ ^[A-Fa-f0-9]{64}$ ]]
[[ "$OFFICIAL_SOURCE" == "https://downloads.cfx-services.net/prod/"*"/cfx-server_linux_x64.tar.xz" ]]
[[ "$LAUNCHER" == "run.sh" ]]
[[ "$EXECUTABLE" == "alpine/opt/cfx-server/cfx-server" ]]

if [ -z "$DESTINATION_PATH" ]; then
  DESTINATION_PATH="$ROOT_DIR/server-binaries/enhanced-linux-$BUILD"
fi
case "$DESTINATION_PATH" in
  /*) ;;
  *) DESTINATION_PATH="$ROOT_DIR/$DESTINATION_PATH" ;;
esac

DESTINATION_PARENT="$(dirname "$DESTINATION_PATH")"
mkdir -p "$DESTINATION_PARENT" "$ROOT_DIR/runtime"
DESTINATION_PARENT="$(cd "$DESTINATION_PARENT" && pwd -P)"
DESTINATION_PATH="$DESTINATION_PARENT/$(basename "$DESTINATION_PATH")"

case "$DESTINATION_PATH" in
  "$ROOT_DIR/server-binaries/"*) ;;
  *) printf 'Destination must remain under %s/server-binaries/.\n' "$ROOT_DIR" >&2; exit 1 ;;
esac
[ ! -e "$DESTINATION_PATH" ] || {
  printf 'Destination already exists; refusing to overwrite rollback-capable binaries: %s\n' "$DESTINATION_PATH" >&2
  exit 1
}

WORK_ROOT="$(mktemp -d "$ROOT_DIR/runtime/fxserver-linux-install.XXXXXXXX")"
trap 'rm -rf -- "$WORK_ROOT"' EXIT
ARCHIVE_PATH="$WORK_ROOT/$ARCHIVE_NAME"
STAGE_PATH="$WORK_ROOT/stage"
mkdir "$STAGE_PATH"

curl --fail --location --silent --show-error --output "$ARCHIVE_PATH" "$OFFICIAL_SOURCE"
ACTUAL_SHA256="$(sha256sum "$ARCHIVE_PATH" | awk '{print toupper($1)}')"
[ "$ACTUAL_SHA256" = "${EXPECTED_SHA256^^}" ] || {
  printf 'Official Linux artifact checksum mismatch.\n' >&2
  exit 1
}

ARCHIVE_LIST="$WORK_ROOT/archive.list"
tar -tJf "$ARCHIVE_PATH" | sed 's#^\./##' > "$ARCHIVE_LIST"
if grep -Eq '(^/|(^|/)\.\.(/|$))' "$ARCHIVE_LIST"; then
  printf 'Artifact archive contains an unsafe path.\n' >&2
  exit 1
fi
grep -Fxq "$LAUNCHER" "$ARCHIVE_LIST"
grep -Fxq "$EXECUTABLE" "$ARCHIVE_LIST"
tar -xJf "$ARCHIVE_PATH" -C "$STAGE_PATH"
[ -f "$STAGE_PATH/$LAUNCHER" ]
[ -f "$STAGE_PATH/$EXECUTABLE" ]
chmod 755 "$STAGE_PATH/$LAUNCHER" "$STAGE_PATH/$EXECUTABLE"

printf '%s\n' \
  "build=$BUILD" \
  "channel=enhanced" \
  "source=$OFFICIAL_SOURCE" \
  "sha256=${EXPECTED_SHA256^^}" > "$STAGE_PATH/INSTALL-MANIFEST.txt"

mv -- "$STAGE_PATH" "$DESTINATION_PATH"
printf '[ok] Installed verified Linux FXServer build %s side-by-side at %s\n' "$BUILD" "$DESTINATION_PATH"
printf '[ok] Existing binaries, runtime, txData, resources, database, and private configuration were not modified.\n'
