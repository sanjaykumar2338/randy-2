# Validated operator recovery after the NoClip/heal failure

> Follow-up after the fce08aa live rejection: use [medical-pavement-survey.md](medical-pavement-survey.md)
> for read-only survey, mode diagnostics and the latest one-file deployment.

## Diagnosis and limits

Live baseline is **201c1b1280896708c275398d697c2283dd2eb17d**, not c8aee714.
In that baseline, hospital recovery teleports the dead ped before validating the
hospital surface. A rejection leaves the ped there. This is the confirmed medical
coordinate defect fixed by c8aee71; this delivery includes that client fix.

The locally inspected txAdmin bundle is enhanced-129-test, not a verified copy of
the VPS b156 bundle. Its `resource/menu/client/cl_base.lua` txcl:heal handler
resurrects at GetEntityCoords(ped), with no ground validation. Its cl_player_mode.lua
NoClip handler manages freeze, visibility, invincibility and freecam independently.
Medical's old transfer/cleanup paths unconditionally unfreeze the ped, so overlapping
medical transfer and NoClip can release a freeze belonging to txAdmin. Medical does
not perform that unfreeze on every ordinary external revive: moving must be true.
There is no live coordinate/timing trace proving that overlap happened in this test.
Neither an invented txAdmin height offset nor a particular b156 terrain bug is proven.

Medical's server polls native health every 500 ms. Once it has observed death, an
alive ped clears persisted tarrantRecovery/isdead and death state bags regardless
of location (external revives are allowed). A later fall death starts a new session
and countdown. If the entire alive interval falls between polls it retains the old
session instead. The client remembers observed death to avoid killing a revived
ped on a delayed status update; a fresh login/restart alive ped still cannot bypass
persisted death. This is health reconciliation, not safe-placement validation.

The precise confirmed failure is that an external heal has no safe-surface contract,
while medical previously both moved before validation and wrote shared freeze state.
The reported fall is consistent with revival at airborne ped coordinates. Its exact
height/source cannot be reconstructed from the report alone.

## Scoped change

Medical no longer writes FreezeEntityPosition at all. Destination preparation keeps
the dead ped where it is and rejects frozen/in-vehicle conditions, including a change
during preparation. It retains bounded scene, ground, world-ray, slope and vehicle
checks from c8aee71. Resurrection resets velocity to prevent inherited falling speed.

`medical_recover_here <server ID>` is **server-console only** (source must be zero).
It requires an online dead character in bucket zero and no active transfer lease.
It authorizes one bounded attempt at the current ped location, with no client-supplied
server command coordinates. Ground must be within 2 m, collision must agree, and
movement exceeding 0.5 m during preparation rejects the attempt. Failure leaves death
metadata intact and permits another attempt after the 20-second lease. Success uses
the existing health reconciliation/save path and restores minimum needs to prevent
immediate starvation. Items/money and employment logic are untouched.

This is an explicit operator exception; normal civilian recovery retains the
30-second countdown, explicit E, hospital destination, persistence and retry rules.
No hospital coordinate is guessed or changed in this delivery.

## Backup-first deployment (operator only)

Use the full delivered hash as REVIEWED_COMMIT. These commands fetch source without
merging or copying any other resource. Run Bash as the existing runtime owner:

```bash
set -euo pipefail
export REVIEWED_COMMIT=FULL_COMMIT_HASH_FROM_DELIVERY
cd /opt/randy-2
git fetch origin main
git merge-base --is-ancestor "$REVIEWED_COMMIT" origin/main
MEDICAL='/opt/randy-2/runtime/qbox-server-data/resources/[tarrant]/tarrant_medical'
BACKUP="/opt/randy-2/runtime/medical-rescue-backup-$(date -u +%Y%m%dT%H%M%SZ)"
umask 077
mkdir -m 700 "$BACKUP"
for f in client.lua server.lua; do
  test -f "$MEDICAL/$f"
  cp -p "$MEDICAL/$f" "$BACKUP/$f.before"
  git show "$REVIEWED_COMMIT:resources/[tarrant]/tarrant_medical/$f" > "$BACKUP/$f.after"
  test -s "$BACKUP/$f.after"
done
printf 'Keep this rollback directory: %s\n' "$BACKUP"
```

