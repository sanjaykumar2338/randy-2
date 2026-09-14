# Phase 2 gameplay/economy baseline

Prepared 2026-09-14. Source implementation is ready for staging; **Jobs: PARTIAL;
Weapon purchasing: PARTIAL; Real estate: PLAN REQUIRED**. No live deployment or
in-game acceptance is claimed. The local runtime differs from Randy's live VPS:
its server.cfg does not start tarrant_world, whereas the user's live baseline does.
Do not copy this workstation's server.cfg over the VPS configuration.

## Current system audit (before implementation)

Inspected local `runtime/qbox-server-data/resources`, startup configuration,
QBX jobs/player exports, OX shops/licenses/QBX bridge, and SQL files. A read-only
`SHOW TABLES` against the local configured database succeeded. No VPS access was used.

* Installed QBX: core, HUD, spawn, vehicles. OX: lib, mysql, target, inventory.
  Appearance, pma-voice, and tarrant_ops are present. No qbx_management, city hall,
  job center, banking UI, or playable garbage/taxi/tow/trucker/bus resource was found.
* Core job definitions include unemployed, police, bcso, sasp, ambulance,
  realestate, taxi, bus, cardealer, mechanic, judge, lawyer, reporter, trucker,
  tow, garbage, vineyard, hotdog. Definitions alone do not provide work activities.
  Core already supplies duty, payroll, job-group persistence, SetJob, AddMoney,
  and Save. Existing payroll remains unchanged and is additional to route pay.
* OX Ammunation already has map blips and both location/target interactions:
  ammo-9 $5 each, knife $200, bat $100, registered pistol $1,000 requiring
  `metadata.licences.weapon`. Built-in license purchase costs $5,000 at
  **12.42198, -1105.82, 29.7854**. It is a paid gameplay license, not an officer
  approval process. The OX client creates the license interaction independently
  of the employment resource. Purchases use inventory money/cash; the QBX bridge
  synchronizes that account. Existing inventory persistence is retained.
* PoliceArmoury has a police group restriction and grade/license restrictions
  on relevant items; no armoury content is added to civilian shops. A separate
  stock BlackMarketArms shop exists using black_money; it is not the legal store
  and remains unchanged. No duplicate weapon or licensing resource is introduced.
* No installed housing resource or disabled housing/job-center package was found.
  The database contains players, player_groups, ox_inventory, player_vehicles,
  bank_accounts_new, player_transactions, player_mails, ox_doorlock, users, bans,
  management_outfits, player_outfits, player_outfit_codes and playerskins.
  There are no houses/properties tables. Banking/doorlock tables do not prove a
  corresponding playable resource is installed. No row contents were exported.

## Implementation and files changed

* `resources/[tarrant]/tarrant_employment/fxmanifest.lua`: isolated opt-in resource.
* `resources/[tarrant]/tarrant_employment/config.lua`: center, stops, pay and timing.
* `resources/[tarrant]/tarrant_employment/client.lua`: employment map blip,
  E interaction, job menu, route guidance, progress, cancellation and gun/license directions.
* `resources/[tarrant]/tarrant_employment/server.lua`: civilian allowlist,
  server-side position/duty/health/character/timing validation, payments and saves.
* `config/economy.example.cfg`: optional startup fragment.
* `tests/check-tarrant-employment.lua`: server behavior regression tests.
* `tests/run-economy-lua.py`: isolated Lua test runner.
* This report.

At **195, -933, 30.7**, the Tarrant County Employment Center offers sanitation
(garbage), local parcels (trucker), and bus-stop inspection (bus). These are
explicitly simple on-foot assignments, not full vehicle-based job packs. Each has
two stops, a 13-second client action per stop (server minimum 12 seconds), and
$90 cash after the whole route. No vehicles, tools, deposits, or client-selected
amounts are used. Appointed jobs cannot be replaced here. Only grade zero is
assigned. Core job capacity and SetJob replacement policy continue to apply.

Players start/restart at the center and can end duty there. A route expires after
30 minutes. Reconnect, character change or resource restart discards unpaid work;
the QBX job and already-earned money use existing persistence. Save requests are
asynchronous in QBX: successful API calls do not prove database durability.
Validation prevents basic replay, remote completion and invalid job grants; it
does not substitute for server-wide anti-teleport/anti-cheat protection.

