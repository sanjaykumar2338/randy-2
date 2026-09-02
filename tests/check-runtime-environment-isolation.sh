#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

make_fixture() {
  local target="$1"
  mkdir -p "$target"
  printf '%s\n' \
    'exec development.cfg' \
    'exec voice.cfg' \
    'exec base.cfg' \
    'exec security.cfg' \
    'exec discord.cfg' \
    'exec permissions.cfg' \
    'exec staff.cfg' \
    'setr tarrant_environment "staging"' \
    'exec ox.cfg' > "$target/server.cfg"
  printf '%s\n' \
    'setr tarrant_environment "development"' \
    'set qb_locale "en"' > "$target/base.cfg"
  printf '%s\n' \
    'setr tarrant_environment "development"' \
    'set mysql_connection_string "fixture-private-value"' \
    'sv_licenseKey "fixture-private-value"' > "$target/development.cfg"
}

STAGING_ROOT="$TEST_ROOT/staging"
make_fixture "$STAGING_ROOT"
bash "$ROOT_DIR/scripts/migrate-runtime-environment.sh" staging "$STAGING_ROOT" >/dev/null

grep -Eq '^exec staging\.private\.cfg$' "$STAGING_ROOT/server.cfg"
! grep -Eq '^exec development\.cfg$' "$STAGING_ROOT/server.cfg"
grep -Eq '^setr tarrant_environment "staging"$' "$STAGING_ROOT/server.cfg"
! grep -R -E --include='*.cfg' '^setr[[:space:]]+tarrant_environment[[:space:]]+"development"' \
  "$STAGING_ROOT/server.cfg" "$STAGING_ROOT/base.cfg" "$STAGING_ROOT/staging.private.cfg"
! grep -R -E --include='*.cfg' "^[[:space:]]*sv_master1[[:space:]]+(\"\"|'')" "$STAGING_ROOT"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ;;
  *) test "$(stat -c '%a' "$STAGING_ROOT/staging.private.cfg")" = '600' ;;
esac

DEVELOPMENT_ROOT="$TEST_ROOT/development"
make_fixture "$DEVELOPMENT_ROOT"
bash "$ROOT_DIR/scripts/migrate-runtime-environment.sh" development "$DEVELOPMENT_ROOT" >/dev/null
grep -Eq '^exec development\.private\.cfg$' "$DEVELOPMENT_ROOT/server.cfg"
grep -Eq '^setr tarrant_environment "development"$' "$DEVELOPMENT_ROOT/server.cfg"

. "$ROOT_DIR/scripts/cfg-syntax-validation.sh"
while IFS= read -r cfg; do
  bad_lines="$(find_two_argument_directives_with_one_argument "$cfg")"
  [ -z "$bad_lines" ] || {
    printf 'Malformed two-argument directive in %s at line(s): %s\n' "$cfg" "$bad_lines" >&2
    exit 1
  }
done < <(find "$STAGING_ROOT" -type f -name '*.cfg' -print)

git -C "$ROOT_DIR" check-ignore -q runtime/example/staging.private.cfg
printf '[ok] Runtime environment-isolation regression tests passed.\n'
