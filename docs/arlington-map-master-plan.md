# Arlington-Inspired Map Master Plan

**Status:** planning baseline; no map assets approved or installed

**Prepared:** 2026-09-03

**Runtime target:** FiveM for GTA V Enhanced, Linux b139

## 1. Decision and scope

Phase 2 should create an **Arlington-inspired overlay on the existing GTA V world**, not replace Los Santos and not attempt a geographically exact 1:1 city. The overlay should make the important relationships legible: a concentrated stadium/attraction district, a connected civic/education core, a southern retail/airport corridor, northern residential/natural space, and a western lake destination.

The practical Phase 2 boundary is signage, map labels, routing, reusable street dressing, a few adapted functional interiors, and two or three identity-defining exteriors. A complete stadium trio, operating theme park, UTA campus, GM plant, airport rebuild, or city-wide road replacement would each consume disproportionate mapping and streaming budget and are not Phase 2 defaults.

This document proposes placements; it does not authorize asset acquisition. Final coordinates require an in-game block survey and collision/ownership check.

## 2. Repository and runtime audit

The tracked repository contains one project resource, `resources/[tarrant]/tarrant_ops`, which is server-side Lua with no streamed files. There are **no tracked `.ymap`, `.ytyp`, `.ydr`, `.ytd`, `.yft`, `.ybn`, `.ycd`, MLO, map manifest, or replacement-map files**. The tracked `config/server.example.cfg` starts standard GTA map/session resources and the minimum Qbox/OX stack, then `tarrant_ops`. Downloaded Qbox resources and the active server data are deliberately ignored under `runtime/`; binaries are ignored under `server-binaries/`.

Consequences:

- Mapping starts from a clean project namespace; use separate resources below `resources/[tarrant]` and never edit Qbox/vendor resources.
- Phase 1 config, live runtime, database, and operational resource need no map-planning change.
- Before implementation, inventory the **deployed** ignored runtime for map resources as a separate preflight; the tracked repository alone cannot prove that staging has no manually installed asset.
- Keep each district or large interior independently startable/rollbackable. A small shared resource may own approved signs, map labels, and common props.

Suggested future structure (not created in this planning phase):

```text
resources/[tarrant]/
  tarrant_map_shared/          # labels, common signs/props, shared archetypes
  tarrant_civic/               # civic exterior placements
  tarrant_civic_interiors/     # separately testable MLOs
  tarrant_entertainment/
  tarrant_south/
  tarrant_north_nature/
```

Every map resource should have an `fxmanifest.lua`, `game 'gta5'`, `this_is_a_map 'yes'`, explicit dependencies where needed, a `stream/` directory, source/license provenance, and an asset manifest generated where required. Do not use `replace_level_meta` or replace the GTA map for this plan.

## 3. Zoning strategy

The overlay prioritizes **drive-time topology and recognizable anchors**, not literal Texas scale or a perfect north arrow.

| Arlington concept | GTA foundation | Purpose and relationship |
| --- | --- | --- |
| Entertainment / North Arlington | **La Puerta, Maze Bank Arena, and the north edge of the Port** | Existing arena, freeway access, large industrial parcels, and parking-like hardscape form one concentrated landmark district. Del Perro Pier is a satellite attraction reached on the same west-side corridor. |
| Central / Downtown | **Pillbox Hill, Mission Row, Legion Square, Textile City, and La Mesa** | Dense civic/job area immediately northeast/east of La Puerta. Existing police, medical, government-like, commercial, and industrial shells minimize custom construction. |
| UTA campus pocket | **Kortz Center / northwest Los Santos** | Best existing institutional campus analogue. It is a deliberate satellite of the civic core rather than forcing a fake campus into dense downtown. Shuttle/transit and map labels preserve the relationship. |
| South Arlington | **Strawberry/Davis commercial spine through LSIA** | Retail and employment transition naturally to the existing airport. The airport remains GTA-functional and is rebranded operationally, not rebuilt. |
| North residential / natural | **Richman, Banham Canyon, Tongva approaches, and northern trails** | Existing upscale/planned housing, greenways, and trails support Viridian and River Legacy without urbanizing wilderness. |
| West / southwest lake | **Lake Vinewood and its reservoir access** | A recognizable inland-water destination west/northwest of the core. Use labels, overlooks, and park services; do not alter the water system. |

### Placement rules

