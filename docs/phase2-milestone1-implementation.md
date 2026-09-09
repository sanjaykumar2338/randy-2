# Phase 2 milestone 1: Arlington core identity

Source implementation complete; visual acceptance pending. This controlled scope
was authorized by the milestone request and narrows the earlier planning gates
to scripts/configuration with fictional branding. Milestone 2 has not begun.

## Architecture and audit

`resources/[tarrant]/tarrant_world` is a standalone client resource with
`fxmanifest.lua`, `config/locations.lua`, `client/main.lua` and a plate preparation
record in `data/`. No server script, dependency, network event, database access,
stream directory or `this_is_a_map` flag is needed: this is not an asset map.
No downloaded or vendor resource was edited. All shipped code is project-authored.
`config/world.example.cfg` is an opt-in startup fragment; existing profiles are
not silently enabled. The regular installer already copies project resources,
but operators must copy/exec the world fragment explicitly.

The local ignored runtime contains Qbox core/vehicles/spawn/HUD, OX, appearance,
voice, Cfx defaults, tarrant_ops and week1-verification. Its HUD contains minimap
YTDs; these were not touched or revalidated. No custom civic MLO or plate override
was identified. No police, ambulance or fire job resource was found in the local
manifest inventory. Local evidence does not establish the VPS inventory: inspect
txAdmin's resource list for duplicate blips and map conflicts before enabling.
Private staging configuration and secrets were not changed. No VPS action occurred.

The registry supports additional locations without duplicate client logic. Each
entry carries ID, enabled flag, fictional/real names, district, category, GTA base,
coordinates, blip settings, RP purpose, interior requirement, stage and survey
status. Disable an entry or its blip independently and restart this resource.
The single distance loop sleeps 750 ms away from sites and draws only within 20 m;
one nearby information label appears within 3 m. Blips are removed on resource stop;
markers/text are frame-local. There are no entities or global zone-name overrides.
District names are metadata and nearby labels, not replacements for HUD street names.

## Location register

All five are enabled. Coordinates are **candidate exterior reference points**,
not surveyed doors, spawn points or validated functional interiors.

| Requested location | GTA base | X, Y, Z | Shipped level |
| --- | --- | --- | --- |
| Arlington Police Department | Mission Row | 434.7, -981.9, 30.7 | Blip, entrance reference marker, nearby name/district/purpose |
| Texas Health Arlington Memorial | Pillbox | 298.6, -584.4, 43.3 | Same; fictional name Arlington Memorial Hospital |
| Arlington City Hall | Legion Square civic plaza | 195.0, -933.0, 30.7 | Same; temporary exterior civic meeting reference, building selection pending |
| Arlington Fire Station 1 | Davis Fire Station | 200.1, -1634.3, 29.8 | Same; no bay/garage integration |
| AT&T Stadium | Maze Bank Arena / La Puerta | -250.5, -2030.0, 30.1 | Same; fictional Arlington Stadium and stadium district label |

Functional additions are navigation and passive RP meeting information. There
are no service transactions, duty systems, teleports, job interactions or newly
opened interiors. Existing interior access remains whatever Phase 1 provides.
No physical signs, facade replacements, logos, props or stadium reconstruction
are shipped. The reusable nearby label is the exterior branding hook for now.
No claim of architectural resemblance to Arlington is made.

`branding_mode = 'fictional'` is the default. After Randy approves real naming,
change it to `'real'` in the source registry, commit/deploy and restart only this
resource. That selects real text names, not logos or licensed artwork.

## Enhanced and Texas plates

Zero streamed assets were added: no YTD/YDR/YMAP/YTYP/YFT or conversion requirement
in this release. This avoids a new binary asset compatibility dependency, but
does not prove rendered behavior on Enhanced b139. **MANUAL GAME TEST REQUIRED**.

