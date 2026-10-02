# Linux Enhanced Artifact Upgrade

FiveM for GTAV Enhanced uses the separate Cfx Server download named
`cfx-server_linux_x64.tar.xz`. Do not substitute the legacy Linux master
artifact named `fx.tar.xz`.

On 2026-10-02 the official [Cfx Server Download page](https://docs.fivem.net/docs/server-download/)
offered Enhanced Linux build 161 at:

```text
https://downloads.cfx-services.net/prod/01a0f7ee-dfa5-7d23-a7a4-86de1b40d6f1/cfx-server_linux_x64.tar.xz
SHA-256 C7F407D1A9592B842FA764D121BD74D5AF6C75AEB973529D9FB4289BB1E4B359
```

The repository pins that URL and independently calculated checksum in
`config/fxserver-linux-artifact.json`. Enhanced b156 was previously accepted,
but FiveM now requires b161 for Enhanced client connections. Live b161
acceptance remains pending until this runbook is performed and the complete
operator checklist passes.

The b161 archive retains `run.sh`,
`alpine/opt/cfx-server/cfx-server`, and the bundled system resources in the same
layout as b156. The stable `server-binaries/enhanced-129` symlink strategy
therefore remains valid. The systemd unit continues to launch that stable path,
and txAdmin remains bundled; neither systemd, txAdmin configuration nor
`server.cfg` needs a change.

## Backup-first install and switch

Run these commands on the VPS as the repository owner from an approved
maintenance session. Replace `FULL_COMMIT_HASH` with the reviewed commit. They
make a private copy of b156 and capture the active link/unit/config before any
pull, preserve the original b156 directory, install b161 side-by-side, and verify
the archive-derived installation before changing the active symlink.

```bash
set -euo pipefail
REPO=/opt/randy-2
ACTIVE="$REPO/server-binaries/enhanced-129"
OLD="$REPO/server-binaries/enhanced-linux-156"
NEW="$REPO/server-binaries/enhanced-linux-161"
RELEASE=FULL_COMMIT_HASH
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP="$REPO/runtime/artifact-upgrade-backups/b156-to-b161-$STAMP"

test -d "$REPO/.git"
test -L "$ACTIVE"
test "$(readlink -f -- "$ACTIVE")" = "$(readlink -f -- "$OLD")"
test -x "$OLD/run.sh"
test -x "$OLD/alpine/opt/cfx-server/cfx-server"
test ! -e "$NEW"
test -z "$(git -C "$REPO" status --porcelain --untracked-files=no)"

umask 077
mkdir -p "$BACKUP"
cp -a --reflink=auto "$OLD" "$BACKUP/enhanced-linux-156"
readlink -- "$ACTIVE" > "$BACKUP/active-symlink-target.txt"
git -C "$REPO" rev-parse HEAD > "$BACKUP/repository-head.txt"
cp -a "$REPO/config/fxserver-linux-artifact.json" "$BACKUP/"
cp -a "$REPO/runtime/qbox-server-data/server.cfg" "$BACKUP/server.cfg"
sudo systemctl cat txadmin.service > "$BACKUP/txadmin.service.txt"
sha256sum "$OLD/alpine/opt/cfx-server/cfx-server" > "$BACKUP/b156-cfx-server.sha256"
printf 'Backup retained at %s\n' "$BACKUP"
umask 022

git -C "$REPO" fetch origin main
test "$(git -C "$REPO" rev-parse "$RELEASE^{commit}")" = "$RELEASE"
git -C "$REPO" merge-base --is-ancestor "$RELEASE" origin/main
git -C "$REPO" merge --ff-only "$RELEASE"
test "$(git -C "$REPO" rev-parse HEAD)" = "$RELEASE"

PROJECT_OWNER="$(stat -c '%U' "$REPO")"
sudo -u "$PROJECT_OWNER" bash "$REPO/scripts/install-fxserver-linux.sh"

test -x "$NEW/run.sh"
test -x "$NEW/alpine/opt/cfx-server/cfx-server"
test -f "$NEW/INSTALL-MANIFEST.txt"
grep -Fxq 'build=161' "$NEW/INSTALL-MANIFEST.txt"
grep -Fxq 'channel=enhanced' "$NEW/INSTALL-MANIFEST.txt"
grep -Fxq 'source=https://downloads.cfx-services.net/prod/01a0f7ee-dfa5-7d23-a7a4-86de1b40d6f1/cfx-server_linux_x64.tar.xz' "$NEW/INSTALL-MANIFEST.txt"
grep -Fxq 'sha256=C7F407D1A9592B842FA764D121BD74D5AF6C75AEB973529D9FB4289BB1E4B359' "$NEW/INSTALL-MANIFEST.txt"

. "$REPO/scripts/fxserver-linux-artifact-validation.sh"
ARTIFACT_RESULT="$(validate_pinned_fxserver_linux_artifact "$REPO" "$NEW/run.sh")"
test "$ARTIFACT_RESULT" = "161|$NEW/run.sh|verified"

CHAT="$NEW/alpine/opt/cfx-server/system_resources/chat"
(
  cd "$CHAT"
  printf '%s\n' \
    'e48050489116ef379ebbb9bc1f69522605217017287b66cef4b3c019c130c0f5  cl_chat.lua' \
    'f192cfff13e1098cafdef1a1d8aa417592dc4a13a6c4ce0c93f17b6e85e6dd21  dist/chat.js' |
    sha256sum --check --strict
)

test "$(readlink -f -- "$ACTIVE")" = "$(readlink -f -- "$OLD")"
sudo systemctl cat txadmin.service |
  grep -Fq 'ExecStart=/opt/randy-2/server-binaries/enhanced-129/run.sh'
! sudo systemctl cat txadmin.service |
  grep -Eq '\+set[[:space:]]+(txAdminPort|txDataPath|serverProfile)'

NEXT="$REPO/server-binaries/.enhanced-129.next"
test ! -e "$NEXT"
sudo systemctl stop txadmin.service
sudo ln -s -- "$(basename "$NEW")" "$NEXT"
sudo mv -Tf -- "$NEXT" "$ACTIVE"
printf '%s\n' "$OLD" > "$REPO/runtime/last-enhanced-rollback-path"
test "$(readlink -f -- "$ACTIVE")" = "$(readlink -f -- "$NEW")"
sudo systemctl start txadmin.service
sudo systemctl is-active --quiet txadmin.service
```

The installer downloads to a temporary directory, compares the complete archive
against the pinned SHA-256, rejects unsafe archive paths, verifies both required
executables after extraction, and only then moves the staged tree into
`enhanced-linux-161`. The explicit metadata, validator and stock-chat checks above
must all pass while b156 is still active. Do not bypass a failed check.

No `daemon-reload` or unit reinstall is required because the service continues
to use `enhanced-129/run.sh`. The procedure does not modify gameplay resources,
runtime server data, MariaDB or any cfg file.

## Live acceptance after the switch

Keep b156 and the backup until all checks pass. Record evidence for:

- txAdmin reports b161 and the service remains active;
- fresh logs show MariaDB/oxmysql connected and required resources started;
- `tarrant_medical` and `tarrant_chat` start without errors;
- an Enhanced client connects and loads the existing character;
- inventory and HUD work;
- T -> ESC dismisses chat immediately, and chat reopens normally;
- hospital recovery regression passes; and
- only then, Delivery acceptance resumes.

Useful read-only checks include:

```bash
sudo journalctl -u txadmin.service -n 200 --no-pager
curl --fail --silent --show-error http://127.0.0.1:30120/info.json
curl --fail --silent --show-error http://127.0.0.1:30120/players.json
curl --fail --silent --show-error http://127.0.0.1:40120/ >/dev/null
bash /opt/randy-2/scripts/check-env.sh
bash /opt/randy-2/scripts/check-qbox-readiness.sh
```

## Exact rollback to preserved b156

Rollback changes only the stable artifact symlink. It does not restore or modify
resources, cfg files, txData or MariaDB.

```bash
set -euo pipefail
REPO=/opt/randy-2
ACTIVE="$REPO/server-binaries/enhanced-129"
NEW="$REPO/server-binaries/enhanced-linux-161"
OLD="$(cat "$REPO/runtime/last-enhanced-rollback-path")"
NEXT="$REPO/server-binaries/.enhanced-129.rollback"

test "$OLD" = "$REPO/server-binaries/enhanced-linux-156"
test -L "$ACTIVE"
test "$(readlink -f -- "$ACTIVE")" = "$(readlink -f -- "$NEW")"
test -x "$OLD/run.sh"
test -x "$OLD/alpine/opt/cfx-server/cfx-server"
test ! -e "$NEXT"

sudo systemctl stop txadmin.service
sudo ln -s -- "$(basename "$OLD")" "$NEXT"
sudo mv -Tf -- "$NEXT" "$ACTIVE"
test "$(readlink -f -- "$ACTIVE")" = "$(readlink -f -- "$OLD")"
sudo systemctl start txadmin.service
sudo systemctl is-active --quiet txadmin.service
sudo journalctl -u txadmin.service -n 100 --no-pager
```

After rollback, confirm txAdmin reports b156, oxmysql reconnects, required
resources start, and an Enhanced-client connection behaves as expected. Note
that FiveM's b161 connection requirement may prevent clients from reconnecting
to b156; rollback is for diagnosing a b161 regression, not a supported final
state.
