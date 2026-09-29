# Pavement survey after fce08aa live rejection

> Historical notes. Current diagnosis, remote candidate validation, deployment
> and acceptance steps: [medical-hospital-recovery.md](medical-hospital-recovery.md).

## Evidence and diagnosis

The operator deployed only medical client/server from
`fce08aa387f73b8930f9a54e155987949a51be02`. Console accepted
`medical_recover_here 1`; the player remained dead. Client reported target
`300.8000,-585.6000,43.2800`, ground `16.756881713867`, and
`ground_z_mismatch` after 8000 ms. NoClip was disabled and txAdmin heal was not used.

The rejection correctly retained death and prevented an unsafe placement. Never
use 16.7569 as a replacement coordinate. Visible pavement is not sufficient to
bypass the existing ground/collision agreement requirement.

Code inspection shows recover_here calls relocate(ticket, true), constructing its
target from GetEntityCoords(ped). It does NOT select cfg.hospital. Both modes used
the same misleading "Hospital validation failed" message. Therefore:

- If that log belongs to recover_here, the ped was sampled at the reported target,
  even though it happens to equal the configured hospital candidate.
- The old log alone cannot distinguish that case from a normal E recovery log.
  Console acceptance proves dispatch, not that the client accepted the event.
- No code path was found that substitutes cfg.hospital for a received here=true.
  Regression now explicitly verifies this using a different ped position.
- The candidate is unaccepted. Evidence does not yet establish that this is solely
  a bad config coordinate rather than a ground-query/collision disagreement in
  this runtime. Changing config alone would not change recover_here's target.
- The old validator only runs its collision ray after ground Z passes, so that
  failure did not record whether nearby world collision disagrees with ground.

## Minimal change

Only runtime client.lua changes. Recovery start/failure logs identify mode,
actual ped position and selected target; rejected console events are logged.
Recover_here's error text no longer tells the operator to press E at the hospital.

New local F8 command: `medical_survey_here`. This is read-only and usable while
alive or dead. It samples ped x/y/z and heading, death/freeze/vehicle/collision
status, ground-found/Z, and an independent nearby world-ray hit/Z/normal. The ray
runs even if ground is missing or has a wrong Z. It uses the existing vertical
probe bounds, world collision mask, slope and agreement thresholds.

`geometryAgrees` summarizes only the geometric predicates. `aliveCandidate` also
requires alive, unfrozen, outside a vehicle, collision loaded and no nearby vehicle.
Neither flag certifies standing, pedestrian accessibility, hospital identity or a
safe respawn. A single snapshot is not a stable-standing test. No scene/focus/fade,
freeze, coordinates, health, server callback, metadata or inventory is changed by
survey. A recovery in progress or unloaded player rejects the survey.

The survey never authorizes recovery. The existing console recovery reruns its
full scene/surface checks, including movement checks. All safety predicates and
civilian behavior are unchanged. No configured coordinate is changed.

## Safest recovery of the dead player

1. Deploy the client below. Stay on the affected character; do not press E or use
   txAdmin Heal Myself. Record inventory, cash and bank.
2. With NoClip disabled and body settled, run `medical_survey_here` in **client F8**.
   Save the complete line. Repeat while stationary to distinguish transient data.
3. If geometry does not agree, do not recover there. Use NoClip only to reposition
   the dead player near another visibly rendered open exterior pavement patch.
   Lower close to the pavement, disable NoClip and any separate freeze, and let
   the body settle before surveying again. Avoid roads, vehicles, walls, stairs,
   roofs, canopy and interiors. Do not infer any target Z from the rejected ground.
4. At a visually suitable spot with repeatable agreeing geometry, collision=true,
   frozen=false, inVehicle=false and vehicleNear=false, wait for any prior 20-second
   recovery lease to expire. Run `medical_recover_here 1` in **server console**,
   using the current server ID if it changed. Dead players correctly have
   aliveCandidate=false; that is not itself a rejection of the geometry.
5. Verify client `Recovery start: mode=recover_here` has ped and target equal to the
   surveyed location. Recovery still may reject if the scene or surface changes.
   If it succeeds, verify no fall, normal walking and cleared medical UI, then
   reconnect to confirm death was saved as cleared. Verify items/money unchanged.