1. Keep the three stadium identities and Texas Live! within the La Puerta entertainment district; do not scatter them across unrelated vanilla venues.
2. Treat Del Perro Pier/Six Flags and any Hurricane Harbor representation as named satellite attractions, linked by route branding, because a convincing combined theme/water park beside the stadiums would be a large custom rebuild.
3. Keep police, hospital, fire, City Hall, downtown businesses, and GM within a short central corridor. Their daily RP utility matters more than facade fidelity.
4. Preserve vanilla roads, navmesh, water, and major terrain. Prefer additive YMAP placement and reversible signs/props.
5. Avoid duplicate service interiors during rollout. Move jobs/teleports only after the replacement passes collision, routing, and OneSync tests.
6. Use custom names and inspired silhouettes. Do not reproduce protected logos, trade dress, floor plans, art, or ripped models without written rights.

## 4. Location implementation matrix

“Functional” means players and jobs need usable rooms, doors, routing, and interaction points. “Shell” means an accessible generic interior can support limited RP. “Exterior” means facade/forecourt/photo destination only.

| # | Arlington location | Proposed GTA placement | Implementation classification | Interior target | Effort | Priority | Dependencies / rationale |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | AT&T Stadium | Maze Bank Arena, La Puerta | Existing GTA location adapted/rebranded; existing building + signage/props; optional custom exterior model | **Shell initially:** concourse/event lobby; full bowl not required | MEDIUM | Tier 1 identity | District naming, licensed/original signs, event routing. Existing arena delivers immediate identity and parking/event RP. |
| 2 | Globe Life Field | Large parcel east/northeast of Maze Bank Arena | Custom YMAP; custom exterior model; purchased/licensed asset candidate; ultimately large custom mapping project | Exterior initially; later event entrance/clubhouse shell | VERY LARGE | Tier 3 | Survey parcel/occlusion/collision; original or licensed model. A recognizable ballpark at GTA scale is substantial. |
| 3 | Texas Live! | Between the AT&T and Globe Life representations in La Puerta | Existing building + signage/props; custom YMAP; custom MLO/interior; licensed asset candidate | **Functional:** selected bars/restaurant/event room, not every storefront | LARGE | Tier 2 | Stadium siting, business scripts, door/target/inventory integration, licensing. High nightlife value but multi-venue scope. |
| 4 | Six Flags Over Texas | Del Perro Pier rebranded as a west-corridor satellite | Existing GTA location adapted/rebranded; signage/props; custom YMAP; long-term large custom mapping project | Exterior/open attraction space sufficient; no functional ride interiors | MEDIUM initially / VERY LARGE full | Tier 3 | Route branding and safe boundaries. Reuse working pier attractions; do not promise an exact park. |
| 5 | University of Texas at Arlington | Kortz Center campus | Existing GTA location adapted/rebranded; building + signage/props; custom YMAP; selective MLO | **Functional selected spaces:** lobby, classroom/lecture room, admin/student-services office | LARGE | Tier 3 | Education gameplay, transit link, original university-inspired branding/approval. Campus scale and distance drive effort. |
| 6 | The Parks Mall at Arlington | Davis/Strawberry commercial block | Existing building + signage/props; purchased/licensed mall MLO candidate; custom MLO | **Functional selected businesses** plus common concourse; not every unit | LARGE | Tier 3 | Retail/business roster, economy/inventory/doors, licensed MLO. Multi-tenant interiors are expensive and heavy. |
| 7 | Arlington Highlands | Strawberry/Davis retail spine nearer LSIA | Existing GTA location adapted/rebranded; signage/props; custom YMAP | Functional only for approved anchor businesses; remainder exterior | MEDIUM | Tier 3 | Business selection and parking/traffic survey. Open-air retail can grow storefront by storefront. |
| 8 | River Legacy Parks | Banham Canyon/Tongva trail approaches | Existing GTA location adapted/rebranded; signage/props; custom YMAP | Exterior sufficient; optional ranger/visitor shell | MEDIUM | Tier 4 | Trail route, sparse props, lighting and emergency access. Avoid dense vegetation streaming. |
| 9 | General Motors Arlington Assembly | Large La Mesa industrial complex | Existing GTA location adapted/rebranded; signage/props; custom YMAP; optional custom MLO | **Functional limited areas:** gatehouse, yard, loading floor/office shell; full factory unnecessary | LARGE | Tier 2 | Industrial job design, vehicle/logistics flow, trademark approval, AI/traffic and yard collision survey. |
| 10 | Choctaw Stadium | Secondary venue parcel adjacent to Maze Bank Arena | Existing building + signage/props where a suitable shell is confirmed; otherwise custom YMAP/custom exterior; licensed candidate | Exterior/event forecourt initially; later small event shell | LARGE | Tier 3 | Must remain in stadium cluster; site survey determines whether adaptation avoids another full model. |
| 11 | Arlington Police Department / main station | Mission Row Police Station | Existing GTA location adapted/rebranded; signage/props; existing or licensed Enhanced-compatible MLO | **Functional essential:** public lobby, briefing, evidence, cells, armory, offices, garage | MEDIUM | Tier 1 core | Police job/doors/target/evidence/garage compatibility, branding, secure routing. Adapt before replacing. |
| 12 | Texas Health Arlington Memorial Hospital | Pillbox Hill Medical Center | Existing GTA location adapted/rebranded; signage/props; existing or licensed Enhanced-compatible MLO | **Functional essential:** reception, treatment, surgery/ICU abstraction, staff space, ambulance access | MEDIUM | Tier 1 core | EMS job, beds/revive, doors, pharmacy/inventory, ambulance routing. Keep vanilla-compatible fallback. |
| 13 | Arlington City Hall | Government-like building facing Legion Square/Pillbox civic area | Existing building + signage/props; custom YMAP; selective custom MLO/licensed candidate | **Functional:** public counter, council/court chamber, offices; compact abstraction | LARGE | Tier 1 core | Government/court/records gameplay requirements, doors, permissions, approved seal/branding. |
| 14 | Arlington Fire Station 1 | Davis Fire Station | Existing GTA location adapted/rebranded; signage/props; custom YMAP; selective MLO | **Functional essential:** apparatus bay, lockers, office/day room, spawn/garage | MEDIUM | Tier 1 core | Fire/EMS job and vehicles, doors, apron clearance. Existing station keeps cost controlled. |
| 15 | Lake Arlington | Lake Vinewood/reservoir overlooks | Existing GTA location adapted/rebranded; signage/props; custom YMAP | Exterior sufficient; optional marina/ranger kiosk later | SMALL | Tier 4 | Labels, overlooks, safe access and water activity rules. No terrain/water replacement. |
| 16 | Hurricane Harbor Arlington | Vespucci/Del Perro beachfront near the Six Flags satellite route | Existing GTA location adapted/rebranded; signage/props; custom YMAP; long-term licensed/custom exterior candidate | Exterior sufficient initially; no functional slide interiors | MEDIUM initially / VERY LARGE full | Tier 4 | Decide whether branded beach venue is acceptable. A convincing water park requires custom geometry and safety testing. |
| 17 | National Medal of Honor Museum | Museum/cultural shell on the La Puerta entertainment promenade | Existing building + signage/props; custom YMAP; custom MLO/interior | Exterior plus **small functional gallery/lobby** recommended; full exhibit fit-out later | LARGE | Tier 2 | Stakeholder/content review, respectful original exhibits, audio/art rights, stadium siting. |
| 18 | Arlington Municipal Airport | LSIA general-aviation apron/hangar sector | Existing GTA location adapted/rebranded; signage/props; custom YMAP; selective MLO | **Functional:** FBO/dispatch, hangar access, aircraft spawn/storage; tower optional | MEDIUM | Tier 2 | Aviation job/garage, restricted zones, spawn clearance, routing. Do not replace LSIA or runways. |
| 19 | Arlington Music Hall / Downtown Arlington | Textile City/Legion Square downtown pocket | Existing building + signage/props; custom YMAP; custom MLO or licensed venue candidate | **Functional selected venue:** lobby, stage/auditorium, backstage; surrounding district mostly exterior | LARGE | Tier 2 | Event/business scripts, audio policy, doors, crowd/performance budget, civic district signage. |
| 20 | Viridian residential community | Richman/Banham planned-residential pocket | Existing GTA location adapted/rebranded; signage/props; custom YMAP; purchased/licensed housing interiors candidate | **Functional selected homes/community room**, not every house | LARGE | Tier 4 | Housing system, ownership/instancing decision, garages, address plan, licensed interiors. Roll out a small block first. |

