# Implementation Status — Behind the Lanterns
**Snapshot through merged PR #20 · 30 October 2026.**
This is the **implementation ledger**, not a new design roadmap or authorization to implement an unapproved feature. The Constitution, Decision Register and GDDs determine design authority; actual main/code, issues and verification documents determine implementation status.

## Status vocabulary
- **Core working**: a bounded, player-facing capability actually implemented, with Godot verification; not necessarily the entire future system specification.
- **Partial**: functionality exists, but important approved aspects are missing or provisional.
- **Not implemented**: no verified production gameplay capability yet; a sketch/fixture/proposal does not change this.
- **Platform unverified**: desktop Godot tests do not imply mobile/Web acceptance.

## Implemented and partial capabilities

| Capability | State | Evidence and boundary |
| --- | --- | --- |
| Transactional session, event scheduling, IDs, native recovery | Core working | [#11](https://github.com/MohamedXIV/behind-the-lanterns/pull/11); no production checkpoint/defeat policy; Web recovery unverified |
| Inventory, finite supplies/containers, commerce and positioning | Core working | [#13](https://github.com/MohamedXIV/behind-the-lanterns/pull/13); aggregate ordinary goods, not all unique-item and ownership policies |
| Optional funded jobs, preparation, reservations and time-based deadline consequences | Core working | [#15](https://github.com/MohamedXIV/behind-the-lanterns/pull/15); bounded delivery/preparation, not every work/crafting mechanic |
| Local navigation, obstacle-aware contextual world interaction | Partial | [#16](https://github.com/MohamedXIV/behind-the-lanterns/pull/16); static rectangular geometry, no general dynamic NPC collision |
| Linked regions, courtyard/workshop interiors, travel and indoor persistence | Partial | [#17](https://github.com/MohamedXIV/behind-the-lanterns/pull/17); technical content, not a production city or housing |
| Real Ink, rumor/knowledge, discoveries and dialogue-triggered domain commands | Partial | [#18](https://github.com/MohamedXIV/behind-the-lanterns/pull/18), [#19](https://github.com/MohamedXIV/behind-the-lanterns/pull/19); small sample narrative, not full social epistemic model |
| NPC schedule availability | Partial | [#15](https://github.com/MohamedXIV/behind-the-lanterns/pull/15); discrete projected positions, not live walking/routines |
| Promise memory, acknowledgement, social consequences, optional follow-up favor | Partial | [#20](https://github.com/MohamedXIV/behind-the-lanterns/pull/20); contextual Work-derived memory, not comprehensive relationships |

## Major roadmap/catalog capabilities not yet implemented
Fishing and its bait/timing/location rules; farming/environmental growth; house ownership/decor; travel between cities by public routes; broader adventure/exploration, stealth, combat, law/arrest/jail; production character visuals/animation/audio/localization; real target-platform lifecycle and acceptance. The exact first-release content boundaries remain an owner decision. Consult [System Catalog](07-SYSTEM-CATALOG.md) and [Production Roadmap](05-PRODUCTION.md) for the complete proposed inventory and dependency directions.

## Platform, verification and save limits
- Last reported [Godot 4.7.2 native verification](technical/NARRATIVE-PLAY.md) for #20: **445 regression/rules assertions + 48 gameplay/UI assertions**, separate-process save/restart, clean startup and GitHub security check. These are reported test results, not independent device validation.
- Native technical save/recovery works; **Web export, browser save synchronization, Android/iOS exports, physical touch/accessibility/device performance and suspend/resume acceptance remain unverified**.
- Disposable playground story/content and save schemas have changed across prototypes; older development saves remain untouched but can be incompatible. There is no production migration policy yet.
- All visual world content remains a deliberately disposable playground, not approved final art or a canonical vertical slice.

## Tracking obligations for every agent/PR
Before doing work, cite its originating GDD/Decision/Issue. During work, keep the relevant issue/PR current. At delivery, **update this file** (or explicitly state and justify that no status changed), record tested vs merely implemented behavior, update acceptance criteria without premature issue closure, and state compatibility limitations and the next **already authorized** dependency-ready task. Do not invent or ratify gameplay scope in this ledger.

**Primary execution tracker:** [Issue #14](https://github.com/MohamedXIV/behind-the-lanterns/issues/14). Original [system inventory](07-SYSTEM-CATALOG.md) is candidate scope, not a to-do list.