6. If every suitable patch disagrees, stop attempts and retain the survey and mode
   logs. There is no validated safe recovery available there under the current
   constraints. A ray-only fallback or forced revive is not an acceptable next step.

This does not promise recovery at the rejected spot. It supplies the missing
measurement needed to find and validate a different real surface safely.

## Measure an exterior hospital standing coordinate

Once safely recovered, walk normally to the desired accessible exterior hospital
pavement. A second already-alive operator may perform this survey independently
while the affected character remains dead. Neither needs a heal or metadata reset.

Stand still outside vehicles in Normal mode, away from traffic, objects and slopes.
Run `medical_survey_here` several times while stationary. Save full lines showing
repeatable ped x/y/z, heading, ground and ray results, aliveCandidate=true, and a
visual description of the hospital pavement. Confirm ordinary walking there and
face the intended arrival direction. Ped Z is the standing position; ground/ray Z
is the measured surface. Keep both rather than treating them as interchangeable.

Supply those measurements for a separate reviewed config change. If ground and ray
disagree at the desired pavement, do not promote either to a spawn coordinate.
Even an agreeing survey requires the usual distant and nearby E-recovery tests
before the hospital location can be accepted. No replacement is guessed here.

## Backup-first VPS deployment (operator only)

This delta assumes the reported fce08aa client/server deployment. Replace only
client.lua; keep its server.lua and existing config. Run as the runtime owner:

```bash
set -euo pipefail
export REVIEWED_COMMIT=FULL_COMMIT_HASH_FROM_DELIVERY
cd /opt/randy-2
git fetch origin main
git merge-base --is-ancestor "$REVIEWED_COMMIT" origin/main
MEDICAL='/opt/randy-2/runtime/qbox-server-data/resources/[tarrant]/tarrant_medical'
BACKUP="/opt/randy-2/runtime/medical-survey-backup-$(date -u +%Y%m%dT%H%M%SZ)"
umask 077
mkdir -m 700 "$BACKUP"
test -f "$MEDICAL/client.lua"
cp -p "$MEDICAL/client.lua" "$BACKUP/client.lua.before"
git show "$REVIEWED_COMMIT:resources/[tarrant]/tarrant_medical/client.lua" > "$BACKUP/client.lua.after"
test -s "$BACKUP/client.lua.after"
printf 'Retain rollback directory: %s\n' "$BACKUP"
```

Server console: `stop tarrant_medical`. Then in the same Bash session:

```bash
cat "$BACKUP/client.lua.after" > "$MEDICAL/client.lua"
cmp -s "$MEDICAL/client.lua" "$BACKUP/client.lua.after"
```

Server console: `ensure tarrant_medical`.
Rollback: stop medical, run `cat "$BACKUP/client.lua.before" > "$MEDICAL/client.lua"`
in the same Bash session, then ensure medical. No checkout/merge or other runtime
file replacement is needed. No VPS commands were executed by the coding agent.

## Live acceptance

- Read-only survey works dead/alive, reports actual position and independent ray
  data, and never changes health, position, freeze, death persistence or items/money.
- At the reported failing location, capture ground and ray independently. If ray
  is near pavement Z but ground remains around 16.7569, retain both as evidence of
  native disagreement; do not weaken the validation.
- Console recovery start reports mode=recover_here and the surveyed ped location,
  never the configured hospital unless the ped is actually there. Unexpected mode
  or coordinates require stopping and checking deployed file/client restart state.
- Bad/frozen/in-vehicle/moving attempts remain rejected. Death remains persisted;
  no teleport, unfreeze, unsafe revive or timer reset occurs on rejection.
- A different validated surface permits safe rescue, retained items/money, normal
  movement and alive reconnect. Do not mark this passed until observed live.
- Normal E recovery still waits 30 seconds, uses mode=hospital, and rejects the old
  candidate safely. Reconnect/resource restart while dead retains enforcement.
- Employment cancellation/payment behavior remains unchanged. After a separately
  measured config change, test nearby/distant recovery and pavement accessibility.

## Regression

Run `python tests/run-economy-lua.py` and `git diff --check`. Six suites cover the
existing medical, employment and world behavior. Added assertions check recovery
mode/origin, rejected 16.7569 ground, independent survey ray on disagreement,
read-only survey alive/dead, invalid geometry/freeze/vehicle and unload rejection.
These are native mocks, not live Enhanced surface certification.
