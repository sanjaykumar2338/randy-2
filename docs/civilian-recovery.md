# Civilian recovery and Employment Center delivery

**Follow-up: hospital validation fix.** The first live recovery failed at surface
validation. The validation-only follow-up leaves the hospital coordinates
unchanged pending an operator-measured exterior point. Use the targeted deployment
and retest instructions in [medical-surface-validation.md](medical-surface-validation.md)
for this follow-up, not the initial-install commands below.

This is a staging candidate, not a claim of live Enhanced b156 acceptance.
No deployment, private configuration changes, database operations, artifact
changes, upstream updates or Bug 3 changes were performed by this delivery.

## Behavior and boundaries

* Employment keeps the original center, all task coordinates, 2.5 m client / 4 m
  server interaction checks, route order and $90 route payouts. A yellow 1.4 m
  cylinder appears within 25 m, distinct from the smaller blue City Hall ring.
  Death, unload, leaving the center and resource stop close only employment-owned
  UI. Another resource's TextUI is neither replaced nor hidden.
* Death cancels the unfinished employment action on both client and server.
  Previously completed stops remain, subject to the existing shift lifetime and
  character/duty rules. An already server-accepted completion is still consumed
  by the client even if death follows while the reply is in flight.
* `tarrant_medical` detects actual ped death (server player-ped health <=100,
  client `IsEntityDead`), waits a configurable 30 seconds, then offers E.
  There is no automatic timer-based resurrection. The server validates character,
  actual death and deadline and consumes the request before returning approval.
  Duplicate requests are rejected while the 20-second transfer lease is active.
* The server selects public bucket 0 and the configured hospital; the client
  cannot supply a destination or a successful-revive event. Native health
  observation reconciles hospital recovery and external/admin resurrection.
  A real external revive outside the hospital also clears recovery state.
* Hospital candidate: `300.8, -585.6, 43.28`, heading `70.0`, near the existing
  Arlington Memorial/Pillbox reference (`298.6, -584.4, 43.3`). This is deliberately
  a separate proposed arrival position, not a world-location edit. Static code
  cannot prove the surface clear of props/doors or appropriate to the live map.
  **Survey this candidate on b156 before launch.** Runtime waits up to 8 seconds
  for scene loading and accepts ground only within 2 m of configured Z, with
  destination world-collision, slope and vehicle-occupancy checks. Validation
  does not move the dead ped. On failure the player stays dead at their original
  position, is unfrozen/faded in, and can retry after the lease.
* Recovery restores maximum ped health, stamina, blood/task state and gameplay
  camera angle; releases only this resource's streaming freeze/fade. Hunger and
  thirst are raised to at least 25 on successful hospital recovery to avoid an
  immediate starvation death. Money, items and accounts are never mutated.
* QBX `isdead`/`inlaststand`, OX `dead`, voice `isDead` and `medicalRecovery`
  state are reconciled. A pre-existing weapon restriction is preserved.
  No last-stand/EMS/job/billing functionality is added.
* Death deadline persists through normal QBX metadata saving as
  `metadata.tarrantRecovery`; no schema change is required. Reconnect cannot
  bypass it through a newly alive login ped. Stopping/restarting releases owned
  visual/streaming state but does not erase persistent death. An interrupted
  transfer can be retried after restart. Unloading clears transient bags for the
  next character without erasing the old character's persisted recovery.
* Employment route persistence across logout/resource restart is unchanged.
  Death during the same session retains completed stops; reconnect does not add
  route persistence that did not exist previously.
* Chat, HUD, streamed textures and upstream NUI files are untouched. This resource
  renders frame-local native text and never calls `SetNuiFocus`.

## Automated validation

Run from the repository root:

```text
python tests/run-economy-lua.py
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/check-runtime-dependencies.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/check-public-listing-config.ps1
bash tests/check-public-listing-config.sh
bash tests/check-runtime-environment-isolation.sh
git diff --check
```

The Lua runner includes employment authority/payout tests, world regression,
medical server/client simulations and employment marker/lifecycle tests. These
mock FiveM/QBX natives; they do not prove actual networking, collision, inventory,
voice, camera, Enhanced UI visibility or durable DB writes.

Existing unrelated failures investigated, not patched:

* `tests/check-linux-artifact-install.ps1`: expects build 139; configuration is
  already pinned to 156 in the preceding commit.
* `tests/check-linux-hosted-deployment.sh`: creates an enhanced-linux-139 fixture;
  the validator correctly looks for the pinned enhanced-linux-156 directory.
