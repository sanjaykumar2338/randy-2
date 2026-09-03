# Phase 2 Map Implementation Plan

**Plan type:** actionable planning only

**Runtime target:** FiveM for GTA V Enhanced, Linux b139
**Authority boundary:** do not acquire assets, edit live runtime/config, or enable resources until the applicable approval gate is signed off.

This plan turns `docs/arlington-map-master-plan.md` into reversible milestones. Phase 2 establishes a coherent Arlington identity and core RP geography; it does not rebuild Los Santos.

## Milestone 0 — Approvals and acceptance criteria

**Deliverables**

- Written decision on real versus fictionalized branding.
- Approved GTA overlay after an in-game tour: La Puerta entertainment cluster, Pillbox/Mission Row civic core, Davis/LSIA south corridor, Kortz campus satellite, northwest nature/residential zone, and Lake Vinewood destination.
- Phase 2 location list and explicit deferral list.
- Room/interaction brief for police, hospital, fire, City Hall, and the selected job pilot.
- Asset/procurement budget, minimum client specification, client download target, event population target, and rollback owner.
- Deployed-runtime inventory showing all existing map/interior resources and conflicts; record it without copying secrets or modifying the server.

**Exit gate:** Randy approves topology, branding route, gameplay briefs, budget, and performance criteria. No asset search or purchase begins before this gate.

## Milestone 1 — Map survey and technical spike

Work in a separate development profile/branch derived from the verified Phase 1 baseline.

1. Record candidate coordinates, parcel bounds, vanilla IPLs/interiors, roads, parking, emergency access, aircraft paths, water, population generators, and likely conflicts.
2. Capture “before” screenshots and performance samples at Mission Row, Pillbox, Legion Square, Davis Fire Station, Maze Bank Arena, La Mesa, LSIA, Kortz, Del Perro, Richman/Banham, and Lake Vinewood.
3. Create a coordinate register and district diagram. Lock the five first-site envelopes before detailed work.
4. Build one disposable, original sign/prop test resource to prove the Enhanced pipeline; do not deploy it to staging.
5. Verify YMAP extents/flags, archetypes, collision, LOD, manifest behavior, cold-cache download, resource stop/start, and clean removal on Enhanced b139.
6. Compare client/server performance to the Phase 1 baseline and document tool versions.

**Exit gate:** clean rollback, no vanilla map damage, no warnings or visual/collision defects, and an accepted coordinate register.

## Milestone 2 — Core public-safety adaptations

Implement as independently startable resources or clearly separable packages:

- Arlington Police Department at Mission Row.
- Texas Health Arlington Memorial at Pillbox.
- Arlington Fire Station 1 at Davis Fire Station.

Start with original signage, map labels, exterior dressing, and known-good vanilla interiors. Add or buy an MLO only where the approved room brief cannot be met.

**Integration checklist**

- Police: public lobby, duty/briefing, evidence, cells, armory permissions, doors, garage, emergency routing.
- Hospital: reception, treatment/bed interactions, restricted staff space, pharmacy/inventory boundary, ambulance spawn/routing.
- Fire: apparatus apron/bays, duty/locker/day-room abstraction, garage and emergency routing.
- Validate doors/targets/jobs against the chosen Qbox resources before binding data to coordinates.
- Run at least a two-client test for doors, routing, instancing/buckets, vehicle clearance, and simultaneous interactions.

**Exit gate:** each service works alone and together, survives reconnect/restart, has no duplicate interaction points, and can be disabled without affecting Phase 1.

## Milestone 3 — Arlington identity and civic anchor

### 3A. AT&T Stadium identity

Adapt Maze Bank Arena using approved original/licensed signage, district gateway props, map labels, event arrival points, and a limited lobby/concourse shell. Do not build a new spectator bowl in this milestone.

### 3B. Compact City Hall

Use the selected Legion Square/Pillbox government-like shell. Deliver a public counter, council/court multipurpose room, compact staff office area, doors/permissions, and exterior civic wayfinding.

### 3C. District continuity

Add restrained road/district signs that make the route among Maze Bank Arena, the civic core, and Davis legible. Signs must not obstruct GTA traffic controls or sight lines.

