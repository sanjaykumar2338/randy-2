# Hospital recovery: validate the pavement layer

Current follow-up to live `e36bca6af242a2a6a25ded9f6a0a223733973edf`.
No VPS deployment was performed by the coding agent. Automated tests are not live
Enhanced acceptance. Manual coordinate surveying is not required for this flow.

## Precise diagnosis

Candidate 1 failed `abs(ground - h.z) > 1.0`, where `h.z` was the Z returned by
`GetSafeCoordForPed`, **not** configured Z 43.28. Its supplied ground/ray
48.753879547119 and normal 1 confirm one flat collision layer, not necessarily the
returned pavement layer. The pasted evidence omits `navZ`, so the exact numerical
delta and safety of that candidate cannot be established. Candidates 5 and 9
reached the same predicate.

Both discovery and validation queried ground from `center.z + 50 = 93.28`, with a
ray spanning the whole volume. That can select a roof/canopy above the pavement;
both measurements can agree on the wrong layer. It also fed high surface heights
into pavement lookup. The different 89.62, 48.75 and 42.2 readings are consistent
with stacked geometry; the logs do not identify the exact structure at each height.
Deleting navmesh agreement would allow flat roofs, so the probe layer is corrected.

`pavement_outside_search` combined two **XY-only** comparisons: within 6 m of an
arbitrary seed AND within 32 m of the hospital. Z was not involved. The seed limit
could discard pavement inside the intended hospital area. A second pavement lookup
also had to return within 0.75 m of the first. The native promises a safe nearby
point, not repeated point identity. Candidate 13's `pavement_unavailable` after
successful ground/ray checks could mean second-lookup failure, changed XY, or Z
disagreement; its old reason did not distinguish those cases.

The original 2 m check belongs to console/exact-point validation: measured ground
versus the sampled target Z. It is unchanged. Hospital ray/ground agreement stays
0.25 m, and navmesh/ground agreement stays 1 m. No tolerance was increased.

All 13 seeds appeared in the live log, so that attempt does not prove starvation.
But sequential capsule waits could consume 250 ms each after a slow scene load.
The same eight-second deadline now polls outstanding probes fairly.

## Corrected strategy

1. Keep the **32 m hospital XY area** and the same 13 relative seeds. The old XYZ
   is a search/streaming reference, never a certified spawn.
2. Resolve the nearest vehicle-path node with zero vertical ranking weight. Reject
   off-road, switched-off, tunnel/interior, highway and water nodes. Road references
   must be within 32 m of their query and 64 m of the hospital; this does not enlarge
   the permitted recovery area.
3. Request pavement at that street height with pavement/non-isolated/non-interior/
   non-water flags. Judge the returned XY against the hospital area, not the former
   six-metre seed limit. Resolve a road reference at the actual pavement XY too.
4. Query ground at **returned navmesh Z + 1 m**, casting down to navmesh Z - 2.5 m.
   Require ground/ray agreement within 0.25 m, ground/navmesh within 1 m, and
   ground/street reference within 2 m. The street comparison supplies independent
   evidence against a roof; it does not compare against configured center Z.
5. Require road type and slope checks, a clear upward world ray from ground+2.1
   to ground+80, four supported footprint edges, standing-body capsule clearance,
   and no vehicle within 2 m. Covered/tunnel pavement remains rejected. Validate
   the initially returned point directly; do not ask another nearby-point lookup
   to reproduce it.
6. Request every seed's collision before waiting. After scene loading, start all
   eligible clearance probes in one sweep and poll them without blocking on
   earlier pending results. Each probe has 250 ms; the entire attempt has eight
   seconds. Rejected seeds can retry after 100 ms. Late/unavailable streaming still
   fails safely rather than extending the lease.
7. Following a clear capsule result, freshly check ground/ray, road type/grade,
   sky, slope, footprint and vehicles. The scene must be loaded; ground must stay
   within 0.05 m of the capsule's checked floor. No further yield precedes placement.
8. Use the existing shared resurrection block at measured ground+1 (the existing
   ped-origin offset) with configured heading. Collision/unfreeze writes occur
   only after validated resurrection. Failure leaves the corpse unmoved, releases
   owned fade/streaming, preserves death, and permits E retry after lease expiry.

Road references are safety evidence, not claimed safe spawns. Map classifications
and collision availability still depend on the live engine. Missing or unsuitable
references fail closed with explicit reasons. Both live acceptance tests remain
necessary; no Enhanced-specific native bug is claimed proven.

