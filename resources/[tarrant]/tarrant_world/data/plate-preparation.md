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
- No `AddReplaceTexture`, `vehshare`, or `plate01` replacement was found in
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