**Exit gate:** a new player can identify the entertainment and civic districts without external explanation; public-service and event flows work at the approved player count.

## Milestone 4 — First employment/destination pilot

Choose **one** based on approved gameplay, not both by default:

- **GM Assembly pilot, La Mesa:** branded/inspired gate, secure yard, loading/spawn points, and a small office/factory shell. No full production line.
- **Arlington Municipal Airport pilot, LSIA GA sector:** FBO/dispatch, hangar interaction, aircraft storage/spawn, restricted-zone boundary, and safe taxi routing. No runway or terminal replacement.

Integrate only the job, inventory, vehicle, access, and economy functions needed for the pilot. Use neutral branding until rights are recorded.

**Exit gate:** end-to-end job loop, abuse/security review, vehicle routing, persistence, concurrency test, and acceptable streaming/performance.

## Milestone 5 — Commercial/cultural vertical slice

Select one compact destination:

- one Texas Live!-inspired bar/event room in the La Puerta stadium cluster;
- Arlington Music Hall at the Downtown/Textile City pocket; or
- a small Medal of Honor Museum lobby/gallery with stakeholder-reviewed original content.

Do not create multiple empty interiors. The selected destination must have an owner/operator, gameplay loop, event policy, and content/license register.

**Exit gate:** the venue supports a complete scheduled event/business loop and meets audio, art, brand, crowd, and performance rules.

## Milestone 6 — Phase 2 hardening and release

1. Audit every shipped file against its source, license, hash, conversion record, and resource dependency.
2. Test only on Enhanced b139 first; document any later artifact validation separately.
3. Validate daylight/night/rain, collision, portals/rooms, doors, LOD/occlusion, traffic/peds, emergency access, aircraft approach where relevant, and fast district traversal.
4. Measure cold-cache download, client memory/texture budget, CPU/GPU frame time, client/server resmon, hitch warnings, and representative event density on minimum-spec hardware.
5. Run Phase 1 regression checks and gameplay persistence checks. Mapping must not regress database, voice, character, inventory, HUD, chat, or operational readiness.
6. Stage one resource/district at a time with backups and a documented disable/remove rollback. Never test first on the working Phase 1 server.
7. Produce an operator runbook, coordinate register, asset register, known-issues list, screenshots, acceptance record, and deferred backlog.

**Release gate:** Randy accepts gameplay and visual identity; technical owner accepts Enhanced, performance, licensing, security, regression, and rollback evidence.

## Deferred rollout after base Phase 2

Recommended order after the release gate:

1. The unselected GM/airport job pilot.
2. Texas Live! expansion and Downtown/Music Hall.
3. Medal of Honor Museum gallery.
4. Arlington Highlands anchor storefronts, then a limited Parks Mall concourse.
5. Globe Life exterior and Choctaw representation after the stadium-cluster site plan and licensed/original models are approved.
6. UTA multipurpose campus spaces and shuttle connection.
7. River Legacy and Lake Arlington low-density recreation.
8. A small Viridian housing block after the housing architecture is selected.
9. Six Flags/Hurricane Harbor beyond signage and GTA-location adaptation only under a separately approved large-project scope.

## Work package template

Use this checklist for every location:

```text
Location / resource:
Approved site and coordinates:
Gameplay owner and minimum interactions:
Implementation class (adaptation / YMAP / MLO / exterior):
Asset creator, source, license, invoice/version/hash:
Real-brand permission or fictional name approval:
Enhanced-native build or Legacy conversion permission:
Alchemist version/mode/report (if applicable):
Dependencies and load order:
Streaming/download/memory baseline and result:
Collision/LOD/portal/lighting/traffic test result:
Multi-client/job/door/vehicle test result:
Phase 1 regression result:
Rollback procedure and owner:
Randy acceptance:
```

## Scope controls

Pause and request a change decision if a work package requires terrain/water replacement, road-network redesign, vanilla level replacement, more than one new stadium-scale exterior, a full theme/water park, a complete campus/mall/factory, broad physical housing, or an unconvertible/unclear-license asset. Trade scope explicitly; do not absorb these into Phase 2.

No implementation milestone may begin merely because an asset is available. Gameplay need, legal rights, Enhanced compatibility, site fit, performance, and rollback must all pass.
