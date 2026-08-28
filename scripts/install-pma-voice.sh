#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SERVER_DATA_PATH="${1:-$REPOSITORY_ROOT/runtime/qbox-server-data}"
PMA_VOICE_VERSION='7.0.1'
PMA_VOICE_COMMIT='6c9d96ed7a02e30912f1a0ce92629bf9afbbca8c'
RESOURCE_ROOT="$SERVER_DATA_PATH/resources/[standalone]"
DESTINATION="$RESOURCE_ROOT/pma-voice"

if [[ ! -d "$SERVER_DATA_PATH/resources" ]]; then
  printf 'Server-data resources directory was not found: %s\n' "$SERVER_DATA_PATH" >&2
  exit 1
fi

if [[ -e "$DESTINATION" ]]; then
  printf 'Refusing to overwrite existing pma-voice resource: %s\n' "$DESTINATION" >&2
  exit 1
fi

for command_name in curl unzip; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Required command is unavailable: %s\n' "$command_name" >&2
    exit 1
  fi
done

mkdir -p "$RESOURCE_ROOT" "$REPOSITORY_ROOT/runtime"
WORK_ROOT="$(mktemp -d "$REPOSITORY_ROOT/runtime/pma-voice-install.XXXXXXXX")"
cleanup() {
  rm -rf -- "$WORK_ROOT"
}
trap cleanup EXIT

ARCHIVE="$WORK_ROOT/pma-voice.zip"
SOURCE_ROOT="$WORK_ROOT/source/pma-voice-$PMA_VOICE_COMMIT"
curl --fail --location --silent --show-error \
  --output "$ARCHIVE" \
  "https://github.com/AvarianKnight/pma-voice/archive/$PMA_VOICE_COMMIT.zip"
unzip -q "$ARCHIVE" -d "$WORK_ROOT/source"

if [[ ! -f "$SOURCE_ROOT/fxmanifest.lua" ]]; then
  printf 'Downloaded pma-voice archive has an unexpected resource layout.\n' >&2
  exit 1
fi
if ! grep -Eq "^version[[:space:]]+['\"]$PMA_VOICE_VERSION['\"]" "$SOURCE_ROOT/fxmanifest.lua"; then
  printf 'Downloaded pma-voice source does not declare version %s.\n' "$PMA_VOICE_VERSION" >&2
  exit 1
fi

mv -- "$SOURCE_ROOT" "$DESTINATION"
printf '%s\n' "$PMA_VOICE_COMMIT" > "$DESTINATION/.tarrant-source-commit"
printf '[ok] Installed pma-voice %s at %s\n' "$PMA_VOICE_VERSION" "$DESTINATION"