* `tests/check-week2-health-log.ps1`: the nominal success fixture fails because
  the checker also probes absent local game/txAdmin listeners. A direct fixture
  run passed all structured startup assertions including tarrant_medical, then
  failed four operational checks (game listener, txAdmin listener, both HTTP
  endpoints). No runtime was started to make this test green.

## Operator deployment (not executed)

Use a maintenance/staging window. Finish active employment shifts first: replacing
that resource resets its in-memory shifts, as it already did before this patch.
Keep players disconnected while replacing resource files. Do not run installers,
SQL imports, copy the entire runtime, or replace upstream resources.

The existing deployment convention is `/opt/randy-2/runtime/qbox-server-data`.
If the running server uses a different data directory, stop and adapt that path
explicitly. These commands deliberately refuse a second medical installation or
an unexpected startup layout. They do not display configuration contents.

Set `REVIEWED_COMMIT` to the full commit hash in the delivery message. In Bash:

```bash
set -euo pipefail
: "${REVIEWED_COMMIT:?Export the delivered full commit hash first}"
cd /opt/randy-2
test -z "$(git status --porcelain --untracked-files=no)"
git fetch origin main
git merge-base --is-ancestor "$REVIEWED_COMMIT" origin/main
git merge --ff-only "$REVIEWED_COMMIT"
test "$(git rev-parse HEAD)" = "$REVIEWED_COMMIT"
DATA=/opt/randy-2/runtime/qbox-server-data
test -f "$DATA/server.cfg"
test -d "$DATA/resources/[tarrant]/tarrant_employment"
test -d "$DATA/resources/[tarrant]/tarrant_ops"
test ! -e "$DATA/resources/[tarrant]/tarrant_medical"
BACKUP="/opt/randy-2/runtime/civilian-recovery-backup-$(date -u +%Y%m%dT%H%M%SZ)"
umask 077
mkdir -m 700 "$BACKUP"
mkdir "$BACKUP/stage"
cp -p "$DATA/server.cfg" "$BACKUP/server.cfg.before"
git --literal-pathspecs archive "$REVIEWED_COMMIT" \
  'resources/[tarrant]/tarrant_medical' \
  'resources/[tarrant]/tarrant_employment' \
  'resources/[tarrant]/tarrant_ops' | tar -x -C "$BACKUP/stage"
python3 - "$DATA/server.cfg" "$BACKUP/server.cfg.after" <<'PY'
import pathlib, re, sys
src, out = map(pathlib.Path, sys.argv[1:])
text = src.read_text()
assert not re.search(r'^\s*(?:ensure|start)\s+tarrant_medical\b', text, re.M)
pattern = r'(?m)^([ \t]*ensure[ \t]+tarrant_ops[ \t]*(?:#.*)?)$'
assert len(re.findall(pattern, text)) == 1, 'Expected one explicit ensure tarrant_ops; do not guess startup layout'
out.write_text(re.sub(pattern, r'ensure tarrant_medical\n\1', text))
PY
printf '%s\n' "$REVIEWED_COMMIT" > "$BACKUP/commit"
printf 'Prepared backup: %s\n' "$BACKUP"
```

In the FXServer/txAdmin **server console**, not Bash:

```text
stop tarrant_employment
stop tarrant_ops
```

Back in the same Bash session, after both resources have stopped:

```bash
for resource in tarrant_employment tarrant_ops; do
  mv -- "$DATA/resources/[tarrant]/$resource" "$BACKUP/$resource"
done
for resource in tarrant_medical tarrant_employment tarrant_ops; do
  mv -- "$BACKUP/stage/resources/[tarrant]/$resource" "$DATA/resources/[tarrant]/$resource"
done
# Preserve the runtime config's owner and permissions; change only the prepared include line.
cat "$BACKUP/server.cfg.after" > "$DATA/server.cfg"
printf 'Keep this rollback directory: %s\n' "$BACKUP"
```

Run file operations as the existing runtime owner; the restrictive umask must not
make the new medical directory unreadable to FXServer. Do not run the copy as an
unrelated root-owned installation and then start the runtime under another user.

Server console:

```text
refresh
ensure tarrant_medical
ensure tarrant_employment
ensure tarrant_ops
```

Confirm fresh `health.startup` success includes `tarrant_medical=started`, no
Lua/native/callback errors, and b156 is still the running artifact. Perform every
acceptance item below before opening to players. The backup directory contains
configuration: retain it privately, never commit or paste its contents.

## Live acceptance — operator and Randy

1. Record both testers' items (including metadata/ammo), cash and bank. Confirm
   b156 and existing QBX/OX versions; join and select an existing character normally.
