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

## Reusable gameplay capabilities
Favor **shallow inheritance plus composition** of small reusable policies/capabilities over deep combinatorial subclass trees; this is a proposed design policy, not permission to scaffold a generic ECS/trait framework. Use the **World Clock** for in-world time (including future spoilage); do not create a Node or timer per inventory item. Skill modifiers must be **contextual and bounded** so they do not override impossible environmental conditions or species location constraints. Owner-approved direction: bait/timing fishing with geographic fish variety; extensible crop soil/environment/watering/growth rules; short active-play crafting; constrained 2D decoration. Exact implementation schema remains subject to architecture review.

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
Godot and 2D fixed 3/4 oblique are locked. **Web is a target** and **GDScript-first is preferred**, but the language/DI/system-lifetime architecture ADR is still open. [Kiosk on the Nile](https://github.com/MohamedXIV/kiosk-on-the-nile) is verified reference evidence for Godot 4.7.2 + GDScript + inkgd on Web; do not invent a C# prerequisite for Ink. Mobile export and BTL-specific integration still require checks. Read the [Life & Livelihood GDD](docs/08-LIFE-LIVELIHOOD-GDD.md) before implementing inventory, crafting, farming, fishing, housing or trade. Favor text-first assets and agent-readable code; avoid binary/graph-only gameplay logic without a compelling case.
