# Phase 2 final local predeployment record

2026-09-10. Source ready for development testing; **LIVE ENVIRONMENT VALIDATION
REQUIRED**. Sanjay owns deployment and visual acceptance. No VPS connection,
live restart, artifact change, vendor edit or Milestone 2 implementation occurred.

## Final delivery

| Location | Reference X, Y, Z | Final state / default label |
| --- | --- | --- |
| APD / Mission Row | 434.7, -981.9, 30.7 | Enabled; Arlington Police Department |
| Hospital / Pillbox | 298.6, -584.4, 43.3 | Enabled; Arlington Memorial Hospital |
| City Hall / Legion Square | 195.0, -933.0, 30.7 | Enabled; Arlington City Hall; plaza placeholder, building pending |
| Fire Station 1 / Davis | 200.1, -1634.3, 29.8 | Enabled; Arlington Fire Station 1 |
| Stadium / Maze Bank Arena | -250.5, -2030.0, 30.1 | Enabled; Arlington Stadium |
| Whataburger / Highlands analogue | -170, -1710, 29 | Enabled for survey; Texas Burger Grill |
| Dairy Queen / Parks corridor analogue | 100, -1400, 29 | Enabled for survey; Prairie Ice Cream and Grill |

All seven have blips, proximity reference markers and labels. All coordinates
need visual acceptance. Both restaurants explicitly display **PROVISIONAL -
MANUAL GAME SURVEY REQUIRED** nearby. Their references are about 411 m apart;
finite, distinct coordinates are technically valid for drawing, but ground,
access and actual building suitability are unverified. These draws create no
entities or collision and cannot obstruct traffic. They add no restaurant jobs,
menus, interiors, transactions or other Phase 1 integration.

Global branding stays fictional. Both restaurants explicitly override it with
fictional mode. Their per-entry `branding_mode = 'real'` selects Whataburger or
Dairy Queen text for internal testing. Hospital and stadium real-mode text is
Texas Health Arlington Memorial Hospital and AT&T Stadium. APD, City Hall and
Fire names are identical in both modes. No official logos, textures, menu art,
models or trade dress are supplied. Physical brand representation remains deferred.

The central registry supports future categories/sites through the same client
logic. No dependencies, server scripts/threads, network events, secrets, database
access or framework mutation exist. Client startup creates each enabled blip
once; stop removes owned blips and clears their handles, including repeated
cleanup. Other resource stop events do nothing. Markers/text are frame-local.
The loop waits 750 ms at distance, uses frame ticks only within 20 m to draw,
and exits when all locations are disabled. Labels appear within 3 m. Disable
`blip.enabled` independently when another resource owns that service blip.

Texas plates: **NOT VISUALLY IMPLEMENTED / BLOCKED**. Number generation,
uniqueness, registration, owned vehicle persistence and DB values are untouched.
See the [exact persistence audit, method comparison and next asset/conversion
step](../resources/%5Btarrant%5D/tarrant_world/data/plate-preparation.md).
Zero streamed assets or artwork were added. Script review introduces no new
binary compatibility requirement; Enhanced Linux b139 rendering is untested.

## Automated evidence

- Lua 5.4 through Lupa 2.8 in ignored `runtime/phase2-test-tools`: PASS. Compiles
  manifest/config/client and checks schema, seven unique IDs, required metadata,
  finite/distinct coordinates, blip settings, fictional/real overrides, shipped
  seven-site behavior, disabled entries, independent blip disable, distance ticks,
  other-resource stop isolation and repeated cleanup. Natives are mocked.
- `tests/check-runtime-environment-isolation.sh`: PASS.
- `tests/check-public-listing-config.sh`: PASS.
- `tests/check-linux-hosted-deployment.sh`: PASS; actual Linux symlink assertion
  skipped on Windows, rerun on Linux.
- `tests/check-linux-artifact-install.ps1`: PASS.
- `tests/check-public-listing-config.ps1`: PASS.
- `tests/check-runtime-dependencies.ps1`: PASS.
- `tests/check-week2-health-log.ps1`: fails `fields-first-success`, matching the
  pre-existing live-dependent limitation. **LIVE ENVIRONMENT VALIDATION REQUIRED**;
  not a passing regression or a newly introduced code failure.
