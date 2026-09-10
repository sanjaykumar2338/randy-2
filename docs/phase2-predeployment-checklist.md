# Phase 2 final local predeployment record

## Ground lookup fallback after live retest

**LIVE ACCEPTANCE PARTIAL.** Reported live evidence for 261c1ec: City Hall's
horizontal ring sits at the feet/surface and its label remains visible: **PASS**.
APD and Hospital were reachable but ring and label were not visible in the
inspected views: **RETEST REQUIRED**, not placement PASS. Remaining four sites,
full lifecycle, duplicate blips, performance and two clients remain pending.

### Diagnosis and source correction

The exact code defect is `z = marker.groundZ` followed by `if z then DrawMarker`:
an unavailable or rejected ground result suppresses the ring. The query is
`GetGroundZFor_3dCoord(c.x, c.y, c.z + 0.5, false)`; false excludes water.
The boolean must indicate success and the returned numeric surface must be
within 2 metres of logical Z. NaN/infinite/distant values are rejected. A
single sample is taken at that height; this is not a vertical raycast sweep.
Ground resolution needs locally rendered world geometry. Covered/raised areas
and collision loading after teleport are possible causes, not verified diagnoses.
City Hall's observed ring is consistent with an accepted surface result.
No live native-return trace establishes which failure occurred at APD/Hospital.
The first failed query is not cached permanently: timestamp-based retries run
every 1000 ms while within the 20 m logical-coordinate drawing sphere. There
is no busy retry loop or forced collision streaming.

Smallest fix: `z = marker.groundZ or c.z`. Success keeps exactly the previous
surface + 0.05 m clearance. Failure/rejected surface draws the same type-23 ring
at logical Z + `marker.zOffset` (default +0.05 m), retrying on the existing
schedule. Later success replaces fallback; later failure uses fallback again.
No large downward correction is guessed. The fallback guarantees the draw call,
not visibility through geometry or ground-level acceptance: it may temporarily
float or be occluded and must be checked in-game. Existing global/per-site
`zOffset` config applies to both paths. No location/config change is needed.

Labels were already independent: after marker processing, the nearest enabled
location strictly within 3 m (3D logical-coordinate distance) is selected, and
its label draws regardless of ground success or marker enabled state. Blips
are created at startup independently. Missing APD/Hospital labels therefore
cannot be explained solely by a nil ground result. Actual player XYZ after
teleport/settling, running resource version/state, client errors and label
occlusion/other UI must be inspected; no cause is asserted without evidence.
No label-distance or blip behavior changed.

Runtime cost is unchanged apart from drawing the ring during failed lookups:
one distance scan of seven entries per tick, 750 ms sleep far away, per-frame
draws only near a visible marker/label. At most one ground query per nearby
site per second at steady state, also refreshed if game timer wraps backwards.
Cache is bounded to enabled IDs (seven), with no growing retry queue. No new
thread, network call, blocking loop, collision request or inactivity handler.
The existing yielding render loop is necessary for frame-local draws; no
unbounded ground-resolution loop is added. Enhanced runtime cost is unmeasured.

Tests: Lua 5.4 syntax/manifest/world harness PASS, including failure/rejected
results producing fallback, throttling, later successful retry, labels and one
blip during all states, APD/Hospital/City Hall cases, and unchanged success type,
scale and clearance. All seven logical coordinates/blip configs are pinned by
existing tests; the entire config file is unchanged from 261c1ec. Existing six
Phase 1 regression scripts PASS; Linux symlink assertion skipped on Windows.
No Phase 1 source changed. Live gameplay/performance acceptance is not claimed.

### Operator update (not executed)

Confirm txAdmin uses `/opt/randy-2/runtime/qbox-server-data`. VPS Bash as owner:

```bash
set -euo pipefail
cd /opt/randy-2
git status --short
test -z "$(git status --porcelain)"
test "$(git branch --show-current)" = main
git pull --ff-only origin main
git log -1 --format='%H %s'
WORLD='/opt/randy-2/runtime/qbox-server-data/resources/[tarrant]/tarrant_world'
BACKUP=/opt/randy-2/runtime/world-fallback-backup-$(date -u +%Y%m%dT%H%M%SZ)
test -f "$WORLD/client/main.lua"
test ! -L "$WORLD"
test ! -L "$WORLD/client"
test ! -e "$BACKUP"
mkdir -m 700 "$BACKUP"
cp -p "$WORLD/client/main.lua" "$BACKUP/main.lua"
cmp 'resources/[tarrant]/tarrant_world/config/locations.lua' "$WORLD/config/locations.lua"
test ! -e "$WORLD/client/main.lua.fallback-update"
cp 'resources/[tarrant]/tarrant_world/client/main.lua' "$WORLD/client/main.lua.fallback-update"
mv "$WORLD/client/main.lua.fallback-update" "$WORLD/client/main.lua"
cmp 'resources/[tarrant]/tarrant_world/client/main.lua' "$WORLD/client/main.lua"
printf 'Rollback client backup: %s/main.lua\n' "$BACKUP"
```

The config comparison deliberately stops if the deployed config differs; review
operator customization before updating. Only the client file changes. In txAdmin
**server console**, once copied:

```text
restart tarrant_world
```

No full restart, server.cfg change or refresh required. For rollback, restore
`$BACKUP/main.lua` to `$WORLD/client/main.lua` and restart only tarrant_world.
Do not modify vendor resources, private settings, DB or artifacts.

### Exact retest order

1. APD `434.7,-981.9,30.7`: existing txAdmin coordinate teleport; inspect immediate
   ring, then again after 1-3 seconds. Step aside to see the ring. Record actual
   player XYZ if the label is missing; verify within 3 m of logical coordinates.
2. Hospital `298.6,-584.4,43.3`: repeat, including arrival under the canopy and
   leaving/returning after collision loads. A fallback ring is not ground PASS.
3. City Hall `195,-933,30.7`: preserve the observed ground ring and label PASS;
   verify unchanged scale, surface clearance and blip. This is the regression gate.
4. Fire `200.1,-1634.3,29.8`, Stadium `-250.5,-2030,30.1`, Texas Burger Grill
   `-170,-1710,29`, Prairie Ice Cream and Grill `100,-1400,29`: inspect accessible
   location, immediate/later ring, label, waypoint, collision and suitability.
   Restaurant PASS means provisional commercial parcel suitability only.
5. Verify all seven blips exist once; character/movement/HUD/inventory/chat and
   existing money/bank are healthy. Record F8/server errors separately, including
   any missing-label evidence. Do not change money/inventory or vendor resources.
6. After all seven visits, console `stop tarrant_world`, confirm overlay gone;
   `ensure tarrant_world`, confirm one overlay returns. Repeat with two clients,
   reconnect and performance/resmon observations. Record results before acceptance.

**APD/Hospital placement and complete visual acceptance remain unapproved.**
No deployment, unrelated warning fix, Phase 1 change or Milestone 2 work.
Earlier hide-on-failure descriptions below are historical and superseded here.


## Marker correction update after partial live test

**LIVE ACCEPTANCE PARTIAL.** This section supersedes the earlier all-pending
record below. PASS: resource loads, custom blips/labels visible, sensible APD
and Hospital areas, accessible City Hall plaza. FIX REQUIRED from the deployed
c06c59b test: shared vertical marker placement. Source correction is implemented;
visual fix acceptance is still pending. No individual logical coordinates or
blip positions changed. City Hall's actual building remains unvalidated.