Effort labels are relative and assume professional-quality collision, LODs, lighting, portals, testing, and integration. “MEDIUM initially / VERY LARGE full” deliberately separates a viable Phase 2 representation from an attraction rebuild.

## 5. Interior policy

### Required for useful RP

- Police, hospital, Fire Station 1, and City Hall need compact, reliable functional interiors.
- Arlington Municipal Airport needs an FBO/dispatch and hangar interaction space, not a passenger terminal rebuild.
- Texas Live!, the Music Hall, the mall, Highlands, and GM need interiors only for businesses/jobs selected for launch.
- UTA needs two or three multipurpose rooms only if education RP is approved.
- Viridian needs a small housing sample after a housing system/instancing decision.

### Exterior or recognizable shell is enough initially

Globe Life Field, Choctaw Stadium, Six Flags, Hurricane Harbor, Lake Arlington, River Legacy, and most of the Medal of Honor Museum can launch as exteriors/forecourts. AT&T can use the existing arena shell. No Phase 2 acceptance criterion should require working rides, full spectator bowls, every retail unit, complete factory machinery, or a complete museum collection.

## 6. Enhanced compatibility and technical gates

The production target is the repository-pinned **Enhanced Linux b139** artifact. Asset acceptance must happen on that exact server line and with Enhanced clients.

