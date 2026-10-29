# Behind the Lanterns
**Working title** · Systems-driven cozy folklore sandbox · Godot · Mobile-first

> A little life in a world larger than you.

**Behind the Lanterns** is a 2D open-ended sandbox adventure drawing its warmth, wonder, and storytelling spirit from *One Thousand and One Nights*. Start as a free young stable worker in a lively city. Earn small sums doing ordinary jobs; meet travelers, animals, merchants, and strangers; listen to rumors—or ignore them and follow your own curiosity. Beyond familiar streets, trade routes, and glowing lanterns lie dangerous places, uncanny encounters, and secrets that **already exist whether or not you know about them**.

You are not a chosen hero, a king, or an outlaw. You can build a modest life, rent a room, tend land, learn a craft, own a home and eventually a personal boat, discover mysteries, evade trouble, and choose when—or whether—to fight. **There is no mandatory main quest or imposed ending.**

## What makes the game distinctive?

| Pillar | In practice |
| --- | --- |
| **Everyday life meets discovery** | Small jobs, trade, crafting, relationships, farming, and household comfort exist alongside voyages and risky exploration. |
| **A real world of legends** | Recognizable places such as Egypt and the Levant sit beside the places sailors dare not visit; history inspires the world but never dictates a date or strict timeline. |
| **Facts exist before quests** | An undiscovered passage is always physically present. A rumor may guide you, but no dialogue flag causes the passage to spawn. |
| **Escape is a valid victory** | Tactical, readable combat against threats; guards/soldiers are **not combat enemies**. Evade, hide, negotiate, or accept consequences such as arrest. |
| **A sandbox, not a checklist** | No required chosen-one plot or end-of-game boss. You are a resident of a world, not the reason the whole world exists. |
| **Respectful cozy design** | Mystery and danger coexist with warmth and belonging; no aggressive retention tricks, paid energy, or predatory monetization. |

### A possible day (illustration, not a scripted quest)
- Help in the stable, deliver a parcel, and spend a little at the market.
- Overhear an uncertain warning about the old harbor; perhaps take a boat toward a known port.
- Wander into an unmarked alley or find an uncharted shore **without** first hearing the warning.
- Avoid a dangerous confrontation, discover a recipe or rare item, and make it home before nightfall.
- Rest in a rented room, grow something on a small piece of land, or talk with a traveling sailor.
- If you break a law, evade the guards; if caught, a fine or jail can also create new relationships and stories.

These are examples of interaction between systems—not mandatory quests or promises of particular launch content.

## Status — 29 October 2026

**Foundational design in review, not a playable game.** The repo initially contained a README and Godot gitignore. PR #1 contains the first substantial design drafts. There is no approved engine scaffold, gameplay architecture, Ink integration, build, or export test yet.

### Agreed
- **Engine:** Godot; **rendering:** detailed 2D high-resolution pixel-art direction, fixed elevated front-readable 3/4 oblique view (not true isometric).
- **Targets:** native mobile in landscape with touch controls **and Web**; desktop/Steam later. **Typed GDScript-first is preferred but not yet ratified**.
- **Setting:** timeless Arabian fantasy informed by *One Thousand and One Nights*, real named lands and fully fictional wonders, no fixed dynasty or year.
- **Structure:** free sandbox, optional story arcs, no mandatory main quest.
- **Narrative:** Ink for dialogue and broader narrative expression; objective World State separated from player Knowledge.
- **Travel:** public ships and caravans on familiar routes, mainly fast travel plus optional short travel logs; a personal decoratable boat is a later progression goal.
- **Combat:** accessible, skill-driven dodge/block/roll/weak-spots; retreat and concealment matter. City guards cannot be fought as ordinary enemies.
- **Production:** systems first, very small replaceable test fixtures, authored meaningful content; **no canonical content-heavy vertical slice**.

### Deliberately not agreed yet
- Selected foundation: **Godot Standard 4.7.2 + typed GDScript**, approved in ADR-001. BTL-specific inkgd integration and Android/iOS export remain unverified.
- Dependency injection / application lifecycle / global managers / system ownership and interfaces.
- Save-vs-checkpoint semantics, the rhythm of in-game time and needs, exact mobile input mapping.
- Starting city's final choice (Alexandria is a candidate) and public-release content bounds.