**Dependencies:** existing qbx_core, ox_lib, OneSync; the existing QBX/OX cash
bridge requires ox_inventory running. No downloaded gameplay dependencies.
Tests use Lua 5.4 via test-only `lupa==2.8` in an ignored directory.
**Database changes:** none; no migrations, seeds, resets or direct player writes.
World placements, plates, framework versions, private configs and infrastructure
are untouched. Coordinates still require Enhanced in-game ground/access checks.

## Real estate recommendation

Use a separate staging evaluation of the official
[qbx_properties repository](https://github.com/Qbox-project/qbx_properties) first.
It is free source under GPL-3.0; preserve its license and meet applicable source
distribution obligations. Verify licenses of any separately acquired shells/MLOs.
This is a candidate, not an assertion of production readiness. Its README lists
realtor, garage and MLO work as unfinished, so automatic installation is unsuitable.

The [manifest](https://github.com/Qbox-project/qbx_properties/blob/main/fxmanifest.lua)
loads QBX, ox_lib and oxmysql; property code also calls ox_inventory. Retain
qbx_spawn and assess appearance/interior and garage integrations at a pinned
commit. Do not run a fresh Qbox recipe. Inspect the selected revision's full
dependencies before installation; no complete dependency lock is claimed here.

| Capability | Candidate assessment / acceptance gate |
| --- | --- |
| Ownership and purchase | Implemented in [server code](https://github.com/Qbox-project/qbx_properties/blob/main/server/property.lua); test concurrent buyers and payment/ownership atomicity before adoption. |
| Sale/transfer | Must verify authorized resale and consistent payment; not accepted from the current audit. |
| Keys/access | Keyholder data exists; test invite/revoke, reconnect and unauthorized entry. |
| Stash | OX stash integration exists; test owner/keyholder isolation and revoked access. |
| Garages | Integration code exists, but README lists unfinished work; select/test a compatible garage dependency separately. |
| Realtor-managed homes/businesses | README still flags realtor work; not accepted. Require server-side role checks and separate business permissions. |
| Persistence | SQL-backed ownership/keyholders/stash settings exist; verify restart and spawn behavior in a disposable staging DB. |

Next milestone: pin and review a revision, enumerate exact dependencies/licenses,
review migrations and purchase transactions, back up staging, then add two
unoccupied test parcels. Exercise purchase, failed purchase, concurrent purchase,
resale, keys, stash, reconnect, restart and garage access. Survey home/business
locations separately without editing existing Arlington/restaurant placements.
If that candidate fails these gates, compare licensed supported alternatives
before selecting or purchasing one. No property can be acquired in this delivery.

## Tests and limitations

Run from the repository root:

```powershell
python -m pip install --target runtime/economy-test-tools lupa==2.8
python tests/run-economy-lua.py
Get-ChildItem tests -Filter '*.ps1' | ForEach-Object {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $_.FullName
    if ($LASTEXITCODE -ne 0) { Write-Warning "Failed: $($_.Name)" }
}
& 'C:\Program Files\Git\bin\bash.exe' -c 'for test in tests/*.sh; do bash "$test" || exit; done'
```

Employment unit tests cover all three routes, timing, cash amount, save calls,
invalid/privileged jobs, remote calls, bucket/death/duty/character validation,
replay, disconnect, expiry, end shift and rejected payment. World regression
covers existing registry/rendering behavior. These use mocks, not game clients.

Existing health-log regression invokes live network/service checks even for its
synthetic log fixture. On this machine it fails because FXServer :30120 and
txAdmin :40120 are stopped/unreachable; MariaDB is running/private and the latest
stored tarrant_ops startup event passes. Do not treat an old log as current
runtime acceptance. Do not start/reconfigure a live server just to hide that test
failure. No Phase 1 health behavior is changed. Run it again on the authorized
staging runtime. Linux symlink assertion is skipped on this Windows host.

In-game spawn, cash/bank and inventory persistence, actual purchase deductions,
resource startup/console errors, locations and two-client behavior remain pending.
The repository delivery is complete only as a staging candidate, not a fully
accepted live milestone.

Results on 2026-09-14: employment and world Lua tests PASS; Linux artifact,
PowerShell public-listing and runtime-dependency tests PASS; all three Bash test
scripts PASS (Windows symlink check skipped); health-log fixture FAIL for the
stopped runtime dependency described above. `git diff --check` PASS.

## Deployment commands (operator only, after separate approval)

These commands are prepared, **not executed**. The documented VPS checkout is
`/opt/randy-2`; verify it matches the target environment first. Stop if another
employment/job pack is already installed there; the local audit is not a live audit.
First deployment refuses an existing destination so rollback cannot overwrite it.
Use the commit reported with this delivery for REVIEWED_COMMIT.

```bash
set -euo pipefail
cd /opt/randy-2
test -z "$(git status --porcelain)"
git pull --ff-only origin main
REVIEWED_COMMIT=$(git --literal-pathspecs log -1 --format=%H -- 'resources/[tarrant]/tarrant_employment')
git show --stat "$REVIEWED_COMMIT"
# Check the displayed hash equals the delivered commit before continuing.
DATA=/opt/randy-2/runtime/qbox-server-data
DEST="$DATA/resources/[tarrant]/tarrant_employment"
test -f "$DATA/server.cfg"
test ! -e "$DEST"
test ! -e "$DATA/economy.cfg"
! grep -Eq '^[[:space:]]*(exec[[:space:]]+economy.cfg|ensure[[:space:]]+tarrant_employment)' "$DATA/server.cfg"
git --literal-pathspecs archive "$REVIEWED_COMMIT" 'resources/[tarrant]/tarrant_employment' | tar -x -C "$DATA"
git show "$REVIEWED_COMMIT:config/economy.example.cfg" > "$DATA/economy.cfg"
printf '\n# Phase 2 civilian employment\nexec economy.cfg\n' >> "$DATA/server.cfg"
```

Run these in FXServer/txAdmin **server console**, not Bash:

```text
refresh
ensure tarrant_employment
```

QBX/OX must already be running. Inspect console for startup errors and run the
player checklist below; no whole-server/framework restart is required. Do not
run installers, import schemas, replace ox shops or copy workstation secrets.

## Exact rollback

In server console: `stop tarrant_employment`. Then, in Bash:

```bash
DATA=/opt/randy-2/runtime/qbox-server-data
printf '# Employment disabled after rollback\n' > "$DATA/economy.cfg"
```

Keep the inert source directory and harmless `exec economy.cfg` include, preserving
any unrelated server.cfg edits. No DB restore is needed. Earned cash and selected
QBX jobs remain; do not reset player data. Players may go off duty before stopping
the resource. Rollback does not cancel core's pre-existing payroll or remove jobs.
Re-enable only after approval by restoring the reviewed economy fragment and
`ensure tarrant_employment`. Do not force-push or reset the shared branch.

## Randy testing checklist

1. Connect as a normal civilian; verify character, HUD, chat, voice, inventory,
   cash/bank, tarrant_world and approved restaurant are unchanged.
2. Find Employment Center on the map at City Hall. Press E; confirm only the
   three listed assignments appear. Select one and follow the routed blip.
3. Finish both stops; verify exactly $90 added to cash (allow separately logged
   core payroll). Cancel an action: no payment. Repeat for each assignment.
4. Reconnect: job and earned cash remain; start a fresh route at the center.
   End shift there and verify off duty. A police/EMS character cannot switch here.
5. At Ammunation near 22.56, -1109.89, 29.80, buy ammo/bat with earned cash;
   confirm quantity, exact deduction and insufficient-funds rejection.
6. With no weapon license, pistol must be rejected. Use the existing license
   point at 12.42198, -1105.82, 29.7854 (E) with $5,000 cash. Verify deduction,
   then buy the $1,000 pistol. No free money/admin grants are part of acceptance.
7. Reconnect: verify weapon, ammunition, remaining cash and license persist.
   Civilian shop must not sell police rifle/stungun; police armoury must reject
   civilians. Do not confuse the separate black market with the legal store.
8. Operator checks current tarrant_ops readiness, DB connectivity and fresh
   server/client errors. Restart only employment to test cleanup, then perform
   a scheduled authorized server restart to verify persistence.
9. Record each PASS/FAIL with timestamp and expected/actual amounts. Housing
   remains PLAN REQUIRED until its separate resource decision and staging tests.
