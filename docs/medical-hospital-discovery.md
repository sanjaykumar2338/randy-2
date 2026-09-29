# Bounded hospital pavement discovery

This replaces the single-point hospital path deployed from
`4f88b50327b88b01368ef329c0cf33fabafd2f9d`. No VPS deployment was performed by the
coding agent. Automated results are not live Enhanced acceptance.

## Root cause

Normal recovery used one unaccepted XYZ position, `300.8,-585.6,43.28`, and could
only succeed if ground was within 2 m of that configured Z. There was no alternate
position. The observed `ground_z_mismatch` therefore rejected every E attempt
before resurrection. Teleporting directly to that XYZ also caused falling/death.
The exact Enhanced terrain/collision behavior behind the mismatch remains
unproven, but this position is demonstrably unsuitable as an assumed spawn.

Console recovery works at a validated local surface: resurrection, movement,
death reconciliation and saving already work. This change replaces hospital
destination selection, keeping the shared resurrection block.

A separate client defect was found during external-revive review: cleanup erased
the observed-death history. A subsequent delayed server death packet could then
be mistaken for persisted death on a fresh login and kill the revived ped. The
client now retains this history until unload/stop and ignores stale death states
when the observed-dead character is already alive. Fresh login/restart still
enforces persisted death; this does not grant a reconnect bypass.

## Exact strategy

The old coordinate is now **only the center of a search volume**, never an
automatically trusted spawn. No replacement safe coordinates are invented and no
manual NoClip survey is required before an ordinary E request.

1. Keep the corpse at its origin. Acquire a destination scene and render focus
   covering the bounded search volume. An already-owned scene is not taken over.
2. Try 13 ordered relative XY seeds: the center; four cardinal offsets at 12 m;
   four diagonal offsets of 12 m per axis; four cardinal offsets at 24 m. Request
   collision as each seed is examined. All seeds share the existing eight-second
   timeout; cycle through them again for transient loading failures.
