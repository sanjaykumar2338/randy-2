# Launch baseline acceptance ledger

Updated 2026-10-02. Milestone: **Three Jobs, Spend/Consume, Two-Player Voice,
and Protected-System Regression**. Status: **automated/documentation delivery
complete; live acceptance incomplete**. This is not a launch approval.

This runtime update changes only the Enhanced Linux artifact manifest, its
explicit approval test, and artifact/deployment acceptance documentation. No
gameplay resource, active server configuration, database, downloaded artifact
binary, or VPS was modified. Nothing was deployed or restarted. The official
b161 archive and extracted chat test fixture are local ignored files only.

## Evidence rules and environment

- **AUTOMATED PASS**: a test executed on this workstation on the date above.
  Mocked natives, players, balances and saves are not live gameplay evidence.
- **ESTABLISHED LIVE PASS (user-reported)**: expressly confirmed by the operator
  in the milestone authorization; not independently rerun by this agent.
- **HISTORICAL PASS**: older documentation, not acceptance of the current release.
- **PENDING LIVE**: actual players/operator must execute and record the procedure.
- **FAIL / ENVIRONMENT BLOCKED**: retain the actual failure; never convert to PASS
  because code exists or an older session passed.

Audited source baseline: `28ff6dac4d35733d5b52e150cc57af45b4691e7a`.
The approved Linux manifest now pins Enhanced **161**. Enhanced b156 was the
previously accepted live runtime, but FiveM now requires b161 for Enhanced client
connections. **Live b161 acceptance remains PENDING LIVE** until the controlled
VPS deployment and the runtime/gameplay checks below are completed.
The ignored local `runtime/qbox-server-data` is older than the reported VPS.
Its OX/voice values below are the exact inspected local values, not a claim that
the current VPS has identical configuration. Live deployed HEAD, resource hashes,
effective convars and artifact path are **not independently captured**.

Before recording new acceptance, the operator should note server/environment,
artifact/build, tester/client, date/time/timezone, character alias (no private
identifiers), deployed commit if known, and any known configuration differences.
If unavailable, record UNKNOWN rather than inventing a version. Read existing
operator evidence only; this delivery authorizes no VPS edits or restarts.

## Established live baseline

All entries below are **ESTABLISHED LIVE PASS (user-reported)**, supplied in the
2026-10-01 authorization. Original session timestamps/log attachments were not
provided here. Preserve these results; they are not new tests by this agent.

| Accepted behavior | Scope |
| --- | --- |
| Enhanced b156 connection | Real client can connect. |
| Character creation/spawn and character persistence | Existing QBX/appearance baseline. |
| Position/health persistence | Reported working. |
| Cash/bank persistence | Reported working. |
| Inventory persistence and HUD | Reported working. |
| Sanitation | Both stops completed; exactly $90 route payout. |
| Civilian death/countdown/hospital recovery | Working `tarrant_medical` recovery. |
| Assets retained after recovery | Money/items preserved. |
| `tarrant_chat` on b156 | Deployed; T -> ESC immediately hides input/background. |
| Chat reuse | Chat reopens and works after the change. |

## Automated results from this delivery

