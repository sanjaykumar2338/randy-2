# Medical hospital surface validation follow-up

> Historical c8aee71 notes. The txAdmin recovery instructions, freeze behavior and
> one-file deployment below are superseded by [medical-admin-recovery.md](medical-admin-recovery.md).
> Do not use Heal: Myself to recover this test character.

## Diagnosis and scope

The live test proved death detection, the 30-second countdown and E input work.
The old validation branch rejected recovery after already moving the dead ped.
The generic error did not record which predicate failed; there is no measured
ground Z or collision trace from that attempt. It would be incorrect to claim
that a particular terrain height or b156 bug has been proven.

Confirmed code defects, independently reproduced in regression tests:

1. `SetEntityCoordsNoOffset` moved the dead ped on every iteration before checking
   the destination. Failure had no rollback to the original death position.
2. The loop exited on ground-found plus ped collision, **before** checking the
   2 m Z tolerance. A temporary hit on a lower level could end the entire 8-second
   loading window after just one 50 ms iteration.
3. Destination streaming relied on repeated collision requests and teleporting
   the ped. There was no explicit destination scene/render focus. Cfx documents
   that ground queries require the target to be within the client's render area:
   [GetGroundZFor_3dCoord](https://github.com/citizenfx/natives/blob/master/MISC/GetGroundZFor_3dCoord.md).

## Fix

* Prepare a bounded hospital scene using `NewLoadSceneStartSphere` and terrain
  streaming focus (`SetFocusPosAndVel`, **not NUI focus**). Keep the ped at the
  original death position throughout validation.
* Request destination collision and require a loaded scene, found ground within
  the unchanged 2 m Z tolerance, a destination world-collision ray agreeing with
  ground Z within 0.25 m, a walkable surface normal (Z >= 0.9), and no vehicle
  within 2 m of the spawn. No configured-Z fallback or unconditional resurrection.
* Retry failed predicates within the existing 8-second window, including an
  early wrong-level ground result. Only a fully accepted destination reaches
  `NetworkResurrectLocalPlayer`; this is the first operation that moves the ped.
* Release owned scene/render focus, freeze and fade on failure, success, unload,
  stop and external revive. Do not stop an already active scene owned by another
  resource. Each rejected attempt prints the failed predicate, configured target,
  last ground result and elapsed time to client F8.
* Leave the 20-second server transfer lease intact. A failed attempt does not
  erase death, reset the 30-second deadline or bypass request validation. After
  lease expiry the next explicit E request can retry; spamming cannot overlap it.

Medical server logic, configuration, employment, world locations, upstream
resources, private configuration, database, b156 and NUI files are unchanged.

## Coordinates — deliberately pending measurement

There is **no new coordinate** in this validation-only fix. The existing unverified
candidate remains `300.8, -585.6, 43.28`, heading `70.0`. The code repair prevents
unsafe movement on rejection; it does not certify this candidate as a suitable
exterior surface. The user explicitly requested no guessed replacement.

To supply the measured replacement using the server's existing txAdmin UI:

1. Revive through txAdmin, then walk normally to clear, level, accessible exterior
   pavement at Pillbox/Arlington Memorial. Stay outside the building/canopy and
   away from steps, doors, walls, parked vehicles and active traffic. Do not sample
   while dead, in a vehicle, noclipping or hovering.
2. Face the desired arrival direction. Open `/tx` (or `/txadmin`), Main page,
   Teleport/Coords controls, and use **Copy current coordinates** (clipboard action).
3. Paste the four numbers `x, y, z, heading`. The inspected bundled txAdmin
   `resource/menu/client/cl_main_page.lua` callback `copyCurrentCoords` obtains
   `GetEntityCoords(PlayerPedId())` and `GetEntityHeading(...)` and copies all four
   to four decimal places. No new command, resource or private-config edit is needed.

The measured replacement will be a separate config-only change and live check.

## Tests

`python tests/run-economy-lua.py` runs six suites. The new surface suite was run
against the original client first and failed on premature movement. It now covers
delayed remote streaming, transient wrong Z followed by valid ground, missing
ground, permanently wrong Z, missing world collision, steep ground, a blocking
vehicle, busy/failed scene loading, expiry/retry, stop/unload and external revive.
Every rejection asserts no movement/resurrection, original-position retention,
streaming/freeze/fade cleanup and a diagnostic. Existing medical authority,
countdown, duplicate-request, persistence, inventory/money and employment/world
regression tests remain included. These are native mocks, not a live b156 survey.

## Targeted deployment — operator only, not executed

Only the existing `tarrant_medical/client.lua` needs replacing. Do not copy config,
server.lua, other resources or server.cfg. Use a maintenance window: restarting
medical briefly interrupts its UI/requests; pending death metadata is preserved.

Export the full delivered commit as `REVIEWED_COMMIT`, then in VPS Bash as the
existing runtime owner:

```bash
set -euo pipefail
: "${REVIEWED_COMMIT:?Export the full delivered commit hash}"
cd /opt/randy-2
test -z "$(git status --porcelain --untracked-files=no)"
git fetch origin main
git merge-base --is-ancestor "$REVIEWED_COMMIT" origin/main
git merge --ff-only "$REVIEWED_COMMIT"
test "$(git rev-parse HEAD)" = "$REVIEWED_COMMIT"
MEDICAL='/opt/randy-2/runtime/qbox-server-data/resources/[tarrant]/tarrant_medical'
test -f "$MEDICAL/client.lua"
test -f "$MEDICAL/config.lua"
BACKUP="/opt/randy-2/runtime/medical-surface-backup-$(date -u +%Y%m%dT%H%M%SZ)"
umask 077
mkdir -m 700 "$BACKUP"
cp -p "$MEDICAL/client.lua" "$BACKUP/client.lua.before"
git show "$REVIEWED_COMMIT:resources/[tarrant]/tarrant_medical/client.lua" > "$BACKUP/client.lua.after"
test -s "$BACKUP/client.lua.after"
printf 'Retain rollback directory: %s\n' "$BACKUP"
```

FXServer/txAdmin **server console**:

```text
stop tarrant_medical
```

Same Bash session (preserves existing file owner/permissions):

```bash
cat "$BACKUP/client.lua.after" > "$MEDICAL/client.lua"
cmp -s "$MEDICAL/client.lua" "$BACKUP/client.lua.after"
```

Server console:

```text
ensure tarrant_medical
```

Rollback, only if required: stop medical in server console, then in the same Bash
session run the following and `ensure tarrant_medical` in server console afterward.
Rollback restores the known premature-teleport defect; keep testing access limited.

```bash
test -f "$BACKUP/client.lua.before"
cmp -s "$MEDICAL/client.lua" "$BACKUP/client.lua.after"
cat "$BACKUP/client.lua.before" > "$MEDICAL/client.lua"
```

## Live retest

1. Record original death position, items, cash and bank. Die far enough from
   Pillbox that its area is initially unstreamed. Confirm the same 30-second
   countdown and no automatic resurrection; press E only after zero.
2. If the unchanged candidate is rejected, the dead ped must remain at the
   original death position. Fade/freeze must release. Copy the single F8 line
   beginning `[tarrant_medical] Hospital validation failed:` including reason,
   target, ground and elapsed time. A failed physical-location check is a safe
   rejection, not evidence the coordinate has been fixed.
3. Wait until the original 20-second request lease expires, then press E again.
   Confirm no overlapping transfers, countdown restart, premature movement or
   inventory/money changes.
4. If validation succeeds, confirm one recovery, usable health/movement/camera,
   inventory and voice, unchanged money/items, and a fresh timer on the next death.
5. In staging, restart medical and admin-revive during destination preparation.
   Confirm no stuck streaming focus, frozen screen, extra teleport or re-kill.
6. Supply the measured exterior coordinate and heading using the steps above.
   After its separate config update, repeat distant and nearby death recovery
   with two players and inspect the actual floor, clearance and heading. Do not
   treat the unmeasured candidate as launch-accepted.
