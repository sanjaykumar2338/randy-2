#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/public-listing-validation.sh
. "$ROOT_DIR/scripts/public-listing-validation.sh"

has_active_empty_sv_master1 'sv_master1 ""'
has_active_empty_sv_master1 "sv_master1 '' # disabled"
! has_active_empty_sv_master1 '# sv_master1 ""'
! has_active_empty_sv_master1 '; sv_master1 ""'
! has_active_empty_sv_master1 'sv_master1 "https://servers-ingress-live.fivem.net/ingress"'

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
printf '%s\n' 'exec security.cfg' > "$TEST_ROOT/server.cfg"
printf '%s\n' '# sv_master1 ""' > "$TEST_ROOT/security.cfg"
PUBLIC_LISTING_VISITED=""
! loaded_config_disables_public_listing "$TEST_ROOT/server.cfg" "$TEST_ROOT"
printf '%s\n' 'sv_master1 ""' > "$TEST_ROOT/security.cfg"
PUBLIC_LISTING_VISITED=""
loaded_config_disables_public_listing "$TEST_ROOT/server.cfg" "$TEST_ROOT"

printf '[ok] Linux FiveM public-listing configuration regression tests passed.\n'