NOT YET TESTED: Fire Station, Stadium, Texas Burger Grill, Prairie Ice Cream and
Grill, full lifecycle, duplicate blip behavior, performance and two clients.
Inventory NUI error is unrelated to world code; exact vendor cause unproven.
Timeout causality is unproven. See the [diagnosis and automated evidence](phase2-milestone1-implementation.md#marker-correction-after-live-acceptance-partial-2026-09-10).

### Operator update only (not executed here)

Confirm the same active server-data path in txAdmin. Use VPS Bash as repo owner:

```bash
set -euo pipefail
cd /opt/randy-2
git status --short
test -z "$(git status --porcelain)"
test "$(git branch --show-current)" = main
git pull --ff-only origin main
git log -1 --format='%H %s'
DATA=/opt/randy-2/runtime/qbox-server-data
BACKUP=/opt/randy-2/runtime/world-marker-backup-$(date -u +%Y%m%dT%H%M%SZ)
test -f "$DATA/resources/[tarrant]/tarrant_world/fxmanifest.lua"
test ! -L "$DATA/resources/[tarrant]/tarrant_world"
test ! -e "$BACKUP"
mkdir -m 700 "$BACKUP"
cp -a "$DATA/resources/[tarrant]/tarrant_world" "$BACKUP/tarrant_world"
printf 'Keep rollback backup: %s\n' "$BACKUP"
```

Then txAdmin **server console**:

```text
stop tarrant_world
```

Back in the same VPS Bash session, copy only the two changed executable files:

```bash
cp 'resources/[tarrant]/tarrant_world/config/locations.lua' "$DATA/resources/[tarrant]/tarrant_world/config/locations.lua"
cp 'resources/[tarrant]/tarrant_world/client/main.lua' "$DATA/resources/[tarrant]/tarrant_world/client/main.lua"
cmp 'resources/[tarrant]/tarrant_world/config/locations.lua' "$DATA/resources/[tarrant]/tarrant_world/config/locations.lua"
cmp 'resources/[tarrant]/tarrant_world/client/main.lua' "$DATA/resources/[tarrant]/tarrant_world/client/main.lua"
```

Then server console:

```text
ensure tarrant_world
```

Only tarrant_world needs stop/start. No full server restart, refresh, server.cfg,
world.cfg, private config, DB or artifact changes are required. Review any local
world customizations against the backup before copying. On copy failure leave
world stopped and restore the two files from the printed backup before ensuring.
For rollback, stop world, copy `$BACKUP/tarrant_world/config/locations.lua` and
`$BACKUP/tarrant_world/client/main.lua` to their respective runtime paths, then
ensure world. Keep all Phase 1 resources running.

### Exact live retest

1. Confirm player connected and existing `tx` admin menu works. Record deployed
   commit, client/server build and console baseline. Do not alter permissions.
2. Teleport via txAdmin Teleport: Coords to APD `434.7,-981.9,30.7`, Hospital
   `298.6,-584.4,43.3`, City Hall `195,-933,30.7`. Walk a few steps away from each
   ring to inspect it unobstructed. Verify a small flat ring on/just above the
   actual surface, no floating/underground marker, readable label and unchanged
   blip/waypoint. Record screenshot and any failed surface lookup; do not guess Z.
3. Visit Fire `200.1,-1634.3,29.8`, Stadium `-250.5,-2030,30.1`, Texas Burger Grill
   `-170,-1710,29`, Prairie Ice Cream and Grill `100,-1400,29`. Check accessible
   terrain, appropriate GTA area, label/ring, unique blip, road/parking and
   collision suitability. Restaurant PASS means provisional parcel suitability.
4. Check late streaming/rapid arrival and revisit each site: ring should appear
   after a successful ground query, without a permanent false position. Check
   day/night, slopes/steps and performance/resmon; report native errors separately.
5. Check character, movement/camera/HUD, inventory opening, chat and existing
   money/bank values without changing items or money. Capture inventory errors
   and any disconnect timing; do not attribute them to world without evidence.
6. After all seven visits, console `stop tarrant_world`: rings/labels/blips vanish.
   `ensure tarrant_world`: each returns once. Check server/F8 errors and count
   blips; do not restart the server. Repeat with two clients.
7. Leave visual acceptance pending until observed results are recorded. No
   fixes, permission changes or vendor changes during retest without approval.


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
