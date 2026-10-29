# GDD 05 — Production Strategy and System Roadmap
**Status:** initial plan · **Updated:** 2026-10-29

## Explicit rejection: content-first vertical slice
The first deliverable is **not** a decorated small town or a hero demo to be extended forever. Previous vertical slices often accumulate unfinished core logic hidden under authored content. Our approach is **systems-first, content-light** and independently verifiable, with only disposable **test fixtures**.

Systems-first does **not** mean a year of abstract engines before anything is playable. Each bounded system must have executable proof and a narrow gameplay-facing test, but that proof must not become hardcoded production architecture.

## Ordered foundation batches (proposed)
**F0 — Design authority and feasibility**
- Constitution/GDDs, decision register, engineering conventions and GitHub Issues.
- Choose Godot version/scripting language, validate native mobile export path and Ink integration with the smallest possible disposable spike.

**F1 — Core state foundation**
- Definition IDs and data-loading contracts.
- World clock and basic scheduling; deterministic seeded simulation where randomness is involved.
- Persistence and resume/rollback contracts, with save/load tests.
- Region identity and player/location state.

**F2 — Interaction and semantics**
- Input abstraction including touch.
- Interaction/actor/NPC state boundary.
- Semantic Knowledge System, World State authority, narrative command gateway and Ink proof.
- A secret fixture discoverable both before and after hearing a rumor.

**F3 — Everyday systems**
- Inventory, ownership, money, jobs/service transactions, simple schedules, relationships.
- Housing/inn and farming are subsequent feature modules over shared contracts, not separate engines.

**F4 — Adventure and consequences**
- Movement, exploration, visibility/hiding, danger/combat primitives, enemy behavior.
- Travel routing / fast travel / logs and law / pursuit / scripted arrest / prison.
- Checkpoint and death/rollback behavior.

**F5 — Content production and worldbuilding**
- Art Bible and validated asset pipeline.
- Expand authored neighborhoods, relationships, routes, journeys, adventures and encounters with the now-proven systems.
- Performance testing on actual target mobile devices.

These are **dependency directions**, not a promise to implement every named subfeature upfront; re-plan from current evidence.

## A good system milestone
1. Short design contract and invariants.
2. Minimal implementation with clear data/content boundary.
3. Automated tests for normal flow, edge cases, and persistence.
4. A disposable fixture that demonstrates actual player-facing behavior.
5. Independent review of maintainability, performance and extension path.

For example, to verify Knowledge+Ink: create one secret that physically exists from the start; record a rumor, let the player discover it without a rumor, and validate that both paths yield consistent state/Ink results. Delete/replace sample content without changing runtime code.

## Prevent agent-generated prototype debt
- Test content goes under `tests/fixtures` or clearly designated non-shipping scenes/data.
- Avoid one-off overrides for a specific stable, alley, merchant, weapon, or door.
- No broad scaffolding in the absence of a tested need.
- No “system complete” claims without observable test evidence.
- Do not hide technical debt by filling the world with content.
- Review architecture periodically with concrete extension scenarios, not speculative frameworks.

## Scope and release
Mobile-first free game, respectful optional ads (default on but free setting to switch off); cosmetic/supporter purchases and Patreon are **possible** additional support mechanisms, not required for the initial implementation. Steam later. No pay-to-win, mandatory ad removal purchase, premium-energy loops or forced advertising. Legal/platform specifics must be reviewed before publication.

**First coding work should be feasibility and state contracts, not city art or a full game scene.**