- Treat every Legacy third-party 3D pack as **unverified** until the creator supplies an Enhanced build or grants conversion rights. Cfx Alchemist converts/refines Legacy `YDR`, `YTD`, `YFT`, `YPT`, and `YDD` assets; retain source and conversion reports. Its GUI stops on escrowed assets, while its CLI can skip and report them. Do not attempt to bypass escrow.
- `YMAP` placement itself is not listed as an Alchemist-converted type, but every referenced custom drawable/texture/drawable dictionary must be Enhanced-ready. Validate archetypes, extents, flags, `_manifest.ymf`, and dependencies after conversion.
- `YBN` collision and `YCD` animation files are not Alchemist conversion targets. That does **not** make an entire MLO automatically compatible: portals/rooms, collision, lighting, entity sets, archetypes, embedded assets, scripts, doors, and audio must all be tested in Enhanced.
- A Legacy MLO is a package, not one file. Require the seller/creator to state Enhanced support, resource dependencies, escrow behavior, update rights, and whether source assets needed for conversion are available.
- Inspect `YDR/YFT` geometry, materials, embedded textures, skeletons, and breakables after conversion; inspect `YTD` memory and visual quality. Reject missing materials, invisible/corrupt meshes, broken collision, light leaks, portal culling errors, or console warnings.
- Prefer additive resources using `this_is_a_map 'yes'`. Do not use a level replacement, IPL suppression, or vanilla building deletion unless a reviewed site plan proves necessity and rollback.

### Performance and streaming budget

Before approving each district, record empty-client and representative-player baselines against Phase 1. Test resource start/restart only in a disposable development profile. Measure client download size, texture/physical memory, frame time, server/client resmon, hitch warnings, population/traffic behavior, and loading while driving rapidly between districts.

Mapping quality gates:

- LOD/SLOD and occlusion behavior at road, aircraft, and skyline distances.
- Correct calculated YMAP extents/flags and no duplicate entities.
- Conservative texture resolution; shared texture dictionaries where licensing and packaging permit.
- Collision, stairs, doors, portals/rooms, night lighting, rain/weather, and emergency vehicle clearance.
- No overlapping MLOs, vanilla props, map holes, z-fighting, invisible walls, or spawn traps.
- OneSync multi-player test at event density; attractions should not add networked scripted entities without a gameplay need.
- Cold-cache join and district-to-district traversal tests on the minimum supported client hardware.

## 7. Asset, licensing, and identity policy

Only use self-created assets, appropriately licensed marketplace/Tebex assets, or assets with written permission covering FiveM, commercial server use, modification/conversion, streaming to clients, and the intended number of servers. Record seller, URL, invoice/license, version, hashes, dependencies, support/update terms, and whether escrow applies in a private procurement register; add a non-secret provenance note to each resource.

Before purchase, require evidence of FiveM Enhanced compatibility and ask whether Cfx Asset Escrow allows the necessary conversion/update flow. Never download leaked, ripped, de-escrowed, GTA/DLC-extracted, or other-game map/model assets. Do not assume “free,” a Discord upload, or marketplace availability grants commercial or modification rights.

Real venue names, team marks, university marks, corporate logos, municipal seals, exhibit media, and exact trade dress may require permission. Randy must choose between licensed real-world branding and fictionalized Arlington-inspired names. Until approved, use neutral working names and original graphics.

## 8. Priority and realistic Phase 2 package