| Test/command | Result | Evidence boundary |
| --- | --- | --- |
| `python -B tests/run-economy-lua.py` | AUTOMATED PASS | Six Lua suites: employment server, world, medical server, medical client, medical surface, employment client marker. QBX/OX/native behavior mocked; no real balances or players. |
| `python -B tests/check-chat-cancel.py --chat runtime/b161-audit/extract/alpine/opt/cfx-server/system_resources/chat --browser "C:/Program Files/Google/Chrome/Application/chrome.exe"` | AUTOMATED PASS | Actual official b161 bundled UI and Lua callbacks in Chromium/Lupa; FiveM natives stubbed. Both stock chat hashes equal the previously approved values. |
| `tests/check-linux-artifact-install.ps1` | AUTOMATED PASS | Approved b161 pin, exact official source/checksum, layout and installer safeguards. |
| `tests/check-runtime-dependencies.ps1` | AUTOMATED PASS | Startup ordering, voice pin, configuration/environment safeguards. |
| `tests/check-public-listing-config.ps1` | AUTOMATED PASS | Directive classification and template checks; not current Cfx listing evidence. |
| `tests/check-linux-hosted-deployment.sh` | AUTOMATED PASS with SKIP | Git Bash fixture paths/metadata now derive from the approved manifest; arbitrary-launcher rejection and service/env checks retained. Real Linux compatibility-symlink branch SKIPPED: host cannot create symbolic links. |
| `tests/check-runtime-environment-isolation.sh` | AUTOMATED PASS | Temporary configurations only; Linux private-file mode assertion is excluded on Windows by the existing test. |
| `tests/check-public-listing-config.sh` | AUTOMATED PASS | Recursive temporary include fixtures only. |
| `tests/check-week2-health-log.ps1` | FAIL / ENVIRONMENT BLOCKED | Stops at `fields-first-success`; fixture also invokes live localhost service checks. No later fixture case is claimed passed. |
| `scripts/check-week2-health.ps1 -Environment development` | FAIL / ENVIRONMENT BLOCKED | MariaDB running/private; game listener absent, txAdmin listener/readiness check failed, both HTTP endpoints unreachable, old stored startup log lacks required `tarrant_medical` readiness. Not a finding about the VPS. |
| `git diff --check` | AUTOMATED PASS | Final authorized diff checked before commit. |

