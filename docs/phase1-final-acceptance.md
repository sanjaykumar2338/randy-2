# Tarrant County RP

## Phase 1 Final Acceptance Report

**Audit date:** 2026-09-02  
**Classification:** **CONDITIONAL PASS**

## 1. Executive summary

The Phase 1 foundation accepts a real FiveM for GTA V Enhanced client connection on the official Enhanced Linux b139 artifact. The previous `bad_request` failure is gone, the public game endpoint responds, OneSync is enabled, all required Phase 1 resources are advertised by the live endpoint, and the operator-observed session reached character creation and appeared in txAdmin.

This is not an unconditional PASS. After commits `886518f` and `56bdbbb` were deployed, the operator completed a controlled live restart: txAdmin recovered; TCP/UDP 30120 and TCP 40120 listened; local/public `info.json` passed; MariaDB reconnected; all required resources started; and `tarrant_ops` reported startup readiness, `healthy=true`, and `database=true`. Gameplay persistence, UI, chat and two-player voice remain unverified. Public Cfx registration also remains absent: the single-server API returned HTTP 404. That does not invalidate the proven direct Enhanced connection.

Repository deployment defects found during this audit were fixed in commit `56bdbbb`: the Linux service can now be rendered with b139-compatible `TXHOST_*` settings and no deprecated txAdmin ConVars, while Linux checks parse `.env` without executing it and locate resources in the deployed runtime.

## 2. Environment and build

| Item | Current value/evidence |
| --- | --- |
| Host | Ubuntu 24.04 (operator-provided live evidence) |
| Project/runtime | `/opt/randy-2`; `runtime/qbox-server-data` |
| Artifact | Enhanced Linux b139; txAdmin `v9.0.0-beta / b139-ea / Lin` (operator-provided) |
| Active artifact path | `server-binaries/enhanced-129` symlinked to `enhanced-linux-139` (operator-provided) |
| Public endpoint | `162.35.117.174:30120` |
| Identity | Tarrant County RP - Staging / Private Phase 1 staging validation |
| Tags/slots | `staging, qbox, roleplay`; 8 slots |
| Repository fix | `56bdbbb` (`fix: reproduce Enhanced Linux txAdmin deployment`) |
| Source commit deployed | The live manual b139/systemd state predates `56bdbbb`; deploy that commit with the commands below. Exact live Git HEAD was not available without VPS shell. |

## 3. Acceptance matrix

Evidence labels: **automated-public** was independently obtained over the network; **automated-source** came from repository tests; **operator-live** is the supplied observation from the current VPS/client; **unavailable** requires authenticated VPS or desktop access.

| Area | Result | Evidence |
| --- | --- | --- |
| 1. Host / service | PASS | **operator-live restart:** `txadmin.service` restarted successfully; txAdmin responded; TCP/UDP 30120 and TCP 40120 listened on b139. **automated-public:** TCP 30120/40120 accepted connections and txAdmin returned HTTP 200. |
| 2. FiveM endpoints | PASS | **operator-live restart:** local and public `info.json` passed after restart; TCP/UDP 30120 listened. **automated-public:** `info.json` and `dynamic.json` HTTP 200; expected name, description, tags, 8 slots, OneSync `true`, 17 advertised resources, and one connected client. |
| 3. Cfx / Enhanced | PARTIAL | **automated-public:** Cfx single-server API lookup for the endpoint returned HTTP 404. **operator-live:** Enhanced direct connection succeeded and `bad_request` no longer occurs. Public browser registration is not proven. |
| 4. Database | PARTIAL | **operator-live restart:** MariaDB/oxmysql reconnected, `database=true`, and `ox_inventory` loaded 301 items. **automated-public:** TCP 3306 was not publicly reachable. Current schema/character contents still require a safe database check. |
| 5. Required resources | PASS | **operator-live restart:** all 11 required resources started. **automated-public:** live `info.json` advertised `oxmysql`, `ox_lib`, `ox_inventory`, `ox_target`, `qbx_core`, `qbx_spawn`, `qbx_hud`, `qbx_vehicles`, `illenium-appearance`, `pma-voice`, and `tarrant_ops`. |
| 6. tarrant_ops | PASS | **operator-live restart:** staging startup readiness passed with `healthy=true`, `database=true`, and all required live resources started; operational character event evidence was previously recorded. |
| 7. Character system | PARTIAL | **operator-live:** client connected, appeared in txAdmin, and reached character creation; creation event was recorded. Character load, row contents, and starting money need the manual test/query below. |
| 8. Persistence | MANUAL TEST REQUIRED | No current disconnect/reconnect evidence for the new staging character was available. Repository historical evidence does not substitute for this deployment. |
| 9. Inventory | PARTIAL | **automated-public:** `ox_inventory` advertised. **operator-live:** 301 item definitions loaded. UI and current-character persistence need manual testing. |
| 10. HUD | MANUAL TEST REQUIRED | **automated-public:** `qbx_hud` advertised. Visual rendering requires a client. |
| 11. Chat | MANUAL TEST REQUIRED | **automated-public:** `chat` advertised. Send/receive requires a client. |
| 12. Money | PARTIAL | Qbox persistence mechanisms and prior regression evidence exist in the repository, but current staging-character initialization/persistence was not independently queried. |
| 13. Voice | MANUAL TWO-PLAYER TEST REQUIRED | **automated-public:** `pma-voice` advertised. Bidirectional proximity/radio audio needs two real clients. |
| 14. Appearance | PARTIAL | **automated-public:** `illenium-appearance` advertised. **operator-live:** character-creation flow was reached. Visual correctness and focus exit remain manual. |
| 15. Security | PARTIAL | **automated-source:** `.env`, `*.private.cfg`, runtime and txData are ignored; public-listing regression tests pass. **automated-public:** 3306 not reachable, 30120 reachable. TCP 40120 and its HTTP UI are publicly reachable, which remains hardening work. Live private-file mode, firewall and loaded cfg graph need VPS checks. |
| 16. Backup / restore | PARTIAL | Checksummed development backup/restore tooling and non-destructive validation documentation exist; b139 rollback is documented and the old artifact is operator-confirmed preserved. A current staging backup/path was not validated and no destructive restore was attempted. |
| 17. Portability / reproducibility | PASS | **automated-source:** b139 URL/build/checksum pin, side-by-side installer, environment isolation, secret ignoring, listing validation, literal dotenv parser, deployed-runtime resource lookup, and generated b139 systemd unit all passed regression tests. |
| 18. Log review | PARTIAL | **operator-live:** readiness, database connection, 301 item load, required starts and character event succeeded; old incompatible launch arguments were removed. Full current journal/FXServer logs were unavailable, so absence of crashes, argument mismatch, or recurring warnings was not independently established. |