The [Cfx Alchemist documentation](https://docs.fivem.net/docs/alchemist/) lists
YDR/YTD/YFT/YPT/YDD conversion from Legacy to Enhanced. Future plate YTDs need
Enhanced authoring or conversion evidence, plus in-game validation; scripts do
not make a Legacy texture compatible. See the
[Enhanced onboarding guide](https://docs.fivem.net/docs/server-manual/onboarding-guide-fivem-for-gtav-enhanced/).
Sources reviewed 2026-09-08.

Texas plate technical audit/scaffold: IMPLEMENTED in
`resources/[tarrant]/tarrant_world/data/plate-preparation.md`. Actual artwork and
replacement: DEFERRED. Local Qbox generates/checks/persists unique strings;
OX vehicle properties independently preserve `plate` and `plateIndex`.
No replacement target/texture format has been validated on an Enhanced client.
No plate setter, texture replacement, schema change or vehicle mutation is shipped.

## Validation

- Lua 5.4 via temporary Python Lupa 2.8: `tests/check-tarrant-world.lua` PASS.
  Compiles manifest and both scripts; executes registry checks, five enabled
  IDs, required fields, finite coordinates, blip config, both branding modes,
  per-location disable, distant/near frame behavior and owned-blip stop cleanup.
  This harness mocks natives; it cannot validate rendering or native behavior.
- All three existing Bash regression scripts PASS under Git Bash. Linux hosted
  deployment's real symlink assertion was skipped by its Windows fallback.
- Existing PowerShell artifact, listing and dependency tests PASS.
- Existing `check-week2-health-log.ps1` FAIL: its success fixture also runs live
  environment checks, so it requires running local Phase 1 services. This test
  and the health script are unchanged; do not interpret this as a regression pass.
- Review staged paths/diff for private files and run `git diff --check` before commit.
- On Linux with Lua 5.4: `lua5.4 tests/check-tarrant-world.lua`.

## VPS deployment (operator, normal Git flow)

Use the existing repository owner account at the documented `/opt/randy-2` path.
First inspect the active txAdmin resource inventory and confirm this is its active
server-data path. Do not copy the development server template over the live cfg.
The following refuses an existing world installation so an operator cannot
accidentally overwrite a separately customized resource. For later updates use
a reviewed backup/update procedure.

```bash
set -euo pipefail
cd /opt/randy-2
git pull --ff-only origin main
git log -1 --format='%H %s'
DATA=/opt/randy-2/runtime/qbox-server-data
test -f "$DATA/server.cfg"
test ! -e "$DATA/resources/[tarrant]/tarrant_world"
test ! -e "$DATA/world.cfg"
cp -p "$DATA/server.cfg" "$DATA/server.cfg.before-world-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$DATA/resources/[tarrant]"
cp -R 'resources/[tarrant]/tarrant_world' "$DATA/resources/[tarrant]/tarrant_world"
cp config/world.example.cfg "$DATA/world.cfg"
if ! grep -Eq '^[[:space:]]*exec[[:space:]]+world\.cfg[[:space:]]*$' "$DATA/server.cfg"; then
  printf '\n# Phase 2 civic identity overlay\nexec world.cfg\n' >> "$DATA/server.cfg"
fi
```

This modifies only the startup include and copies project files; it does not
touch `staging.private.cfg`, `.env`, keys, databases, binaries or vendor resources.
No command restarts the server. In a disposable Enhanced development profile
first, then at the operator's chosen deployment time, use the txAdmin **server
console** (not Bash):

```text
refresh
ensure tarrant_world
```

A full server restart is not required for this script-only resource. The include
persists it across the next normal restart. Source configuration/name/coordinate
updates require redeploying files and `restart tarrant_world`; no live restart
was performed here. Avoid repeated ensures during testing because they restart
an already-running resource.

## Sanjay's manual acceptance and rollback

**MANUAL GAME TEST REQUIRED** on Enhanced Linux b139:

1. Record Phase 1 and overlay-off client/server resmon/frame time; inventory live
   maps and service blips. Join with a cold cache and inspect F8/server errors.
2. Visit all five coordinates; survey ground height, accessible entrance/reference,
   roads, doors, collision, emergency apron and existing script conflicts. City
   Hall is a plaza placeholder: select/approve a building before interior work.
3. Confirm each blip/name, nearby marker and district/purpose text in day/night/rain;
   verify readability against the HUD and labels disappear beyond 3 m. Confirm
   fictional defaults. Test real text and per-site disable only in development.
4. Drive civic core -> Davis -> arena; record resmon/frame-time comparison, two
   clients, rapid traversal, reconnect and cold-cache behavior. No numeric
   performance acceptance is claimed until measurements exist.
5. Stop/start/restart the resource in development: no duplicate or orphan blips,
   labels or markers. Other resources must remain healthy. If a service already
   owns a blip, disable this registry entry's blip rather than editing that vendor.
6. Recheck character loading, money/inventory, chat/HUD/voice, vehicle retrieval and
   exact saved plate strings. Run Phase 1 health checks on the actual running host.
   At the next authorized full restart verify persistence/recovery again.

Rollback: server console `stop tarrant_world` removes its visible overlay. Remove
the `exec world.cfg` line added above from active `server.cfg` to keep it disabled
on restart (or comment `ensure tarrant_world` in world.cfg). Leave the resource
files dormant; no database or binary rollback is necessary. Do not restore a
whole old server.cfg over newer operator changes. Keep a Git revert for source
rollback as a separately reviewed normal deployment.

## Deferred work and Randy decisions

Visual/collision acceptance and surveyed site envelopes are pending. Physical
signs, Enhanced texture spike, all custom interiors, government/fire/medical/police
gameplay, stadium models, plate artwork and other 15 locations are deferred.
Randy must approve real branding/art rights, the surveyed City Hall building and
site tour, future room/job briefs, any asset budget/license and client performance
targets before those additions. No paid or third-party map asset was installed.

## Subsequent commercial planning scaffold (2026-09-09)

Whataburger and Dairy Queen are **SCAFFOLDED / DISABLED** in the same registry,
with disabled blips and explicit per-site fictional branding. They are not part
of the five completed milestone 1 source locations; those five records are
unchanged. The client now accepts an optional per-site naming override, falling
back to the existing global mode for all original records. No assets or gameplay
were added, and milestone 2 has not begun. See the
[commercial plan and activation gates](phase2-map-implementation-plan.md#texas-commercial-staples).

Follow-up validation: Lua 5.4 (temporary Lupa 2.8) PASS for seven unique IDs and
coordinates, categories, required metadata, disabled sites producing no blips,
markers or labels, per-site/global branding, proximity and cleanup. A recursive
comparison against `73f26572de0d85661f6ab13a9b6b62fb94cd1baa` confirmed every field
of the original five records unchanged. All three Bash regression scripts and
PowerShell artifact/listing/dependency tests PASS; the Windows symlink assertion
was skipped. The unchanged health-log test still fails `fields-first-success`,
matching the previously recorded live-environment limitation; live Phase 1
acceptance is not claimed. `git diff --check` PASS. No VPS deployment or
txAdmin/FiveM restart was performed.