In txAdmin **server console**: `stop tarrant_medical`.
Then in the same Bash session:

```bash
for f in client.lua server.lua; do
  cat "$BACKUP/$f.after" > "$MEDICAL/$f"
  cmp -s "$MEDICAL/$f" "$BACKUP/$f.after"
done
```

In server console: `ensure tarrant_medical`.
Only these two runtime files are replaced, including c8aee71 client changes missing
from the live baseline. Private config and all other resources remain untouched.
Rollback: stop medical, run the following in the same Bash session, then ensure it.
This restores the previous known hospital defect, so restrict testing accordingly.

```bash
for f in client.lua server.lua; do
  test -s "$BACKUP/$f.before"
  cat "$BACKUP/$f.before" > "$MEDICAL/$f"
done
```

## Recover the character and measure pavement

1. After deployment, stay logged into the affected character. Record cash, bank and
   inventory. Do not press E during positioning and do not use Heal: Myself.
2. Use NoClip only to move the dead character close to visibly rendered, level,
   open exterior hospital pavement. Avoid canopy/interior, road traffic, steps,
   vehicles and walls. Lower close to the pavement before exiting NoClip.
3. Set txAdmin Player Mode to Normal, remove any separate admin freeze, close the
   menu, and let the dead body settle. Do not run recovery while hovering, falling
   or in a vehicle. Wait at least 20 seconds after any earlier recovery attempt.
4. In the **server console**, run `medical_recover_here ID`, replacing ID with the
   affected player's current numeric server ID (not citizen ID). Do not type this
   in client F8 or chat. No metadata/database edits are needed.
5. On rejection, retain the F8 diagnostic. Death must remain persisted. Correct
   positioning and retry after 20 seconds; do not substitute an unvalidated heal.
6. On success, save the F8 line `Validated recovery surface: x, y, groundZ, heading`.
   Confirm normal walking on that exact pavement, no fall, usable inventory/camera,
   cleared recovery UI and retained items/money. Reconnect and confirm still alive.
7. Face the desired hospital arrival direction and use txAdmin Copy current
   coordinates while standing normally. Supply that output together with the F8
   ground measurement and a description of the pavement location. Ped Z and surface
   Z are different measurements. If you walk to a different spot, the earlier F8
   measurement does not certify it. A visual check is required: geometry tests cannot
   identify a hospital or certify public pedestrian access.

The coordinate remains pending this live measurement; do not declare the old
300.8, -585.6, 43.28 candidate accepted. Update config only after reviewing the
measured location, then test normal hospital recovery there.

## Live acceptance checklist

- Frozen/NoClip or vehicle attempts refuse without movement, resurrection or an
  unfreeze. A bad/airborne surface refuses and preserves death across reconnect.
- Successful console rescue prints the measured ground, clears persisted death,
  stays alive after reconnect, and retains items/cash/bank. Movement is normal.
- Normal death still waits 30 seconds and requires E. Employment work cancels as
  before, with no death payment or changed job handling.
- Failed normal hospital validation preserves the original death position, releases
  medical fade/focus, and retries after the lease without restarting the countdown.
- Restart medical/reconnect while dead preserves the deadline and enforced death.
- With a subsequently measured hospital config, test nearby and distant deaths:
  one safe pavement arrival per E request, no fall/re-kill and items/money retained.
- Any external revive already observed during preparation cancels that transfer
  without another teleport or freeze change. Do not repeat the failed NoClip/heal
  combination on this test character.

## Regression evidence

`python tests/run-economy-lua.py`: all six suites pass. New checks cover console-only
rescue authorization, duplicate/expired lease, failed rescue persistence, successful
completion away from the configured hospital, local-event rejection, frozen/vehicle
refusal, movement/airborne rejection and absence of medical freeze writes. Existing
countdown, E, external revive, reconnect/restart, surface preparation, money/items,
employment and world checks remain passing. These use native mocks; live b156
placement and the actual hospital pavement still require the checklist above.