Native contracts:
[road lookup and Z weighting](https://github.com/citizenfx/natives/blob/master/PATHFIND/GetClosestVehicleNode.md),
[road flags](https://github.com/citizenfx/natives/blob/master/PATHFIND/GetVehicleNodeProperties.md),
[pavement lookup](https://github.com/citizenfx/natives/blob/master/PATHFIND/GetSafeCoordForPed.md).

Server logic is unchanged: 30 seconds, explicit E, 20-second lease, death clearing,
Qbox Save, recovery needs, and inventory/cash/bank retention. Its broad arrival
envelope classifies hunger/thirst; it does not select the client destination or
cause the reported navmesh rejection. Employment, reconnect/restart, console
recovery and explicit-point diagnostics remain intact. Existing external-revive
history protection remains tested, including death packets after confirmation.

## One-attempt diagnostics

Keep the recovery start, candidate rejections, search summaries and final result
from client F8. Candidate evidence includes:

- Native road result, flags and query distance, or the exact unavailable native.
- Returned pavement XYZ and XY distances from the hospital and seed.
- Probe endpoints, navmesh Z, street Z, ground, ray status/Z/normal, and all three
  numerical height deltas used by the checks.
- Sky coverage and capsule result/hit/age when reached.
- A summary for each seed with attempt count, last failure evidence and scene-load
  time; pending-at-deadline and never-loaded states are distinguished.

Accepted candidates print actual XY, measured floor and final checks. Optional
alive-observer `medical_survey_hospital` runs identical discovery without moving or
reviving its observer. Four explicit arguments retain the strict point diagnostic.
Neither mode changes config or is required for ordinary civilian recovery.

## Regression coverage

Run `python tests/run-economy-lua.py` and `git diff --check`. All six suites are
required: employment server, world, medical server, medical client, medical surface,
and employment client marker. Medical coverage includes:

- Ground/ray 48.753879547119, center 43.28, XY 298.1172,-585.9902 accepted when
  independent navmesh/street/clearance evidence supports that surface. Mock navmesh
  and street heights complete missing live fields; this does not certify Candidate 1.
- Ray/ground tolerance boundaries; high 89.620208740234 surface rejected against
  street Z 42.357627868652 even when the high navmesh/ray/ground agree.
- Local pavement queried below a roof; covered first candidate rejects and an
  exposed later point succeeds.
- Pavement more than 6 m from its seed accepted inside the unchanged hospital XY
  bound; out-of-area pavement rejected; no repeat-lookup identity assumption.
- Scene loads at 7750 ms, first 12 capsules remain pending, candidate 13 succeeds
  at 7800 ms without extending the attempt or request lease.
- Missing/forbidden road data, ground/ray failures, slope/footprint/coverage/body
  failures, total exhaustion, fresh checks, expired probes, original-position
  retention, retry and post-validation collision/unfreeze.
- External revive cancellation and late packets, countdown, duplicate requests,
  money/items, saving, UI cleanup, reconnect/restart and employment behavior.

These are native mocks. Hospital recovery is not live PASS until both normal
death -> 30 seconds -> E -> hospital -> alive/walking tests succeed.

## Backup-first deployment: operator only

From deployed e36bca6, **client.lua and config.lua are the only changed runtime
files**. Keep its server.lua. In VPS Bash as the runtime owner:

```bash
set -euo pipefail
COMMIT=FULL_COMMIT_HASH_FROM_DELIVERY
cd /opt/randy-2
git fetch origin main
git merge-base --is-ancestor "$COMMIT" origin/main
MEDICAL='/opt/randy-2/runtime/qbox-server-data/resources/[tarrant]/tarrant_medical'
BACKUP="/opt/randy-2/runtime/medical-layer-backup-$(date -u +%Y%m%dT%H%M%SZ)"
umask 077
mkdir -m 700 "$BACKUP"
for f in client.lua config.lua; do
  cp -p "$MEDICAL/$f" "$BACKUP/$f.before"
  git show "$COMMIT:resources/[tarrant]/tarrant_medical/$f" > "$BACKUP/$f.after"
  test -s "$BACKUP/$f.after"
done
printf 'Keep rollback directory: %s\n' "$BACKUP"
```

In **txAdmin server console**: `stop tarrant_medical`. Then in the same Bash session:

```bash
for f in client.lua config.lua; do
  cat "$BACKUP/$f.after" > "$MEDICAL/$f"
  cmp -s "$MEDICAL/$f" "$BACKUP/$f.after"
done
```

In **txAdmin server console**: `ensure tarrant_medical`. No `refresh`, server-wide
restart, private configuration or database edit is needed.

Rollback: stop medical, run the following in the same Bash session, then ensure it.
The backup restores the known e36bca6 failure.

```bash
for f in client.lua config.lua; do
  test -s "$BACKUP/$f.before"
  cat "$BACKUP/$f.before" > "$MEDICAL/$f"
done
```

## Live acceptance: two real players/tests

1. Record items/counts, cash and bank. Tester A dies near the hospital, waits the
   full 30 seconds, and presses E. Early E does nothing; repeated E cannot duplicate
   recovery. Require hospital exterior -> alive -> normal walking.
2. Tester B repeats from a distant location with Pillbox initially unstreamed.
   Require the same complete flow; retain both accepted-candidate F8 lines.
3. For both: no admin assistance, medical_recover_here, NoClip or Heal Myself; no
   sky fall, underground/roof spawn, repeated death, stuck UI or disabled collision.
   Verify items, cash/bank, intended needs and successful save.
4. Reconnect afterward and verify alive state and retained assets. Separately check
   reconnect/restart while dead cannot bypass persistent death/countdown.
5. In staging, obstruct a candidate: require safe fallback or rejection without
   moving the corpse, then retry after lease expiry. Test legitimate external
   revive during preparation: no later re-kill, teleport or stale death UI.
6. Mark hospital PASS only after steps 1-3 succeed for both tests. If anything
   fails, preserve the complete one-attempt diagnostics above. The separate packet
   timeout issue remains out of scope.
