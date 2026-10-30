# Implementation Status — Behind the Lanterns
**Snapshot through merged PR #25 (mobile-first interaction & Web persistence batch) · 30 October 2026.**
This is the **implementation ledger**, not a new design roadmap or authorization to implement an unapproved feature. The Constitution, Decision Register and GDDs determine design authority; actual main/code, issues and verification documents determine implementation status.

## Status vocabulary
- **Core working**: a bounded, player-facing capability actually implemented, with Godot verification; not necessarily the entire future system specification.
- **Partial**: functionality exists, but important approved aspects are missing or provisional.
- **Not implemented**: no verified production gameplay capability yet; a sketch/fixture/proposal does not change this.
- **Platform unverified**: desktop Godot tests do not imply mobile/Web acceptance.

## Implemented and partial capabilities

| Capability | State | Evidence and boundary |
| --- | --- | --- |
| Transactional session, event scheduling, IDs, A/B recovery & Web `/userfs` sync adapter | Core working | [#11](https://github.com/MohamedXIV/behind-the-lanterns/pull/11), [#25](https://github.com/MohamedXIV/behind-the-lanterns/pull/25), [MOBILE-WEB-PLAY.md](technical/MOBILE-WEB-PLAY.md); native and `WebSaveAck` `/userfs` IndexedDB verification implemented; live browser/device acceptance unverified |
| Inventory, finite supplies/containers, commerce and positioning | Core working | [#13](https://github.com/MohamedXIV/behind-the-lanterns/pull/13); aggregate ordinary goods, not all unique-item and ownership policies |
| Optional funded jobs, preparation, reservations and time-based deadline consequences | Core working | [#15](https://github.com/MohamedXIV/behind-the-lanterns/pull/15); bounded delivery/preparation, not every work/crafting mechanic |
| Local navigation, obstacle-aware contextual world interaction | Partial | [#16](https://github.com/MohamedXIV/behind-the-lanterns/pull/16); static rectangular geometry, no general dynamic NPC collision |
| Mobile-first input abstraction, landscape touch controls, safe-area layout & pause/resume | Partial | [#25](https://github.com/MohamedXIV/behind-the-lanterns/pull/25), [Issue #6](https://github.com/MohamedXIV/behind-the-lanterns/issues/6), [MOBILE-WEB-PLAY.md](technical/MOBILE-WEB-PLAY.md); semantic actions, key remapping, running pace, landscape touch D-pad/action cluster, visibility & left/right hand swap, notched safe-area margins and pause/focus state commit verified in Godot 4.7.2; physical touchscreen device acceptance unverified |
| Linked regions, courtyard/workshop/riverbank transitions and indoor persistence | Partial | [#17](https://github.com/MohamedXIV/behind-the-lanterns/pull/17), [#21](https://github.com/MohamedXIV/behind-the-lanterns/pull/21); technical content, not a production city or housing |
| Real Ink, rumor/knowledge, discoveries and dialogue-triggered domain commands | Partial | [#18](https://github.com/MohamedXIV/behind-the-lanterns/pull/18), [#19](https://github.com/MohamedXIV/behind-the-lanterns/pull/19); small sample narrative, not full social epistemic model |
| NPC schedule availability | Partial | [#15](https://github.com/MohamedXIV/behind-the-lanterns/pull/15); discrete projected positions, not live walking/routines |
| Promise memory, acknowledgement, social consequences, optional follow-up favor | Partial | [#20](https://github.com/MohamedXIV/behind-the-lanterns/pull/20); contextual Work-derived memory, not comprehensive relationships |
| Riverside fishing, bait choice, active-time reel window and habitat species pools | Partial | [#21](https://github.com/MohamedXIV/behind-the-lanterns/pull/21), [FISHING-PLAY.md](technical/FISHING-PLAY.md); small starting roster and seeded opportunities, not exotic sea life or skill modifiers |
| Cultivation/farming, environment/soil viability, bounded skill modifiers and lazy offscreen growth | Partial | [#23](https://github.com/MohamedXIV/behind-the-lanterns/pull/23), [FARMING-PLAY.md](technical/FARMING-PLAY.md); data-defined plots/crops, interval watering, five-day offscreen reconciliation and bounded cultivation skill, not seasons/weather history or broad crop rosters |

## Major roadmap/catalog capabilities not yet implemented
House ownership/inn lodging and constrained 2D furniture placement; item perishability/spoilage policies; travel between cities by public routes (ships/caravans) and travel logs; broader adventure/exploration, stealth, combat, law/pursuit/scripted arrest/jail; production character visuals/animation/audio/localization; real target-platform lifecycle and acceptance. The exact first-release content boundaries remain an owner decision. Consult [System Catalog](07-SYSTEM-CATALOG.md) and [Production Roadmap](05-PRODUCTION.md) for the complete proposed inventory and dependency directions.

## Platform, verification and save limits
- Last reported [Godot 4.7.2 native verification](technical/MOBILE-WEB-PLAY.md) (following [#23](technical/FARMING-PLAY.md), [#21](technical/FISHING-PLAY.md) and [#20](technical/NARRATIVE-PLAY.md)): **588 regression/rules assertions + 69 gameplay/UI assertions**, separate-process save/restart across foundation, gameplay, connected, region, narrative, fishing, farming and Web-ack suites, and clean startup. These are desktop headless test results, not independent device validation.
- Native technical save/recovery and `WebSaveAck` (`/userfs` IndexedDB sync/acknowledgment + rollback on unconfirmed flush) are implemented and verified in Godot 4.7.2; **live `.wasm`/`.pck` Web export and browser execution (blocked in container by absent Godot 4.7.2 `web_nothreads` export templates and browser binaries), Android/iOS exports (`adb`/SDK absent), and physical mobile touchscreen/suspend-resume acceptance remain unverified**.
- Disposable playground story/content and save schemas have changed across prototypes; older development saves remain untouched on disk but are rejected by content/domain fingerprint checks. There is no production migration policy yet.
- All visual world content remains a deliberately disposable playground, not approved final art or a canonical vertical slice.

## Tracking obligations for every agent/PR
Before doing work, cite its originating GDD/Decision/Issue. During work, keep the relevant issue/PR current. At delivery, **update this file** (or explicitly state and justify that no status changed), record tested vs merely implemented behavior, update acceptance criteria without premature issue closure, and state compatibility limitations and the next **already authorized** dependency-ready task. Do not invent or ratify gameplay scope in this ledger.

**Primary execution tracker:** [Issue #14](https://github.com/MohamedXIV/behind-the-lanterns/issues/14). Original [system inventory](07-SYSTEM-CATALOG.md) is candidate scope, not a to-do list.