- Startup audit: installer copies project resources into ignored
  `runtime/qbox-server-data/resources/[tarrant]`; world activation remains opt-in
  through `config/world.example.cfg`. No server template change is needed.
- Tracked private-path review: only `.env.example` and `.env.staging.example`,
  no real `.env`/private runtime config tracked. Diff whitespace check passes.

Reproduce world tests from repository root with `lua5.4 tests/check-tarrant-world.lua`.
The seven existing regression commands are `bash tests/<name>.sh` and
`powershell -NoProfile -ExecutionPolicy Bypass -File tests/<name>.ps1` as listed above.

## Exact operator deployment

Use the repository owner account. Confirm txAdmin's active server-data directory
is `/opt/randy-2/runtime/qbox-server-data`; if different, resolve that discrepancy
before these commands. Review live resource inventory for competing blips/maps.
Do not rerun the full Qbox installer or copy a server template over private config.

If world is already running, first use txAdmin **server console**:

```text
stop tarrant_world
```

Then VPS Bash (backs up an existing world installation, also supports first install):

```bash
set -euo pipefail
cd /opt/randy-2
git status --short
test -z "$(git status --porcelain)"
test "$(git branch --show-current)" = main
git pull --ff-only origin main
git log -1 --format='%H %s'
DATA=/opt/randy-2/runtime/qbox-server-data
BACKUP=/opt/randy-2/runtime/phase2-predeployment-backup
test -f "$DATA/server.cfg"
test ! -e "$BACKUP"
test ! -L "$DATA/resources/[tarrant]/tarrant_world"
test ! -L "$DATA/world.cfg"
mkdir -m 700 "$BACKUP"
cp -p "$DATA/server.cfg" "$BACKUP/server.cfg"
if test -e "$DATA/world.cfg"; then cp -p "$DATA/world.cfg" "$BACKUP/world.cfg"; fi
mkdir -p "$DATA/resources/[tarrant]"
if test -d "$DATA/resources/[tarrant]/tarrant_world"; then
  mv "$DATA/resources/[tarrant]/tarrant_world" "$BACKUP/tarrant_world"
fi
cp -a 'resources/[tarrant]/tarrant_world' "$DATA/resources/[tarrant]/tarrant_world"
cp config/world.example.cfg "$DATA/world.cfg"
if ! grep -Eq '^[[:space:]]*exec[[:space:]]+world\.cfg[[:space:]]*([#;].*)?$' "$DATA/server.cfg"; then
  printf '\n# Phase 2 identity overlay\nexec world.cfg\n' >> "$DATA/server.cfg"
fi
diff -r 'resources/[tarrant]/tarrant_world' "$DATA/resources/[tarrant]/tarrant_world"
```

The fixed backup path intentionally refuses repeat deployment; retain it until
acceptance and choose a new dated backup for any subsequent release. It can
contain private server settings: keep it on the host, never commit/share it.
Review any prior world customization in the backup before activation.

txAdmin/FiveM **server console**, not SSH Bash or client F8:

```text
refresh
ensure tarrant_world
```

**No full server restart required.** The startup include applies at the next
normal restart; `ensure` activates now. To reload a running world after a later
reviewed config update use `restart tarrant_world`. Never restart Phase 1 resources
merely to activate this overlay. No command touches the Enhanced b139 artifact.

## Sanjay's in-game checklist

- [ ] Record build, deployment commit, live resource inventory and overlay-off
  client/server frame time/resmon. Confirm normal server startup at the next
  scheduled start, world starts, and no new server/F8 errors or resource warnings.
- [ ] Character loads; movement, HUD, inventory, chat and voice work. Money/bank
  and inventory survive reconnect; compare with the Phase 1 baseline.
- [ ] Visit all seven table coordinates. Verify APD/hospital names, reasonable
  City Hall/fire/stadium reference sites, readable labels, no duplicate blips,
  no underground/floating markers or inaccessible geometry; check day/night/rain.
- [ ] Survey both restaurants for distinct logical catchments, road/parking and
  pedestrian access, collision and existing-business conflicts. Record corrected
  coordinates/screenshots. Do not claim any GTA building visually matches a brand.