2. Walk the hospital candidate and check correct floor, open pavement, doors,
   cover, props, vehicles, heading and two-player spacing. Test from a distant
   unstreamed area. If unsuitable, do not launch: revise only medical configuration
   after a measured survey. Leave tarrant_world coordinates untouched.
3. Arrive via the Employment Center blip without a job. At about 24 m see the
   yellow approach ring; beyond 25 m it disappears. Within 2.5 m see exactly
   `[E] Employment Center`. Check ground alignment and distinction from City Hall.
4. Open with E, close with Escape, reopen, walk away, return, unload/reload and
   restart employment in staging. Verify no stale prompt/context or duplicate
   menu. Open another legitimate TextUI and verify employment does not hide it.
5. Complete sanitation stop 1. Die during stop 2's progress: progress/menu/prompt
   must close, no payout, and after recovery stop 2 remains the current stop.
   Complete it for exactly $90 once. Repeat ordinary Delivery and Transit routes;
   all coordinates, marker behavior and payouts must match the prior baseline.
6. Test death while standing at the center and with its menu open. With the
   second player observing, test NPC police gunfire, player gunfire, falling and
   drowning. Show one countdown, reject E at 29 seconds, then show the E prompt.
   Wait another 10 seconds without pressing E: remain dead.
7. Press/spam E after expiry. Observe one recovery at the hospital, correct
   surface/heading, health, stamina, movement, camera and controls. Confirm
   inventory opens and items/money match step 1; verify proximity voice and radio.
   Hunger/thirst may rise to the documented minimum of 25; no fees or item loss.
8. Die again immediately after a completed recovery: receive a fresh 30 seconds.
   Verify another player's countdown/input is independent. Repeat from a vehicle.
9. Reconnect during countdown, and after expiry: preserve the original deadline,
   require E, and do not bypass death via login/model creation. Switch characters:
   the other character must not inherit dead/inventory/weapon/UI state.
10. In staging, restart medical while dead, while countdown has expired, and
    during transfer. No frozen screen/controls or automatic revive; persistent
    death remains recoverable. A transfer interrupted by restart may require E
    again. Test a cold server restart/reconnect with a dead character as well.
11. Admin-revive during countdown and during collision/transfer: the native
    revive must survive delayed state replication; no stale death UI, extra
    teleport, repeated revive or inventory/voice lock. Also test health restored
    by another trusted server resource, if one is later installed.
12. Simulate an unavailable hospital surface only in isolated staging using a
    temporary medical-config fixture, then restore the committed config: timeout
    must release freeze/fade, keep death state, allow retry after the lease and
    leave items/money untouched. Do not edit world locations to perform this test.
13. Capture the unrelated blue panel's owning NUI frame separately. Do not change
    chat/HUD/focus/KVP/streaming configuration as part of these acceptance tests.

## Rollback (operator only)

Use maintenance mode with players disconnected, and first recover/revive active
dead testers. Rolling medical back restores the previous **missing respawn flow**;
keep civilian access closed until recovery is available again. Offline pending
death metadata is deliberately retained, not mass-cleared or edited in SQL.
Reinstalling this medical resource resumes it. No player/economy DB restore.

Server console:

```text
stop tarrant_employment
stop tarrant_medical
stop tarrant_ops
```

In Bash, set `BACKUP` to the exact directory printed by deployment:

```bash
set -euo pipefail
DATA=/opt/randy-2/runtime/qbox-server-data
: "${BACKUP:?Set the exact deployment backup directory}"
case "$BACKUP" in /opt/randy-2/runtime/civilian-recovery-backup-*) ;; *) exit 1 ;; esac
test -f "$BACKUP/commit"
test -d "$BACKUP/tarrant_employment"
test -d "$BACKUP/tarrant_ops"
# Refuse to overwrite configuration edited since deployment.
cmp -s "$DATA/server.cfg" "$BACKUP/server.cfg.after"
test ! -e "$BACKUP/rolled-back"
mkdir "$BACKUP/rolled-back"
for resource in tarrant_medical tarrant_employment tarrant_ops; do
  mv -- "$DATA/resources/[tarrant]/$resource" "$BACKUP/rolled-back/$resource"
done
for resource in tarrant_employment tarrant_ops; do
  mv -- "$BACKUP/$resource" "$DATA/resources/[tarrant]/$resource"
done
cat "$BACKUP/server.cfg.before" > "$DATA/server.cfg"
```

Server console:

```text
refresh
ensure tarrant_employment
ensure tarrant_ops
```

This restores actual backed-up runtime files rather than assuming the previous
Git revision exactly matched deployment. The checkout remains at the delivered
commit; do not redeploy it accidentally after rollback. No force push, reset,
artifact rollback, private config replacement or database mutation is required.