PowerShell tests use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File`.
Bash tests use the installed Git Bash. No installers or gameplay fault injection
were executed. The health component remains stopped for this milestone: do not
alter/start it to manufacture a passing result. This is an environment-dependent
test failure, not an observed medical gameplay failure.

The PowerShell test keeps an explicit approval guard for build 161 and its exact
official source URL and independently calculated archive SHA-256.
The Bash fixture reads that manifest's build for directory names, install metadata
and expected output. `enhanced-129` remains the existing stable launcher alias;
it does not select build 129. Manifest/installer validation and rejection behavior
are unchanged.

## Historical evidence (not current release acceptance)

| Earlier evidence | Current limitation |
| --- | --- |
| Windows Phase 1 restart/reconnect and isolated backup restore in `week3-phase1-completion.md` | Does not certify the current Linux b161 candidate. |
| Linux b139 controlled restart in `phase1-final-acceptance.md` | Not the current full-resource restart/persistence test. |
| Earlier economy/world fixture passes | Superseded by fresh relevant automated results above; live checklist remains separate. |
| Earlier chat b129 browser test | Superseded by the successful test against the actual b161 Linux bundle; its two stock hashes remain identical. |

## Pending live acceptance register

No rows below have been performed by this agent. All remain **PENDING LIVE**.

| ID | Test | Completion evidence required |
| --- | --- | --- |
| ART-161 | Controlled Enhanced b161 deployment | txAdmin reports b161; service starts; MariaDB/oxmysql connects; required resources, `tarrant_medical` and `tarrant_chat` start; Enhanced client connects and loads the character; inventory/HUD, T -> ESC dismissal and hospital recovery regressions pass. Preserve b156 until complete. |
| JOB-D | Delivery two-stop route | Coordinates/markers, both actions, balances before/after each stop, one $90 payment. |
| JOB-T | Transit two-stop route | Same, using Transit stops and action text. |
| JOB-N | Employment negative/lifecycle checks | Cancel/retry, duplicate input, invalid stop, reconnect, end shift; no unearned money. |
| ECO-1 | Earn -> purchase -> consume -> reconnect | Shop identity, displayed prices, cash/bank, item counts, needs, before/after reconnect. |
| ECO-F | Insufficient-funds rejection | Valid carrying capacity/slot, unaffordable total, rejection, no money/item change. |
| ECO-C | Capacity rejection | Valid slot/stack, affordable overweight request, rejection, no money/item change. |
| VOICE-2 | Two-human pma-voice | Bidirectional near/far/mode behavior and reconnect, both testers' observations. |
| CHAT-R | Randy-specific chat | Empty/typed ESC, movement/focus, reopen/send/receive on Randy's client. |
| REG-1 | Current combined protected-system smoke test | Character/HUD/inventory/world/chat and recovery retain accepted behavior; no source changes. |
| OPS-R | Current full restart/reconnect | Deferred to a separately authorized operator window; state comparison and resource/DB recovery. No restart permitted in this delivery. |

Sanitation's live acceptance remains established; an optional repeat in this
combined test session must be recorded as a new observation, not prefilled PASS.

## Operator checklist: jobs

Source: `resources/[tarrant]/tarrant_employment/{config,client,server}.lua`.
Use normal gameplay, not teleport/money/job commands or injected callbacks.
These are on-foot actions; no parcel inventory, bus, passengers, truck or job
vehicle is required. Begin alive with an unemployed or existing civilian-route
job, in the normal public world. Appointed police/EMS jobs cannot be replaced.

Employment Center: **(195.0, -933.0, 30.7)**, City Hall/Legion civic plaza,
map label **Tarrant County Employment Center**. A yellow/orange cylinder appears
within 25 m (visual Z 29.8). Within 2.5 m expect **[E] Employment Center**.
Press E and select the exact menu entry below; menu ordering is not guaranteed.

| Route / job ID | Menu label | Stop 1 (XYZ) | Stop 2 (XYZ) | Action prompt |
| --- | --- | --- | --- | --- |
| Sanitation / `garbage` | Sanitation - litter collection | 163.5, -1005.7, 29.4 | 113.6, -1038.5, 29.3 | [E] Collect litter |
| Delivery / `trucker` | Delivery - local parcels | 120.8, -926.0, 29.8 | 24.5, -1346.3, 29.5 | [E] Deliver parcel |
| Transit / `bus` | Transit - stop inspection | 115.3, -784.1, 31.4 | 141.8, -1028.4, 29.4 | [E] Inspect bus stop |

For each pending route:

1. Record cash `C0`, bank `B0`, job/duty, health, position, inventory item counts
   and time. Avoid other spending/transfers during the route.
2. Select its menu label. Expect on-duty notification, a routed blip and waypoint
   for stop 1. The current stop has a purple cylinder within 35 m, drawn at
   configured Z minus 0.9. Only the current task is marked.
3. Walk within 2.5 m and press E. Expect its action text and a **13-second** progress
   circle; movement/vehicle controls/combat are disabled during the action.
   Server validation requires at least 12 seconds and distance at most 4 m.
4. Complete stop 1. Expect waypoint/marker to advance to stop 2. Record cash/bank:
   **no route payout yet** (`C1 = C0`, absent unrelated cash changes).
5. Complete stop 2 the same way. Expect completion notification, route removal,
   and **exactly $90 cash once** (`C2 = C0 + 90`). Record both balances and time.
6. Return to the center and select **End shift / go off duty**. Record job/duty.
   Normal reconnect should retain job and earned money, not an unfinished route.

Local QBX configuration separately pays these grade-zero jobs **$50 bank every
10 minutes while on duty**. Completion clears the route but does not end duty.
Record any payroll notification separately; do not label it a second route
payment. Live payroll settings must be confirmed from observed/operator evidence.
QBX save calls are asynchronous; the reconnect check establishes actual retention.

### Job failure/repeat cases (after the first clean completion)

- **Cancel:** on a fresh route, start stop 1 and press the bound Cancel Progress
  key (local OX default **X**) after 2-3 seconds. Expect no advancement or payment.
  Retry and complete normally. ESC is not the documented progress-cancel binding.
- **Duplicate input:** press E again during progress, then again after final
  completion. Expect only one action/payment; no completed-route task prompt.
- **Wrong order/distance:** on a fresh route visit stop 2 first, then press E
  outside the 2.5 m stop-1 interaction range. Expect no task completion/payment.
  This tests the normal UI; it is not proof of rejection of malicious callbacks.
- **Disconnect:** complete only stop 1, record money, disconnect normally and
  reconnect as the same character. Expect no partial-route payment or route
  restoration. Start afresh at the center; job and already-earned money remain.
- **End shift:** start a route, then end it at the center before completion.
  Expect route removal/off duty and no $90 payment; revisit the stop to check.
- **Expiry:** if time allows, leave a route unfinished for more than 30 minutes.
  Next attempt should reject/clear it and request a fresh shift; no payout.
- **Role protection:** only with an already-appointed tester, try selecting a
  civilian route. Expect rejection and unchanged appointed job; never grant a
  role solely for this test under this milestone.

Raw callback replay, early completion, wrong bucket/character/death and payment
failure are covered by the mocked server suite. They are **automated evidence**,
not completed live adversarial tests. Do not install a test client or inject
events on the production server. Death-related regression uses the existing
recovery checklist below; do not intentionally create unsafe test conditions.

## Operator checklist: exact OX shop and consumables

Inspected files under `runtime/qbox-server-data`:
`ox.cfg`, `resources/[ox]/ox_inventory/data/{shops,items}.lua`,
`modules/shops/{client,server}.lua`, and `modules/bridge/qbx/client.lua`.
No OX files were changed. Compare these values with the actual live shop before
testing; a mismatch is an environment difference to record, not grounds to edit OX.

Use **General shop 1**, displayed name **Shop**, beside Delivery stop 2:

- Location/blip reference: **(25.7, -1347.3, 29.49)**.
- Active local target point: **(25.06, -1347.32, 29.5)**, distance **1.5 m**;
  target box length 0.7, width 0.5, heading 0, Z bounds 29.5-29.9.
- Local `inventory:target=true`. Stand at the counter, hold **Left Alt**
  (`ox_target:defaultHotkey LMENU`, toggle disabled), aim at the target and
  left-click **Open Shop**. Player bindings may override the configured default.
- No employment-style cylinder is expected at the shop. If the live server uses
  non-target mode, document the difference and use its existing point/prompt at
  the location reference; do not change configuration.

| Item ID / label | Base configured price | Local randomized displayed price | Weight | Successful use |
| --- | --- | --- | --- | --- |
| `burger` / Burger | $10 | $8-$12 per unit | 220 g | 2.5 s use; one consumed; hunger +20, capped at 100 |
| `water` / Water | $10 | $8-$12 per unit | 500 g | 2.5 s use; one consumed; thirst +20, capped at 100 |
| `sprunk` / Sprunk | $10 | $8-$12 per unit | 350 g | 2.5 s use; one consumed; thirst +20, capped at 100 |

**Prices are not fixed at $10:** local `set inventory:randomprices true` uses
`ceil(basePrice * randomInteger(80,120) / 100)` when shop items are prepared.
Use the price actually displayed for that item/session. These purchases use the
`money` inventory currency synchronized with QBX **cash**, not bank.
Local player limits are **50 slots / 85,000 g**; use the live inventory's actual
capacity when calculating rejection tests. The QBX bridge converts the item
status value 200000 to +20; regular needs decay can affect observations.

### ECO-1: earn, buy, use, reconnect

1. Complete the clean Delivery test without grants. At the nearby shop, record
   cash/bank, displayed Burger/Water prices `Pb`/`Pw`, existing counts `Nb`/`Nw`,
   current inventory weight/limit and hunger/thirst. Capture the shop UI.
2. Buy **two Burger and two Water** into empty slots or compatible existing
   stacks. Expect counts `Nb+2`, `Nw+2`; cash deduction **2*Pb + 2*Pw**; no shop
   deduction from bank. The local randomized total is $32-$48, below route pay.
3. Close the shop. Open inventory (local default **TAB**) and use one Burger and
   one Water, waiting for each action to finish. Expect counts `Nb+1`, `Nw+1`,
   needs increased as above, no additional money deduction, normal controls.
   Test below full needs to observe an increase; do not starve or edit metadata.
4. Return to the center and end shift to limit subsequent payroll interference.
   Record cash/bank, retained item counts, health/needs and position immediately
   before normal disconnect. Reconnect to the **same character**.
5. Record the same fields immediately after load. Paid cash/item changes must
   persist exactly, with no duplicated purchases or returned consumed items.
   Explain separately any observed payroll/needs decay; do not excuse unexplained
   money/item differences. Check HUD, inventory and movement/focus still work.

### ECO-F: insufficient funds (not capacity)

Record cash `C`, displayed Burger price `P`, and free weight `F` in grams. Choose
quantity `Q = floor(C/P) + 1`. Use an empty slot or compatible Burger stack and
verify **220*Q <= F** before attempting the normal shop purchase. Expect
**You can not afford that (missing ...)** and unchanged cash/bank/items.
Record requested count, total, rejection and before/after values. If the UI
prevents submission, record UI rejection only; server rejection remains pending.
If the capacity precondition fails, use a legitimately lower-cash tester or leave
this case pending; do not alter balances, discard valuables or use admin grants.

### ECO-C: capacity (not funds)

Record free weight `F`, cash `C` and displayed Water price `P`. Choose
`Q = floor(F/500) + 1`, with an empty slot or compatible Water stack. Require
**Q*P <= C** so only weight prevents purchase. Expect
**You can not carry that much**, no deduction and no added Water. Local shop code
checks weight before funds, so an unaffordable overweight order does not isolate
capacity acceptance. If the UI caps quantity or sufficient legitimate cash is
unavailable, record the limitation and leave server capacity acceptance pending.
Do not mass-buy items just to fill inventory or change capacity configuration.

An optional occupied-incompatible-slot attempt should reject stacking without
changing balances/items; it is distinct from the weight test. Do not conflate
UI prevention with a server-side rejection that was never reached.

## Operator checklist: two-human voice

Source: local `voice.cfg`, `pma-voice/shared.lua`, and client commands/proximity.
Native audio is enabled; default mode is Normal, mode cycling enabled, configured
cycle key **GRAVE** (backtick). Existing user key mappings may override this.
Local modes are Whisper 1.5, Normal 3.0, Shouting 6.0 native proximity units.
The resource uses a larger candidate-target range for native audio, so these
numbers are **not certified exact audible cutoffs in metres**. Measure behavior.

1. Two real humans A/B join the same server/public world and meet in the open
   City Hall plaza at the Employment Center. Both record client/audio devices,
   selected voice mode and configured push-to-talk key. Use that PTT binding;
   this resource does not establish a universal keyboard PTT key for both users.
   Use headphones and mute external call audio to avoid mistaking it for game voice.
2. Stand about 1 m apart, both on **Normal**. A says "A normal one two three";
   B repeats what was heard through game voice. Swap roles with a different
   phrase. Record audible/clear/dropouts for both directions and talking indicator.
3. A remains still and speaks short numbered phrases while B walks along an
   unobstructed plaza line, checking approximately 2, 5, 10 and 25 m separation.
   Record attenuation and where speech disappears. At 25 m expect no proximity
   voice with these defaults. Return to 1 m and verify immediate recovery.
   Repeat with B speaking and A moving. Distances are observation points, not
   assertions of sharp native-audio cutoffs.
4. At 1 m, cycle the speaker through **Whisper -> Normal -> Shouting** using
   GRAVE until the desired UI label appears. For each mode repeat the outward
   walk and return; record audible range. Whisper should be shorter-range than
   Normal and Shouting longer-range in the same conditions. Swap speakers and
   repeat. Both return to Normal afterward.
5. B disconnects normally and reconnects to the same character. At 1 m repeat
   both directions, then the far/return check. Repeat with A reconnecting.
6. When doing the protected recovery test, check both directions again after
   hospital recovery. Record this separately if recovery is not repeated today.

Do not grant radios, set radio channels through exports, or install phone/radio
resources. This milestone accepts **proximity voice**. Radio/phone voice is not
proven by this test; no usable radio integration was found in the local resource
inventory. Existing in-game proximity input/settings are the only controls used.

## Operator checklist: Randy chat and protected regression

Randy uses his own Enhanced client and records his existing chat visibility mode.
For the when-active scenario, use existing F8 command `toggleChat whenactive`,
close F8 and restore his original mode after testing.

1. T -> release -> ESC: input/background disappear immediately; movement/camera
   work and no unintended draft is sent.
2. T -> type a harmless unsent draft -> ESC: same outcome; reopen and confirm
   cancellation, not accidental submission.
3. T -> send a harmless message with Enter: normal send/history. Another player
   sends a reply after ESC; normal display/fade returns. Reopen again.
4. Record Randy-specific PASS/FAIL and screenshots/short recording. Existing
   acceptance on another client does not fill this row automatically.

For the combined smoke test, record character alias, position, health, cash/bank,
item counts and HUD before/after normal reconnect. Visit the established City
Hall, APD (434.7,-981.9,30.7), Hospital (298.6,-584.4,43.3), Fire Station
(200.1,-1634.3,29.8) and Stadium (-250.5,-2030.0,30.1) if performing a world tour;
expect existing labels/rings and accessibility, not newly implemented services.
No resource restart is part of this check.

For a recovery repeat, use an agreed ordinary gameplay death with the tester's
consent, not SQL/metadata commands, injected events or resource changes. Record
money/items, observe the **30-second countdown**, press the existing recovery
E prompt when ready, and expect recovery on a validated hospital exterior.
The exact destination may be any configured valid candidate; the hospital world
marker is not a mandatory spawn coordinate. Verify retained money/items, restored
controls, HUD/inventory/chat and two-way voice. If not performed, keep the new
combined recovery row pending while preserving the established earlier PASS.

## Deferred restart acceptance: OPS-R

**Do not run a restart under this milestone.** At a separately authorized
operator window: record both testers' character/position/health/needs/cash/bank/
items/job and deployment identity; finish or abandon unpaid routes and disconnect
normally; let the operator perform the approved restart. Check actual required
resource states and fresh DB connection/readiness logs, then reconnect the same
characters and compare recorded state. Preserve paid earnings/items; unfinished
routes are intentionally discarded. Verify gameplay/voice/chat afterward.
Capture resource errors and actual save outcomes, not just `SELECT 1` health.
`tarrant_ops` currently omits employment/world/chat from its required list, so
its healthy flag alone cannot close this release test.

## Result template and stop rule

For each live test, copy and fill this record without private identifiers/secrets:

```text
Test ID / date / timezone:
Tester aliases / client build / server build / deployed source (or UNKNOWN):
Starting job/duty / position / health / needs:
Cash before / after / reconnect:
Bank before / after / reconnect / separate payroll:
Item IDs + counts before / after / reconnect:
Shop/item displayed price / requested quantity / weight and limit (if applicable):
Actions, coordinates and observed markers:
Expected result:
Observed result:
Evidence (screenshot/log timestamp; redact private identifiers):
Result: PASS / FAIL / PENDING / BLOCKED
Defect/component and reproduction steps:
```

**If observed gameplay differs from the expected result, stop testing that
component, retain evidence and document the discrepancy. Do not patch, redeploy,
restart, reset player data or retune prices/payments automatically.** Unrelated
safe checks may continue. No gameplay defect has been observed by this agent;
live tests have not been executed. The local health failure above is retained.

The single first live test is **JOB-D: one clean Delivery route**, beginning at
the Employment Center and recording cash/bank before selection and after each
stop. Perform negative tests only after that clean result is recorded.