**Existing project evidence:** [Kiosk on the Nile](https://github.com/MohamedXIV/kiosk-on-the-nile) already runs Godot Standard 4.7.2 + GDScript + vendored Godot-4 inkgd with Web previews; Behind the Lanterns may reuse lessons, but mobile export and integration here remain unverified.

**ADR-001 has been accepted for the narrow runtime foundation.** Other RFCs, exact mechanics and production release scope remain open; do not confuse the accepted architecture with completed code or proven exports.

## Documentation map

| File | Purpose |
| --- | --- |
| [Constitution](docs/00-CONSTITUTION.md) | Locked game principles and anti-goals |
| [Vision GDD](docs/01-GAME-VISION.md) | Player fantasy, everyday/adventure loops, growth |
| [World & Narrative GDD](docs/02-WORLD-NARRATIVE.md) | Timeless setting, travel, world secrets, Ink, semantic knowledge |
| [Gameplay GDD](docs/03-GAMEPLAY-SYSTEMS.md) | Time, careers, housing, combat, law, jail, saves |
| [Life & Livelihood GDD](docs/08-LIFE-LIVELIHOOD-GDD.md) | **Detailed proposal**: items/inventory, crafting/cooking, farming, fishing, housing/placement, vendors/jobs, state, invariants and test contracts |
| [Art & Technology](docs/04-ART-TECH.md) | Visual constraints and technical production direction |
| [Production Strategy](docs/05-PRODUCTION.md) | Systems-first work and verification policies |
| [Architecture RFC](docs/06-ARCHITECTURE-RFC.md) | **Proposed, NOT adopted**: language and DI/autoload/service models |
| [Selective World Simulation RFC](docs/09-WORLD-SIMULATION-RFC.md) | Design rationale and unresolved tuning questions for scheduled/lazy world updates |
| [ADR-001 Runtime Foundation](docs/adr/ADR-001-RUNTIME-FOUNDATION.md) | **Accepted foundation**: GDScript, session scope, time, scheduling, storage boundaries |
| [System Catalog](docs/07-SYSTEM-CATALOG.md) | Candidate systems, responsibilities, state ownership, boundaries |
| [Decision Register](docs/DECISIONS.md) | Explicit Locked/Provisional/Open/Deferred decisions |
| [Agent Contract](AGENTS.md) | Instructions for AI coding agents |

## Development principles

1. Design game **capabilities**, not special cases for named towns, NPCs, quests, or scenes.
2. A system is complete only when a small disposable fixture can verify it with tests.
3. Keep simulation/state, UI/scene presentation, and content authoring distinct.
4. Preserve reality independent of rumors; Ink can request validated game actions, never silently invent world objects.
5. Avoid elaborate generic frameworks, giant game-manager singletons, graph-only code invisible to agents, and one-file monoliths.
6. Prefer lightweight local validation; no GitHub Actions without a real need.
7. Capture significant design changes in the Decision Register; GitHub Issues are the implementation backlog.

## Development roadmap (proposed, not a scope promise)

**F0:** approve detailed design and technical architecture; verify Godot mobile and Ink compatibility.

**F1:** build persistent world model, time, region identity and save/rollback contracts.

**F2:** implement actor interaction, semantic knowledge, narrative command gateway and mobile input.

**F3:** connect basic everyday systems: schedules, ownership, inventory, work, money and relationships.

**F4:** add exploration and consequences: region travel, danger, tactical combat, law/pursuit, arrest and prison.

**F5:** expand hand-authored towns, journeys, encounters and production-quality assets after contracts survive testing.

### Repository

Primary source of truth: [MohamedXIV/behind-the-lanterns](https://github.com/MohamedXIV/behind-the-lanterns). The public title **Behind the Lanterns** remains a working title subject to eventual trademark/store clearance.

Design status is not code status: do not mistake these documents for implemented features.
