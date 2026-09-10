# Texas plate preparation: DEFERRED texture, completed audit/scaffold

No executable replacement hook or texture is loaded by this resource. Enabling
branding does not change plates. Keep a future plate resource independently
startable because texture replacements can affect every vehicle on a client.

Local runtime audit (2026-09-08):

- `qbx_vehicles/server/main.lua` generates a random plate when absent, checks
  `player_vehicles` for uniqueness, and persists the string. `vehicles.sql`
  has a unique plate key. Do not change this code or schema.
- `ox_lib/resource/vehicleProperties/client.lua` reads/writes the plate string
  and `plateIndex` as separate vehicle properties. An index selects a style;
  it does not supply Texas artwork. Qbox's compatibility bridge also applies
  vehicle properties. Neither is an appropriate place for world branding.
- No plate-specific `AddReplaceTexture`, `vehshare`, or `plate01` replacement was found in
  the inspected local resource tree. Stock vehicle artwork remains the baseline.
  This is local evidence, not a live VPS inventory.

Next milestone contract (not implemented): author original Texas-inspired art;
survey the Enhanced client's actual texture dictionary/name pairs and normal
maps; determine whether a dedicated streamed YTD or runtime replacement is
appropriate. Do not assume Legacy `vehshare` names or binary formats work.
Record source artwork, dimensions, size, hashes, license, exact target names,
Enhanced build, conversion report and screenshots before enabling a replacement.
Runtime replacement must remove its own replacements on stop; streamed overrides
need a cold reconnect/cache rollback test. Do not call plate text/index setters,
update SQL, regenerate identifiers, or mutate saved vehicle properties.

Cfx lists YTD among Alchemist's Legacy-to-Enhanced conversion types:
https://docs.fivem.net/docs/alchemist/
https://docs.fivem.net/docs/server-manual/onboarding-guide-fivem-for-gtav-enhanced/
Reviewed 2026-09-08. No asset was created, converted, installed, or validated here.

Acceptance: compare the exact saved plate string and vehicle lookup before/after
enable, garage storage/retrieval, reconnect and server restart; test multiple
plate styles, two clients, day/night/rain, cold cache and complete rollback on
Enhanced Linux b139. MANUAL GAME TEST REQUIRED.

## Final predeployment decision (2026-09-10)

**BLOCKED / NOT VISUALLY IMPLEMENTED.** No plate code or artwork is loaded.
The native rendering boundary is a plate text string plus an independently
selected stock plate style. Local OX reads these with GetVehicleNumberPlateText
and GetVehicleNumberPlateTextIndex and restores them with their respective
setters (client.lua lines 214-215 and 331-336). qbx_vehicles generates missing
strings, checks uniqueness, inserts both mods and plate, and updates saved plate
values through its existing persistence path (server/main.lua lines 139-161,
247-249). None of these files or the unique SQL plate key changes.
A texture-only replacement would not itself write qbx_vehicles or DB data;
calling style/text setters could alter subsequently saved properties and is excluded.
The HUD already replaces minimap textures; it is unrelated and remains untouched.

Method assessment:

- Style configuration selects existing artwork; it cannot author a Texas design
  and may change saved plateIndex. Rejected for this goal.
- Runtime texture creation still needs a verified destination texture and a
  replacement hook. Cfx's [AddReplaceTexture declaration](https://github.com/citizenfx/fivem/blob/master/ext/native-decls/AddReplaceTexture.md)
  explicitly marks it experimental and advises against live use. No b139 proof
  or exact Enhanced dictionary/normal-map inventory is available locally.
- Streamed YTD replacement requires verified Enhanced target names and binary
  format. No validated plate YTD exists in this project. Legacy names such as
  vehshare/plate01 are hypotheses, not confirmed Enhanced rendering targets.
- No other verified Enhanced replacement method was established in this audit.

Next asset step: inspect an Enhanced client texture inventory for each stock
plate style (including normal maps and character layer), record exact targets,
dimensions and formats. Author original light/white artwork with subtle TEXAS
text, clear central number area, no seal/logo or copied artwork. Package it as
Enhanced-native YTD, or convert an original Legacy YTD using Cfx Alchemist on
Windows 11: choose Asset Conversion, separate input/output folders and retain
strict validation (no relaxed mode). The documented CLI form is
`AlchemistCli.exe C:\plate-input C:\plate-enhanced --fail-on-error`.
Record tool version, source/output hashes and report; inspect the output format.
[Cfx Alchemist](https://docs.fivem.net/docs/alchemist/) supports YTD conversion;
conversion success alone does not prove correct target selection or rendering.
Sources rechecked 2026-09-10.

Use a separately startable development resource to validate multiple vehicles,
all stock styles, number readability, garage/reconnect persistence, two clients,
cold cache, missing/purple textures, frame time and rollback on Enhanced b139.
Only then select and enable a release method. No unverified binary, runtime
replacement, registration hook, DB migration or vehicle enumeration loop ships
in this final pass. This blocker does not block the seven-site script overlay.
