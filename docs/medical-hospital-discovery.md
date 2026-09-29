# Medical recovery: explicit hospital exterior candidates

Current follow-up to failed live `fe380120605a5a3829b165889ffc3480680a71d0`.
Retains the four explicit candidates and reliable local physical validation;
unavailable body-clearance probes no longer veto otherwise valid exterior ground.
No VPS deployment was performed by the coding agent.
Live acceptance is still required; no admin command is part of civilian recovery.

## What failed

The latest live failure had valid street-level ground but every candidate reported
`body_clearance_unavailable`, followed by `clearance_pending_at_end`. The code
combined three distinct capsule outcomes into the same rejection: invalid handle
(status 0), elapsed probe budget (250 ms), and completed hit (status 2, hit true).
It repeatedly discarded/restarted jobs until the eight-second search deadline,
where pending jobs were discarded without a final ground-based decision.

[GetShapeTestResult](https://github.com/citizenfx/natives/blob/master/SHAPETEST/GetShapeTestResult.md)
defines 0 as invalid, 1 as pending and 2 as complete; hit output is undefined for
0/1. Pending or invalid therefore cannot establish an obstruction. The supplied
logs do not establish why Enhanced did not complete these remote capsules, or
distinguish every earlier rejection from a completed hit. No engine defect is
claimed. The demonstrated code defect is treating unavailable clearance as unsafe
ground and exhausting the recovery budget instead of using the explicit points.

The fix polls capsules for at most 250 ms (or the remaining scene budget). A
completed hit rejects that candidate as `body_obstructed`. Invalid or still-pending
results use `clearance=ground_fallback` after fresh reliable surface checks. A
completed clear result uses `clearance=confirmed_clear`. The final polling pass
also runs at the shared deadline, so late scene loading cannot strand a validated
candidate behind a pending capsule. The deadline bounds waiting; final synchronous
surface checks still run before any resurrection. Unknown hit output is never
interpreted as a positive or negative obstruction result.

The earlier road-search implementation coupled safe placement to unrelated road-query rules.
It refused flags including `64` (HIGHWAY), although that classification alone says
nothing about collision or standing clearance at the destination. Its second road
lookup could also reject a returned pavement point based on road-distance limits.
The quoted west-road coordinate is inside the first lookup's limits; without the
complete returned-pavement fields, that excerpt cannot identify which lookup
produced `road_outside_search`. These dependencies are removed, not widened.

`covered_or_unloaded` combined an incomplete upward shape test with any world hit
up to 80 m overhead. A canopy/bridge well above a standing player therefore caused
rejection even when the floor and body clearance were usable. This did not establish
that the destination collision was missing. Actual scene/ground/body checks remain;
the open-sky requirement is removed.

Road flag definitions: [Cfx native reference](https://github.com/citizenfx/natives/blob/master/PATHFIND/GetVehicleNodeProperties.md).
No Enhanced-native defect is assumed. A rendered street at the corpse's location
does not itself validate a remote hospital destination; the new flow validates the
selected destination directly without moving the corpse first.

## Explicit points and provenance

These are **candidates**, not pre-authorized spawns. The first point has direct
ground/ray evidence; the remaining three are exterior street references from the
latest F8 data. They require fresh ground/collision checks on every recovery.
No arbitrary offsets or guessed replacement XYZ have been added.

| Order | Point | XYZ floor hint | Evidence |
| --- | --- | --- | --- |
| 1 | Southern pavement | 296.1680, -609.3672, 42.357627868652 | Earlier live candidate 13: pavement lookup plus agreeing ground/ray |
| 2 | Northern exterior | 297.5000, -549.5000, 42.2188 | Latest live candidate 12 road reference |
| 3 | Western exterior | 262.2500, -582.7500, 42.3438 | Latest live candidate 11 road reference |
| 4 | Northeastern exterior | 329.5000, -551.5000, 42.7812 | Latest live candidate 10 road reference; flag 64 is not used as a veto |

All retain heading 70.0. The low southern road reference
`299.25,-647,28.3125`, the underground troubleshooting coordinates, and the old
`300.8,-585.6,43.28` arrival are **not** fallback destinations. The old center
remains a streaming reference and server arrival-envelope center only.

## Production path

1. Keep the 30-second countdown, explicit E request and 20-second exclusive server
   lease. Stream the candidate area and request collision at all four points.
2. At each exact XY, query ground from floor hint +1 m and raycast down to hint
   -2.5 m. Require ground, a completed world-collision hit, ray/ground agreement
   within 0.25 m, and ground within 2 m of the candidate's own floor hint. This
   excludes the observed high 48.75/89.62 and underground 16.98 layers here.
3. Require slope normal Z >=0.9 and supported footprint edges 0.45 m around the
   center. Require no vehicle within 2 m. Try a standing-body capsule covering
   collidable world, objects, peds and vehicles: a completed positive hit rejects
   the candidate. Invalid, pending or timed-out clearance permits ground fallback
   for this explicit candidate list only. A canopy above the player does not fail
   merely because it exists. When the capsule is unavailable, overhead/object
   clearance is unknown; the fallback does not claim to have measured it.
4. Check all eligible candidates without blocking on one pending capsule. Retain
   the shared eight-second wait limit and per-probe 250 ms limit. Prefer the first
   candidate whose checks finish successfully; failed candidates never move the ped.
5. After the capsule result or fallback decision, freshly check the local floor,
   ray, slope, footprint and vehicles. The scene must be loaded and floor must
   remain within 0.05 m of the initially sampled floor. No yield separates final
   validation and resurrection.
6. Use the existing shared resurrection block at **measured ground +1 m**, restore
   collision, unfreeze the recovered ped, clear velocity/tasks/blood, restore health
   and control, release owned fade/streaming, and let server reconciliation clear
   death metadata/UI and invoke Qbox Save.

All-failure leaves the corpse unmoved, preserves death and allows another E after
lease expiry. Medical never releases foreign freeze/NoClip state on refusal or
cleanup. Items, cash/bank, employment rules and external-revive history protection
remain unchanged. Reconnect/restart still enforce persistent death.

The shared arrival radius is now 50 m to include all four explicit points for
normal hunger/thirst recovery and saving. This is server needs classification,
not permission to skip destination validation. `server.lua` is unchanged.

There are no recovery calls to `GetClosestVehicleNode`, `GetVehicleNodeProperties`
or `GetSafeCoordForPed`, and no upward sky ray. Optional `medical_survey_hospital`
tests this same list read-only. Its four-argument point diagnostic, local survey
and console recovery commands remain available but are not recovery requirements.

## Regression results

Run `python tests/run-economy-lua.py` and `git diff --check` from repository root.
The six suites cover employment server, world, medical server, medical client,
medical surface and employment client marker.

Surface fixtures reproduce all four quoted road references/flags while asserting
zero road/native lookup calls. A 6 m canopy (and a 2.3 m canopy clear of the body)
permits recovery; a 1.8 m ceiling blocks the capsule and selects the next point.
Tests verify each fallback, actual measured placement, ray/height/slope/footprint/
object/vehicle rejection, all-candidate failure and retry, late scene loading and
stalled early probes, stale results, lifecycle cleanup, external revive and late
death packets, and read-only diagnostics/config preservation. Server regressions
check needs, Save and retained assets for **every** explicit candidate.

The latest regression reproduces all four capsules indefinitely pending above
valid measured ground: normal E recovery completes after 250 ms via the first
candidate, restoring collision, unfreeze, task clearing and control exactly once.
Invalid status 0 also recovers; undefined hit=true in either status cannot veto
recovery. Tests retain completed-hit rejection, each later candidate's unknown-
clearance fallback, fresh safety-check failures, a scene loaded at 7950 ms with
pending clearance at 8000 ms, and delayed scheduling past the polling deadline.

Native mocks do not certify the live map. In particular the street references are
not surveyed pedestrian spawn approvals. Runtime validation and the two-player
live acceptance below remain mandatory before claiming hospital recovery PASS.

## Backup-first VPS deployment (operator only)

From deployed fe38012, replace **client.lua only**. The existing four-candidate
config.lua and server.lua are unchanged. In VPS Bash as the runtime owner:

```bash
set -euo pipefail
COMMIT=FULL_COMMIT_HASH_FROM_DELIVERY
cd /opt/randy-2
git fetch origin main
git merge-base --is-ancestor "$COMMIT" origin/main
MEDICAL='/opt/randy-2/runtime/qbox-server-data/resources/[tarrant]/tarrant_medical'
BACKUP="/opt/randy-2/runtime/medical-clearance-backup-$(date -u +%Y%m%dT%H%M%SZ)"
umask 077
mkdir -m 700 "$BACKUP"
for f in client.lua; do
  cp -p "$MEDICAL/$f" "$BACKUP/$f.before"
  git show "$COMMIT:resources/[tarrant]/tarrant_medical/$f" > "$BACKUP/$f.after"
  test -s "$BACKUP/$f.after"
done
printf 'Keep rollback directory: %s\n' "$BACKUP"
```

In **txAdmin server console**: `stop tarrant_medical`. Then, in the same Bash session:

```bash
for f in client.lua; do
  cat "$BACKUP/$f.after" > "$MEDICAL/$f"
  cmp -s "$MEDICAL/$f" "$BACKUP/$f.after"
done
```

In **txAdmin server console**: `ensure tarrant_medical`. No `refresh`, server-wide
restart, private config, artifact or database changes are needed.

Rollback: stop medical, restore the `.before` file in the same Bash session,
then ensure medical. This restores the previous known live failure.

```bash
for f in client.lua; do
  test -s "$BACKUP/$f.before"
  cat "$BACKUP/$f.before" > "$MEDICAL/$f"
done
```

## Short live acceptance

1. Record inventory/counts, cash and bank. Tester A dies near the hospital, waits
   30 seconds, presses E and must arrive alive and walking normally at an exterior
   candidate. Tester B repeats from a distant location with the area unstreamed.
2. No admin recovery, medical_recover_here, Heal or NoClip. Check no falling,
   underground/roof spawn, repeated death, stuck UI or missing collision. Verify
   retained assets, intended recovery needs, successful save and alive reconnect.
3. In staging, block the first candidate and verify safe fallback or rejection
   without corpse relocation. Check retry after lease expiry and external revive
   cancellation. Keep both accepted-candidate F8 lines; on failure retain all four
   candidate summaries with exact physical-check reasons.

Only mark hospital recovery PASS after both normal live E tests succeed.