### Tier 1 — Core RP and first identity

Mission Row/APD, Pillbox/Texas Health, Davis/Fire Station 1, compact City Hall, and Maze Bank Arena/AT&T identity. These create repeatable police, EMS, fire, government, and event play with mostly adapted GTA foundations.

### Tier 2 — Jobs and Arlington identity

GM industrial job shell, Municipal Airport FBO, Downtown/Music Hall, National Medal of Honor Museum exterior/lobby, and Texas Live! pilot venue.

### Tier 3 — Destination/commercial expansion

Globe Life and Choctaw representations, Six Flags overlay, UTA, Parks Mall, and Arlington Highlands. These depend on approved businesses, site surveys, or significant assets.

### Tier 4 — Natural/residential breadth

River Legacy, Lake Arlington, Hurricane Harbor representation, and a small Viridian housing block. These deepen lifestyle RP after core jobs and housing systems exist.

### Phase 2 definition of done

A realistic Phase 2 map package is:

1. Approved names/visual language and a locked overlay coordinate plan.
2. Rebranded, functional police/hospital/fire services using proven interiors.
3. A compact functional City Hall.
4. Maze Bank Arena rebranded as the principal stadium anchor, with an entertainment-district gateway/wayfinding layer.
5. One employment/destination pilot: GM gate/yard **or** Municipal Airport FBO.
6. Map labels/routes, performance baselines, Enhanced validation reports, provenance records, and rollback per resource.

That package establishes Arlington without building a custom city. Globe Life, Choctaw, full Texas Live!, UTA, malls, theme/water parks, full museum, and broad housing remain later increments unless Randy approves extra budget/assets and consciously trades out core scope.

## 9. Recommended first locations and rollout

The first five implementation targets are:

1. **Arlington Police Department at Mission Row** — highest recurring RP value and a low-risk adaptation path.
2. **Texas Health Arlington Memorial at Pillbox** — essential EMS loop, paired naturally with police/civic RP.
3. **AT&T Stadium identity at Maze Bank Arena** — the fastest strong visual statement of Arlington.
4. **Arlington City Hall in the Legion Square/Pillbox civic pocket** — anchors government, records, court, and public-service stories.
5. **Arlington Fire Station 1 at Davis Fire Station** — completes public safety and connects the civic core to the southern corridor.

After those pass, implement either GM or the Municipal Airport based on the first approved Phase 2 job. Then add the Texas Live!/Downtown pilot before investing in standalone stadium exteriors.

## 10. Decisions required before implementation

Randy must approve:

- Real branding versus fictionalized Arlington-inspired branding, plus proof of any trademark/logo/seal permissions.
- The topology-first GTA placements after an in-game map tour, especially the La Puerta cluster, Kortz satellite campus, and beachfront attraction compromise.
- Which jobs/businesses actually launch in Phase 2 and their minimum room/interaction lists.
- Whether existing vanilla interiors are acceptable, or which locations require purchased/custom MLOs.
- Asset budget, vendor shortlist, license terms, Enhanced support evidence, and permission to run Alchemist where needed.
- Phase 2 client performance/download targets and minimum client hardware.
- Housing approach (instanced versus physical), event capacity, airport operations, and whether emergency services share any spaces.
- An approval that exact Globe Life, Choctaw, Six Flags, Hurricane Harbor, UTA, mall, and Viridian builds are outside the base Phase 2 scope.

## 11. Reference basis

- Repository evidence: `README.md`, `config/server.example.cfg`, `config/fxserver-linux-artifact.json`, `resources/[tarrant]`, and the Phase 1 acceptance documents, audited 2026-09-03.
- Cfx, [Alchemist documentation](https://docs.fivem.net/docs/alchemist/) — supported conversion types, Enhanced conversion/refinement, and escrow behavior.
- Cfx, [FiveM for GTA V Enhanced onboarding](https://docs.fivem.net/docs/server-manual/onboarding-guide-fivem-for-gtav-enhanced/) — Enhanced asset conversion requirement.
- Cfx, [placing assets and creating map mods](https://docs.fivem.net/docs/assets-manual/beginner-series/part-4/) — YMAP/resource layout and manifest generation.
- Cfx, [resource manifest reference](https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/) — `this_is_a_map`, dependencies, data files, and escrow metadata.
- Cfx, [finding resources](https://docs.fivem.net/docs/server-manual/finding-resources/) — dependency, marketplace, seller, and terms diligence.