## 4. Endpoint evidence

The audit intentionally extracted only non-secret fields:

- TCP 30120: open.
- Public `info.json`: HTTP 200; correct project metadata/tags; OneSync enabled; 17 resources.
- Public `dynamic.json`: HTTP 200; correct hostname; 1/8 clients at audit time.
- TCP 3306: not reachable from the auditor.
- TCP/HTTP 40120: publicly reachable and HTTP 200.
- UDP 30120: the supplied live packet capture/external `infoResponse` evidence passes; the auditor's local UDP probe received no response and is not treated as a contradictory FAIL because the ad-hoc probe could not validate protocol compatibility.

## 5. Issues

### Critical

No critical runtime failure is proven. A successful Enhanced client connection is the strongest application-path evidence.

### Non-blocking

1. Cfx public single-server lookup returns HTTP 404; public registration/browser discovery remains pending or absent. Direct connectivity works.
2. txAdmin 40120 is publicly reachable. Restrict it to an approved admin CIDR, VPN, SSH tunnel, or reviewed authenticated reverse proxy without affecting public 30120 TCP/UDP.
3. Repository commit `56bdbbb` has not been proven deployed on the VPS; the equivalent systemd change is currently manual.
4. The existing `tests/check-week2-health-log.ps1` fixture failed locally because `check-week2-health.ps1` also probes live local services and none were running on the audit workstation. This is an environmental/non-isolated fixture failure, not evidence of a staging failure.
5. A Linux-specific current staging backup was not validated. The available backup script is PowerShell/development-oriented; provider snapshots or a reviewed Linux backup path should be formalized before production.

## 6. Remaining manual tests

Sanjay should perform this shortest safe client sequence with the existing test character:

1. In FiveM Enhanced press **F8**, enter `connect 162.35.117.174:30120`, then close F8.
2. Select the existing test character; do not create/reset another character solely for the audit.
3. Confirm spawn, then use **W/A/S/D** and mouse movement.
4. Confirm HUD, open inventory with the configured inventory key, and close it.
5. Press **T**, send a harmless test message, and confirm it appears.
6. Record the displayed cash/bank and one non-sensitive inventory item/count.
7. Complete/exit appearance UI and confirm keyboard/mouse focus returns.
8. Disconnect normally, reconnect with the same command, select the same character, and verify position (where supported), money and inventory persist.
9. For voice, connect a second real player; verify bidirectional normal proximity audio, distance falloff/cycle, and radio only if the character has legitimate radio access.

Do not manufacture balances/items or edit database rows to make these pass.

## 7. Controlled restart

A controlled live restart was performed after deploying commits `886518f` and `56bdbbb`. `txadmin.service`, txAdmin HTTP, TCP/UDP 30120, TCP 40120, local/public `info.json`, MariaDB/oxmysql, all required resources and `tarrant_ops` health recovered successfully. **Restart acceptance: PASS.** Character persistence across the restart is not accepted because the client has not yet completed the required reconnect/persistence test.

