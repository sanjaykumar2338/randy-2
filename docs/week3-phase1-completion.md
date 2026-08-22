# Week 3 / Phase 1 Completion Runbook

Status: **PASS — Phase 1 foundation completed and ready for Phase 2 economy development.**

This completion audit accepts the Week 1 playable runtime and Week 2 operations foundation as established evidence. Week 3 did not rebuild those systems or introduce later-phase gameplay features.

## Phase 1 Requirements Audit

| Requirement | Existing evidence | Week 3 conclusion |
| --- | --- | --- |
| Supported local database and Qbox runtime | Week 1 installation, schemas, connection, resources, and gameplay | Complete |
| Player/character/spawn lifecycle | Week 1 in-game spawn/reconnect; Week 3 disconnect, reconnect, join, and character reload | Complete |
| Inventory and money persistence | Week 1 restart test; Week 3 live and isolated-restore checks | Complete |
| Voice foundation | pma-voice 7.0.1, native audio, UI/proximity/radio/call settings, clean startup | Complete; two-player audio remains separate |
| Staff and whitelist architecture | Week 2 ACE hierarchy and disabled-by-default Discord/whitelist configuration | Complete for foundation |
| Logging and health | txAdmin audit plus structured `tarrant_ops` lifecycle/readiness events | Complete |
| Development security and secret separation | Loopback listeners, hardened convars, ignored operational secrets | Complete |
| Backup and recovery | Checksummed backup, validation-only mode, isolated restore | Complete |
| Operational performance baseline | Not previously repeatable | Completed in Week 3 |
| Phase boundary/documentation | Week 1/2 runbooks existed | Completed here |

No missing Phase 1 dependency justified installing another framework or editing upstream Qbox/OX resources.

## Week 3 Work

- Added a repeatable, secret-safe performance sampler at `scripts/measure-phase1-baseline.ps1`.
- Marked the loopback development server private with `sv_master1 ""`, following Cfx guidance for localhost servers, to avoid unnecessary public-list exposure.
- Denied `command.quit` to the owner ACE group to reduce accidental shutdown risk while retaining deliberate txAdmin lifecycle control.
- Re-ran the generated runtime configuration without overwriting the ignored local staff grant.
- Performed a clean client disconnect, txAdmin-scheduled restart, client reconnect, session join, and character reload.
- Revalidated the complete backup and recovery path against an isolated database.
- Rechecked player state without manufacturing balances or inventory.

Project functionality remains under `resources/[tarrant]`; no upstream resource was modified.

## Lifecycle And Persistence Regression

At 22:42 local time, the connected client was cleanly disconnected and the server reported zero players. txAdmin recorded the authenticated restart schedule and executed it at 22:43. The game listener PID changed from 18576 to 20256. After recovery, MariaDB connected, ox_inventory loaded 301 items, pma-voice and all required Qbox/OX resources started, and `tarrant_ops` reported the database and every required resource healthy.

FiveM then reconnected from the local launcher. Structured events recorded `player.connecting`, `player.joined`, and character `ER26B064` loaded with cash 500 and bank 5080. The subsequent values 5090 and later increments are explained by the already-audited $10 civilian paycheck; no restart/reconnect duplication was observed. Inventory autosave succeeded and MariaDB retained `water` x2, cash 500, metadata, and the expected position near `-528.88, -224.62, 37.20`.

The accepted Week 1 test remains the authoritative visual in-game spawn/HUD/movement/chat/inventory proof. Week 3 reached the same character through the live reconnect path and did not expose a gameplay regression. Repeated synthetic GUI retries were avoided once server and database evidence was conclusive.

## Voice Review

pma-voice uses native audio with exactly one audio mode enabled. Its UI, proximity cycling, normal default mode, radios, calls, submix, radio animation, and conservative 200 ms refresh are configured. Debug logging is disabled and no new pma-voice startup/runtime error occurred.

Actual proximity/radio audio between two humans remains a separate multiplayer acceptance test. A single local microphone/client cannot prove bidirectional voice.

## Permissions And Whitelist Review

The ACE chain is owner → admin → moderator → support. Project commands require at least `tarrant.support`; owner is the only project role with general command access and is explicitly denied `command.quit`. Real staff identifiers remain in ignored `staff.cfg`. The current local owner grant survived configuration regeneration.

