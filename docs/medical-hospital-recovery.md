# Hospital recovery: code ready, exterior coordinate still unaccepted

> Historical single-point diagnosis. Current runtime discovery, deployment and
> acceptance: [medical-hospital-discovery.md](medical-hospital-discovery.md).
> Manual coordinate surveying is no longer a prerequisite for E recovery.

This is the current follow-up to live commit
`47e546e4299d2d4660f6b216306b026e3f07e9c4`. It supersedes the deployment and
coordinate-survey instructions in the earlier medical documents.

## A. Code-side diagnosis and changes

Live evidence from two players confirms death detection, the 30-second countdown
and E prompt. Normal hospital recovery fails with `mode=hospital`,
`reason=ground_z_mismatch`, target `300.8,-585.6,43.28`. Console
`medical_recover_here 1` succeeds at a separately validated local surface, restores
walking and saves. This establishes that resurrection/reconciliation can work;
it does not validate the hospital destination.

The exact failing branch requires a loaded destination scene, a successful ground
query, and `abs(ground - configuredZ) <= 2.0`. The reported reason means the first
two conditions passed and the last did not. The old code never ran its collision
ray after that mismatch. Consequently the evidence cannot establish whether this
is a physically unsuitable coordinate, a native ground/collision disagreement, or
incomplete destination streaming on Enhanced. No exterior walkable pavement at
the configured point has been demonstrated. The old ground measurement near
16.7569 and dead/underground coordinates are not replacement spawn measurements.