## 8. Safe VPS deployment and verification commands

These commands preserve runtime, txData, resources, private cfg and database. They do not print secret contents:

```bash
cd /opt/randy-2
git pull --ff-only origin main
git rev-parse --verify HEAD

PROJECT_OWNER="$(stat -c '%U' /opt/randy-2)"
test -x /opt/randy-2/server-binaries/enhanced-129/run.sh
test -d /opt/randy-2/txData

PROJECT_ROOT=/opt/randy-2 SERVICE_USER="$PROJECT_OWNER" TXADMIN_PORT=40120 \
  bash scripts/render-txadmin-systemd.sh /tmp/txadmin.service
grep -E '^(Environment=TXHOST_|ExecStart=)' /tmp/txadmin.service
! grep -Eq '\+set[[:space:]]+(txAdminPort|txDataPath|serverProfile)' /tmp/txadmin.service

sudo cp -a /etc/systemd/system/txadmin.service "/etc/systemd/system/txadmin.service.pre-repo-$(date -u +%Y%m%dT%H%M%SZ)"
sudo install -m 0644 /tmp/txadmin.service /etc/systemd/system/txadmin.service
rm -f /tmp/txadmin.service
sudo systemctl daemon-reload
sudo systemctl enable txadmin.service

sudo systemctl stop txadmin.service
sudo systemctl start txadmin.service
sudo systemctl is-active --quiet txadmin.service
sudo systemctl show txadmin.service -p NRestarts -p MainPID -p ExecMainStatus

readlink -f /opt/randy-2/server-binaries/enhanced-129
sudo ss -lntup | grep -E ':(30120|40120)[[:space:]]'
sudo systemctl is-active --quiet mariadb.service

sudo -u "$PROJECT_OWNER" bash scripts/check-qbox-readiness.sh
curl --fail --silent --output /dev/null http://127.0.0.1:30120/info.json
curl --fail --silent --output /dev/null http://127.0.0.1:30120/dynamic.json
curl --fail --silent --output /dev/null http://127.0.0.1:40120/

sudo journalctl -u txadmin.service -b --no-pager | \
  grep -Ei 'fatal|crash|core-dump|failed|error|argument count mismatch|txAdminPort|txDataPath|serverProfile' || true
```

Before accepting the live configuration graph, run the existing recursive validators (they report directive locations but not private values):

```bash
cd /opt/randy-2
bash tests/check-runtime-environment-isolation.sh
bash tests/check-public-listing-config.sh
git check-ignore -q .env runtime/qbox-server-data/staging.private.cfg
stat -c '%a %U:%G %n' runtime/qbox-server-data/staging.private.cfg
```

The private cfg should be owned by the service account and readable only by that account (normally mode `600`). Do not use `cat`, `grep` without a directive-only validator, or `systemctl cat` on units that might contain unrelated secrets.

## 9. Rollback

Artifact rollback remains available through the preserved pre-b139 directory and `runtime/last-enhanced-rollback-path`, following `docs/linux-enhanced-artifact-upgrade.md`. The repository systemd-unit rollback is the timestamped `txadmin.service.pre-repo-*` copy made above. Neither rollback touches runtime data or MariaDB. Do not perform either unless b139/unit regression evidence requires it.

## 10. Tests executed

Passed:

- `tests/check-linux-hosted-deployment.sh`
- `tests/check-linux-artifact-install.ps1`
- `tests/check-public-listing-config.ps1`
- `tests/check-public-listing-config.sh`
- `tests/check-runtime-dependencies.ps1`
- `tests/check-runtime-environment-isolation.sh`
- Bash syntax checks for all new/modified Linux scripts
- `git diff --check`

Not passed:

- `tests/check-week2-health-log.ps1`: fixture also required live localhost MariaDB/txAdmin/FXServer services, which were unavailable on the Windows audit workstation.

## 11. Files changed by the deployment fix

- `scripts/render-txadmin-systemd.sh`
- `scripts/dotenv-utils.sh`
- `scripts/check-qbox-readiness.sh`
- `scripts/check-env.sh`
- `tests/check-linux-hosted-deployment.sh`
- `docs/linux-enhanced-artifact-upgrade.md`
- `docs/phase1-final-acceptance.md` (this report; committed separately)

## 12. Final decision

**PHASE 1: CONDITIONAL PASS**

The technical foundation is suitable to prepare Phase 2 work, but Phase 2 should not be declared operationally started until the same staging character passes reconnect persistence, HUD/inventory/chat/appearance checks, and a two-player voice test. The repository deployment commits and controlled restart now pass. Public Cfx listing is accurately recorded as HTTP 404; it is not a blocker to the proven Enhanced direct-connect path.
