# Agent Operating Contract — Behind the Lanterns

Read `docs/00-CONSTITUTION.md` and `docs/DECISIONS.md` **before** any development work.

## Priorities
1. Preserve the approved sandbox fantasy and non-negotiable design rules.
2. Build **small, verifiable, extensible systems** first; add minimal test content only to prove contracts.
3. Prefer data-driven definitions, explicit IDs, modular boundaries, and deterministic tests.
4. Prefer boring, readable code over clever abstractions, massive generic frameworks, visual-scripting graphs, or one-file monoliths.
5. Never write production behavior that assumes a specific city, NPC, quest, save slot, weapon, or map. Example IDs belong in **fixtures**, not core logic.
6. Keep in-game world truth separate from player knowledge. Discovering a rumor must not spawn a secret already intended to exist.
7. Treat Ink as the narrative orchestration layer, **not** the owner of all gameplay state. State mutations flow through validated game commands.
8. The player must never fight city guards/soldiers/security. Attempting to attack them results in a scripted arrest, not ordinary combat.
9. Prefer lightweight, local validations. Do not create GitHub Actions workflows unless truly necessary.
10. Do not implement a vertical slice as the game's canonical architecture.

## Definition of Done for a system
- A small explicit contract and acceptance tests exist.
- Test fixtures include positive, negative, save/load, and cross-system interactions where relevant.
- No magic identifiers in runtime logic; sample content is disposable or clearly labeled.
- Save compatibility and migration approach are considered before persistence schema changes.
- Minimal content proves behavior; quantity of NPCs/quests/maps is **not** evidence of system completeness.
- No undocumented expansion in scope.

## Decisions and uncertainty
Use **Locked**, **Provisional**, **Open**, **Deferred** consistently. Do not silently turn Provisional or Open proposals into final decisions. Update the decision register and the appropriate GDD when decisions change.

## Repository workflow
GitHub is the project source of truth. Inspect current main, open PRs, and issues before changes. Make one coherent branch/PR per bounded batch. Never force-push main. No mass issue generation or competing feature branches.

## Technology constraints
Godot and 2D fixed 3/4 oblique are locked. Language, exact Godot version, Ink binding, file layout, and mobile export approach require a compatibility decision before the first engine scaffold. Favor text-first assets and agent-readable code; avoid binary/graph-only gameplay logic without a compelling case.