- [ ] Drive between sites, reconnect/cold-cache join and compare FPS/stutter/resmon.
- [ ] Spawn/test several vehicles and retrieve an owned vehicle. Existing exact
  plate strings must still display and persist through garage storage/reconnect.
  Texas texture acceptance is NOT APPLICABLE in this build; if implemented later,
  also check all styles, no missing/purple texture and no Enhanced rendering fault.
- [ ] Server console `stop tarrant_world`: all its blips, labels and markers vanish.
  `ensure tarrant_world`: each returns once only. Repeat and verify Phase 1 remains
  healthy. Check coexistence with service blips owned by other resources.
- [ ] Two players load simultaneously, each sees one overlay, with no resource
  errors; repeat proximity/reconnect and vehicle checks independently.
- [ ] Run `bash tests/check-linux-hosted-deployment.sh` on Linux and the existing
  `bash scripts/check-qbox-readiness.sh` with the host's configured environment.
  Confirm live DB readiness, `tarrant_ops` startup readiness and txAdmin health.
  Run the PowerShell health-log regression in a configured live Windows test
  environment; no claim it can execute natively on the Linux VPS.
- [ ] Record observed results and Randy/Sanjay acceptance. Every visual, gameplay,
  performance, persistence and two-client checkbox remains pending locally.

## Exact rollback

Immediate server console:

```text
stop tarrant_world
```

Restore the previous installed overlay if one existed (same fixed backup as above):

```bash
set -euo pipefail
cd /opt/randy-2
DATA=/opt/randy-2/runtime/qbox-server-data
BACKUP=/opt/randy-2/runtime/phase2-predeployment-backup
test -d "$BACKUP"
test ! -e "$BACKUP/final-tarrant_world"
mv "$DATA/resources/[tarrant]/tarrant_world" "$BACKUP/final-tarrant_world"
if test -d "$BACKUP/tarrant_world"; then
  cp -a "$BACKUP/tarrant_world" "$DATA/resources/[tarrant]/tarrant_world"
fi
if test -f "$BACKUP/world.cfg"; then
  cp -p "$BACKUP/world.cfg" "$DATA/world.cfg"
else
  printf '# Phase 2 overlay disabled after rollback\n' > "$DATA/world.cfg"
fi
```

The harmless `exec world.cfg` include can remain; the absent prior world gets
an empty disabled fragment. Do not restore the whole backed-up server.cfg over
newer operator edits. With a previous installed resource and its prior startup
settings reviewed, console `refresh` then `ensure tarrant_world` restores it;
otherwise leave world stopped. Phase 1 resources remain running.

If the repository itself must return to the specified pre-final state, preserve
branch history with a detached checkout; do not force-push or reset main:

```bash
cd /opt/randy-2
test -z "$(git status --porcelain)"
git switch --detach 583c3a58e2aa46aa1f199cfe11cfb2f737d1ac28
```

Git checkout alone does not update the copied runtime. To explicitly install
that commit's five-active/two-disabled overlay after the rollback above:

```bash
DATA=/opt/randy-2/runtime/qbox-server-data
mkdir -p "$DATA/resources/[tarrant]/tarrant_world"
cp -a 'resources/[tarrant]/tarrant_world/.' "$DATA/resources/[tarrant]/tarrant_world/"
diff -r 'resources/[tarrant]/tarrant_world' "$DATA/resources/[tarrant]/tarrant_world"
```

Then console `refresh`, `ensure tarrant_world` only if choosing to run that
previous overlay. Keep world.cfg disabled for Phase-1-only rollback. Return to
normal source deployment later with `git switch main` and the reviewed copy flow.
Verify character, HUD, inventory, chat/voice, money/bank, owned vehicles/plates,
live readiness logs and `bash scripts/check-qbox-readiness.sh`. No DB restore,
framework restart or artifact rollback is required for these changes.

## Remaining gates

Enhanced game survey/visual acceptance, live Phase 1 readiness, two-client and
performance testing remain pending. Texas plate target discovery and validated
asset/conversion are blocked as documented. Physical signs, interiors, business
systems, other locations and Milestone 2 remain deferred.