The client already loads a destination scene and sets render focus without moving
the dead ped. This remains necessary: Cfx documents that the
[ground query requires client render range](https://github.com/citizenfx/natives/blob/master/MISC/GetGroundZFor_3dCoord.md).
This change:

- Shares the existing scene/surface validator between recovery and a new read-only
  `medical_survey_hospital` command. There is no alternate recovery destination
  supplied by a player and no config-writing command.
- Always records an independent world ray when sampling the destination, even
  when ground disagrees. Logs include ground-found/Z, ray status/hit/Z and normal.
  Ray values are used only for a completed hit, consistent with the
  [native contract](https://github.com/citizenfx/natives/blob/master/SHAPETEST/GetShapeTestResult.md).
- Rechecks scene and surface after the final 50 ms yield. Previously a successful
  sample could become stale before resurrection, for example when a vehicle
  arrived during that yield. No yield separates this final check and placement.
- Cancels recovery if the player ped changes during preparation.
- Keeps the original 2 m target-Z limit, 0.25 m ray/ground agreement, normal-Z
  minimum 0.9, 2 m vehicle exclusion and 8-second streaming timeout. There is no
  ray-only, configured-height or underground-height fallback.

`NetworkResurrectLocalPlayer` remains the first operation that moves the player,
at validated `ground + 1.0`. Velocity is cleared, health/tasks/stamina/control are
restored, then owned streaming focus/scene and fade are released. Medical does not
freeze or unfreeze the ped; foreign freeze/vehicle state rejects recovery. Failed
validation never changes ped coordinates or health, clears death, or saves a
successful recovery. Natural corpse physics are not disabled.

Server behavior is unchanged: 30-second deadline, 20-second exclusive request
lease, bucket 0, native-health reconciliation, death metadata/state cleanup,
minimum hunger/thirst recovery and `exports.qbx_core:Save(src)`. The inspected
local Qbox resource exports that Save function. On validation failure, the lease
expires before the next E attempt; death/deadline persist. External revive still
aborts relocation and clears death through reconciliation. Reconnect/restart
continue to reconstruct death state; employment integration and retained
items/cash/bank are unchanged. The intermittent disconnect issue is out of scope.

## B. Coordinate requiring live survey

**Normal hospital recovery is NOT live accepted.** The operator confirms there
are no repeated alive exterior survey measurements. Config retains the rejected
candidate solely because there is no justified replacement; its comment now
explicitly marks it unaccepted. Deploying this code alone does not repair that
coordinate or promise a successful E recovery.

Use an already-alive operator to obtain evidence. No rescue, NoClip, heal,
database edit or reconnect is part of the eventual civilian recovery flow.

1. Walk normally onto open, level Pillbox Medical exterior pedestrian pavement.
   Avoid interiors, roofs, drainage channels, stairs, doors, canopy, traffic and
   props. Confirm ordinary walking and visible clearance. Describe the exact
   spot and face the intended arrival direction.
2. Stand still, alive, outside vehicles and with NoClip/freeze disabled. In client
   F8 run `medical_survey_here` three times at least one second apart. Keep all
   full lines. Require stable ped coordinates/heading, `aliveCandidate=true`,
   `collision=true`, agreeing ground/ray heights, no nearby vehicle, and no
   freeze/death. These remain snapshots; visual inspection and stable standing
   are operator checks, not something the flag certifies.
3. From another alive observer well away from the hospital, or after walking away
   normally, run in F8:

   ```text
   medical_survey_hospital <measuredPedX> <measuredPedY> <measuredPedZ> <heading>
   ```

   Substitute all four measured numbers, without angle brackets. Keep standing
   ped Z and measured ground Z distinct. The command uses the production remote
   scene/ground/ray validator, waits up to 8 seconds, and reports
   `remoteGeometryValid`, reason and geometry. It changes only temporary streaming
   focus/scene, releases them afterward, and never changes health, position,
   freeze, fade, config, inventory, money or server recovery authorization.
4. Repeat from nearby and distant positions. Require `remoteGeometryValid=true`
   together with the local/visual evidence. With **no arguments**,
   `medical_survey_hospital` tests the currently configured hospital; use this to
   capture ground/ray disagreement at the rejected point without dying or moving
   anyone there. Dead/recovering observers and overlapping surveys are refused.
5. Supply the complete local/remote logs and exterior description for a reviewed
   config change. If they disagree, retain the rejection; do not widen tolerance
   or promote either height on its own. Config must be identical on server/client
   for arrival reconciliation. After installing the measured config, run the
   complete acceptance procedure below. Survey success alone is not acceptance.

## Backup-first VPS deployment (operator only)

The coding agent has not deployed this change. Run as the existing runtime owner
in VPS Bash, substituting the full delivered commit hash. Only medical client
and config are copied; config changes comments only in this delivery.

```bash
set -euo pipefail
export REVIEWED_COMMIT=FULL_COMMIT_HASH_FROM_DELIVERY
cd /opt/randy-2
git fetch origin main
git merge-base --is-ancestor "$REVIEWED_COMMIT" origin/main
MEDICAL='/opt/randy-2/runtime/qbox-server-data/resources/[tarrant]/tarrant_medical'
BACKUP="/opt/randy-2/runtime/medical-hospital-backup-$(date -u +%Y%m%dT%H%M%SZ)"
umask 077
mkdir -m 700 "$BACKUP"
for f in client.lua config.lua; do
  test -f "$MEDICAL/$f"
  cp -p "$MEDICAL/$f" "$BACKUP/$f.before"
  git show "$REVIEWED_COMMIT:resources/[tarrant]/tarrant_medical/$f" > "$BACKUP/$f.after"
  test -s "$BACKUP/$f.after"
done
printf 'Keep rollback directory: %s\n' "$BACKUP"
```

During a maintenance window, in **server console**: `stop tarrant_medical`.
Then in the same Bash session:

```bash
for f in client.lua config.lua; do
  cat "$BACKUP/$f.after" > "$MEDICAL/$f"
  cmp -s "$MEDICAL/$f" "$BACKUP/$f.after"
done
```

In **server console**: `ensure tarrant_medical`. This briefly interrupts medical
UI and requests while persistent death remains authoritative. No source merge,
private config, upstream resource or database modification is required.

Rollback: stop medical, run the following in the same Bash session, then ensure
medical. The backup has the already-known hospital failure.

```bash
for f in client.lua config.lua; do
  test -s "$BACKUP/$f.before"
  cat "$BACKUP/$f.before" > "$MEDICAL/$f"
done
```

## Exact live acceptance steps

First deploy the code and capture the survey evidence above. Until a measured
replacement config is reviewed and installed, only rejection/diagnostic checks
can be accepted; do not repeatedly kill players expecting the old point to work.

After the measured config is installed:

1. With both original testers, separately record items/counts, cash and bank.
   Die normally near the hospital. Confirm death detection, 30-second countdown,
   no automatic respawn, and E before zero does nothing.
2. At zero confirm `[E] Recover at Arlington Memorial Hospital (items and money
   retained)`. Press E and try repeated presses during preparation. Require one
   recovery to the measured hospital pavement: alive, on solid ground, no fall,
   normal walking/camera/control, cleared death UI and usable inventory. No admin
   action, heal, NoClip, reconnect or database edit may assist this recovery.
3. Verify unchanged items/cash/bank, minimum recovery hunger/thirst, cleared
   `isdead`, `inlaststand`, `tarrantRecovery`, `dead`, `isDead`, `medicalRecovery`
   through existing read-only inspection, and completed Qbox/inventory save.
   Reconnect **after** the successful acceptance flow to verify it stayed saved.
4. Repeat from a distant area where Pillbox is initially unstreamed, with each
   tester. Confirm the same safe destination and behavior. Survey success and
   `medical_recover_here` success cannot substitute for these E tests.
5. In a controlled test, block the measured arrival with a vehicle. Die elsewhere
   and press E after countdown. Require rejection with no medical relocation or
   revive, original death location retained, fade restored and no foreign freeze
   changed. Items/money/death persist. Remove the obstruction, wait until the
   original 20-second lease expires, then press E: one successful recovery and no
   restarted 30-second countdown. Do not change config to underground coordinates
   just to force a failure.
6. In staging, restart medical during preparation and reconnect while dead.
   Require safe cleanup, retained death/deadline and no free revive. Retry E when
   permitted. Test an existing external revive during preparation: it must cancel
   hospital relocation, clear medical state/UI and avoid a second revive/re-kill.
7. Confirm death still cancels unfinished employment work without extra payment,
   and that subsequent work follows existing job behavior. Record both testers'
   results and F8/server evidence. Mark hospital PASS only when steps 1–4 succeed
   on the live Enhanced server without assistance.

## Automated regression evidence

Run `python tests/run-economy-lua.py` and `git diff --check` from repo root. The
runner includes all three medical suites plus employment, world and marker
coverage. Native mocks test behavior, not live Enhanced geometry.

| Required behavior | Coverage |
| --- | --- |
| Death detection, 30 seconds, early denial, explicit E | medical server/client |
| Invalid destination never moves/revives; original position retained | medical surface |
| Valid destination revives at validated ground + 1; normal unfrozen state | medical surface/client |
| Metadata/state/UI cleared, Save once, items/cash/bank retained | medical server/client |
| Duplicate input/request exclusion, lease expiry and retry | all medical suites |
| Reconnect, restart, unload, foreign freeze, external revive | all medical suites |
| Ground mismatch logs independent ray; no height fallback | medical surface |
| Vehicle/ground/collision/scene changes after final yield reject | medical surface |
| Remote candidate survey is read-only, bounded and cleans up | medical surface |

The final revalidation is a code fix ready for use. The hospital exterior
coordinate and normal live recovery acceptance remain outstanding.