Whitelist enforcement remains false. The `tarrant.whitelist` ACE and Discord role placeholders are ready, but production enforcement must not be enabled until an approved Discord application/role bridge maps reviewed guild roles to ACE principals. A webhook is logging transport, not authorization.

## Logging And Security Review

`tarrant_ops` records redacted connection, join/leave, character, job, money, project-resource, readiness, whitelist-denial, and project-admin events as structured JSON. Only six-character identifier suffixes are logged. txAdmin separately records authenticated lifecycle and console actions. Secrets are neither printed by the health/baseline scripts nor forwarded unless the ignored webhook configuration is explicitly enabled.

The console-side `tarrant_admin_note Phase 1 completion audit` test produced both the txAdmin console attribution and the structured `admin.action` event without exposing an identifier or secret.

Development listeners remain restricted to `127.0.0.1` on ports 30120, 40120, and 3306. Script hooks and development mode are disabled; request-control filtering and networked sound/explosion/script-entity restrictions remain enabled. The local server is explicitly private. Loopback JSON endpoints remain available for automated checks.

Before production:

1. Bind only the intentionally public game interfaces and enforce the host firewall.
2. Keep MariaDB private; never expose port 3306 publicly.
3. Put txAdmin behind a reviewed management network or secure reverse proxy and require individual strong accounts/2FA where supported.
4. Rotate development keys, use production-scoped database credentials, and inject all secrets outside Git.
5. Approve the Discord bot/role bridge and test whitelist fail-open/fail-closed behavior before enforcement.
6. Review Cfx artifact updates, resource releases, rate limits, log retention, backup encryption, and off-host backup storage.
7. Reassess stricter state-bag/resource sandbox permissions with the production resource set; do not enable breaking restrictions blindly.

## Performance And Health Baseline

The post-restart sample was captured with one connected player over three seconds:

| Metric | Baseline |
| --- | ---: |
| Started resources reported by FXServer | 17 |
| Enhanced cfx-server worker processes | 4 |
| Aggregate FXServer working set | 309.1 MiB |
| FXServer CPU, percent of host | 0.23% |
| `info.json` response | 294.4 ms |
| `players.json` response | 4.2 ms |
| MariaDB working set | 22.8 MiB |
| MariaDB connections/running threads | 5 / 1 |

The earlier idle/transition sample was 198.4 MiB and 0.55% host CPU. These are local development reference points, not production capacity claims. Phase 2 should compare like-for-like samples and investigate sustained CPU, memory, endpoint latency, server hitch warnings, database thread growth, or resource-count increases.

The remaining startup notices are an available artifact update (`b127` to `b129`) and Enhanced native deprecation notices originating from the current runtime/upstream resources. They are nonblocking but should be reviewed during a separately tested artifact/dependency update rather than changed during Phase 1 acceptance.

## Backup And Recovery Result

Backup `20260822-225721` passed SHA-256 and required-schema validation. It restored into isolated database `tarrant_rp_phase1_restorecheck_20260822` with 14 tables, character `ER26B064`, cash 500, bank 5090, and `water` x2. The isolated database was then removed and its absence confirmed. The live database was never replaced or artificially edited.

Recovery procedure:

1. Stop player traffic and take a fresh backup with `scripts/backup-dev.ps1`.
2. Copy the backup off-host and protect it as sensitive data.
3. Run `restore-dev.ps1 -BackupPath <path>` for checksum/schema validation.
4. Review redacted config and `[tarrant]` resources manually.
5. Restore first to a new database with `-Apply -TargetDatabase <review_name>`.
6. Validate tables, character/inventory/money, and application-user privileges.
7. Schedule a maintenance window before deliberately switching runtime configuration to the restored database.

## Deferred Beyond Phase 1

- Two-player proximity/radio voice communication.
- Production Discord bot authorization, role synchronization, and whitelist enforcement.
- Production networking, firewall/reverse-proxy, monitoring/alerting, log retention, and encrypted off-host backups.
- Economy expansion, dealerships, financing, expanded jobs, businesses, housing, government systems, monetization, and custom Texas map/world work.
- Optional Qbox resources intentionally excluded from the minimal foundation, including apartments, ID cards, vehicle keys, and other systems whose owning phase has not started.
- A controlled upgrade from Enhanced artifact b127 to the newer advertised build after release notes and regression testing.

## Phase 1 Decision

**PASS. Phase 2 economy development may begin.** Preserve the Phase 1 regression checks and compare future performance samples against this baseline. The deferred second-player and production-account tasks do not block local Phase 2 development.