3. Probe ground from the top of a volume extending 50 m above/below center Z.
   Ask `GetSafeCoordForPed` for nearby **pavement, non-isolated, non-interior,
   non-water** navmesh using flags `1|2|4|8` (15). Reject results more than 6 m
   from their seed or more than 32 m horizontally from the hospital center.
   These are documented [Cfx navmesh flags](https://github.com/citizenfx/natives/blob/master/PATHFIND/GetSafeCoordForPed.md).
4. At that actual navmesh XY, query ground again and cast a world ray through the
   full vertical search volume. Require ground/ray Z agreement within 0.25 m,
   navmesh/ground agreement within 1 m, and surface normal Z at least 0.9. Require
   a repeat pavement query within 0.75 m of the chosen XY. A roof/cover over a
   lower ground hit causes top-ray disagreement; a roof/interior/water polygon
   cannot be accepted simply because ground exists there.
5. Probe four footprint edges 0.45 m from the center. All must have world ground
   within 0.25 m and slope normal Z at least 0.9. Reject ledges/narrow surfaces and
   vehicles within 2 m. Test a vertical capsule of radius 0.45 m, from ground+0.6
   to ground+1.6, for collidable world, objects, peds and vehicles. Its async result
   must complete without a hit within 250 ms and before the overall deadline.
   The [trace flags](https://github.com/citizenfx/natives/blob/master/SHAPETEST/StartShapeTestLosProbe.md)
   use all categories and ignore only non-collidable objects, not glass.
6. After the capsule's final yield, recheck scene, pavement, ground/ray, footprint,
   slope and nearby vehicles. Ground must remain within 0.05 m of the checked
   capsule's floor. There is no further yield before placement. If anything
   fails, leave the corpse untouched and proceed to the next candidate.
7. Use the same resurrection block as console recovery, with the measured ground
   plus the existing 1 m ped-origin offset and configured heading (70 degrees).
   Enable collision, unfreeze only this successfully resurrected ped, clear
   velocity, restore health/tasks/stamina/control and release owned streaming/fade.

The 50 m vertical bound is a **search bound**, not permission to accept a height
that disagrees with collision. The old two-metre local-surface tolerance remains
unchanged for console recovery and explicit-point diagnostics. A hospital ground
hit alone never authorizes resurrection: it must also be exposed, navmesh pavement,
level across the footprint and free of collidable obstructions. Semantic pavement
classification still depends on the live map's navmesh, and remote entity/collision
availability depends on the engine; mocks cannot certify the physical location.

If every candidate remains invalid, the resource fades back in, releases owned
streaming state, leaves death/position intact and displays the existing retry
message. The original 20-second exclusive request lease must expire before E can
retry. Frozen, in-vehicle or collision-disabled peds are refused; medical does not
take over NoClip/foreign freeze during failure, cleanup or external revive.

The server recognizes hospital arrivals within the same search volume instead of
the old 5 m sphere. This preserves minimum hunger/thirst recovery for a valid
fallback arrival. It is only arrival classification: server-observed health still
controls death clearing and Qbox Save, including external revives. No client event
can declare successful arrival. Countdown, E, inventory, cash/bank, employment,
death persistence and duplicate-request protection remain unchanged.

Diagnostics log candidate index, seed/actual position, rejection reason and
available ground/ray/navmesh evidence. Accepted candidates log their measured
surface. Optional F8 `medical_survey_hospital` now runs the complete discovery
without moving/reviving its alive observer. Four explicit arguments retain the
old single-point diagnostic; neither form changes config or authorizes recovery.

## Automated checks

Run from repository root:

```text
python tests/run-economy-lua.py
git diff --check
```

The runner executes six suites, including all three medical suites. Coverage:

- First candidate valid; first invalid or obstructed then second valid; a last-frame
  vehicle obstruction falls through to the next candidate.
- Measured ground Z different by more than 2 m from center Z is used only after
  all pavement/collision/clearance checks pass.
- Ground/ray failures, steep surfaces, missing pavement, out-of-bounds navmesh,
  navmesh/ground mismatch, uncovered-footprint failure, covered/underground ground,
  body obstruction and pending/invalid capsule results all reject safely.
- Every seed visited on full failure within one timeout; no movement/resurrection,
  no collision/unfreeze writes on failure; cleanup and subsequent E retry work.
- Successful revival enables collision and unfreezes; foreign freeze/NoClip state
  remains untouched on refusal, external revive, unload and stop.
- Countdown/early rejection, duplicate requests, metadata/UI cleanup, Save once,
  retained items/cash/bank, reconnect/restart and employment regression coverage.
- External revive during preparation and delayed death packets after confirmation;
  fresh login still enforces persisted death.
- Fallback arrivals receive normal hunger/thirst and save behavior; external
  revives outside the discovery volume clear death without hospital needs.

## Backup-first deployment: operator only

Deploy **all three changed runtime files together**. Server/config consistency is
required for the search bounds and arrival-needs classification. No other runtime
file, private config or database is modified. In VPS Bash as the runtime owner:

```bash
set -euo pipefail
COMMIT=FULL_COMMIT_HASH_FROM_DELIVERY
cd /opt/randy-2
git fetch origin main
git merge-base --is-ancestor "$COMMIT" origin/main
MEDICAL='/opt/randy-2/runtime/qbox-server-data/resources/[tarrant]/tarrant_medical'
BACKUP="/opt/randy-2/runtime/medical-discovery-backup-$(date -u +%Y%m%dT%H%M%SZ)"
umask 077
mkdir -m 700 "$BACKUP"
for f in client.lua server.lua config.lua; do
  cp -p "$MEDICAL/$f" "$BACKUP/$f.before"
  git show "$COMMIT:resources/[tarrant]/tarrant_medical/$f" > "$BACKUP/$f.after"
  test -s "$BACKUP/$f.after"
done
printf 'Keep rollback directory: %s\n' "$BACKUP"
```

In **txAdmin server console**: `stop tarrant_medical`. Then in the same Bash session:

```bash
for f in client.lua server.lua config.lua; do
  cat "$BACKUP/$f.after" > "$MEDICAL/$f"
  cmp -s "$MEDICAL/$f" "$BACKUP/$f.after"
done
```

In **txAdmin server console**: `ensure tarrant_medical`. No `refresh`, server-wide
restart or reconnect is required to load these existing resource files. Restarting
medical briefly interrupts its UI/requests; persistent death remains authoritative.

Rollback: `stop tarrant_medical`, then in the same Bash session:

```bash
for f in client.lua server.lua config.lua; do
  test -s "$BACKUP/$f.before"
  cat "$BACKUP/$f.before" > "$MEDICAL/$f"
done
```

Then `ensure tarrant_medical`. The backup restores the known single-point failure.

## Short live acceptance checklist

1. Record Tester A's inventory/counts, cash and bank. With normal movement and no
   admin assistance, die near the hospital. Confirm 30 seconds, early E denial,
   then the Arlington Memorial E prompt. Press E repeatedly during preparation.
2. Require exactly one recovery onto exterior hospital pavement, alive and walking.
   Check no sky fall, underground/roof spawn, collision issue, death loop or stuck
   recovery UI. Retain the accepted-candidate F8 line. Check items/cash/bank,
   hunger/thirst and successful character save. Do not use rescue/heal/NoClip to
   make this acceptance pass.
3. Tester B repeats from a different distant location with the hospital initially
   unstreamed. Require the same complete death -> 30 sec -> E -> hospital -> alive
   -> walking flow. Inspect the chosen pavement on the actual Enhanced map.
4. Reconnect after successful recovery and confirm the character stays alive with
   retained items/money. Also confirm reconnect while dead retains countdown/death.
5. In a controlled test, obstruct a previously chosen candidate with a parked
   vehicle and repeat recovery. Require safe fallback to another validated point
   or safe rejection at the original death position. On rejection, remove the
   obstruction and retry after the original 20-second lease expires.
6. In staging, test an existing legitimate external revive during preparation and
   restart medical while dead/preparing: no extra teleport, re-kill, stuck fade or
   unintended unfreeze. Confirm employment cancellation/payment behavior remains
   unchanged. Keep the unrelated intermittent disconnect issue separate.

Only mark hospital recovery PASS after both testers complete steps 1–3 on the
live Enhanced server. If discovery fails, retain the per-candidate reasons and
overall failure line; no manual-coordinate hunt is required to exercise this flow.
