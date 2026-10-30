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

## Mandatory design authorization and progress synchronization

**Treat project documents and tracked work as binding product authority.** Before choosing a batch or changing gameplay:
1. Inspect actual current `main`, open PRs, and relevant GitHub issues. Read `docs/00-CONSTITUTION.md`, `docs/DECISIONS.md`, the appropriate GDD(s), `docs/05-PRODUCTION.md` (roadmap), `docs/07-SYSTEM-CATALOG.md`, and `docs/IMPLEMENTATION-STATUS.md`. For a given issue, check its latest body/comments and dependencies.
2. Trace each substantial **player-facing system or mechanic** to a confirmed requirement in those sources and an issue/roadmap item. Say which requirement it satisfies in the PR. Documentation may list candidates and proposals: do **not** silently upgrade Open/Provisional/Deferred or candidate items into approved game-design scope.
3. **No self-authorized new gameplay systems, fictional setting decisions, compulsory progression or major mechanics.** If a genuinely valuable idea has no existing authorization, raise it as an explicit **proposal** in the relevant issue (or a focused new issue only when necessary) and wait for owner approval; continue with dependency-ready authorized work. Small incidental UX and necessary engineering details are implementation choices, not new product systems.
4. **Autonomy is for engineering**: select dependency-ready approved features, implementation order, patterns, data layout, UI integration, code refactoring and tests using independent judgment. Challenge technical assumptions when evidence warrants. Product/design changes need explicit approval, not permission inferred from agent enthusiasm.
5. **Update progress during the work and at delivery**, not just in a final chat summary: keep the active issue/PR updated with concise status, blockers, scope adjustments and verification evidence. After a batch, update `docs/IMPLEMENTATION-STATUS.md` in the same PR with implemented/partial/not-started capabilities and links; also update affected issue checklists/status and any design documents/decision register truly changed. Do not close an issue until its actual acceptance criteria are met.
6. If the roadmap or docs disagree with current code, record the discrepancy and source links rather than silently rewriting game design to suit the code. Keep "implemented", "tested", "platform-verified" and "feature complete" separate. Never claim a working mobile/Web build without direct evidence.
7. Handoff between models must be reproducible from GitHub alone: state exact base/main, merged PR links, what actually works, how to run/reproduce, known gaps and the next **approved** dependency-ready work. Avoid repetitive historical narration or invented milestones.

## Repository workflow
GitHub is the project source of truth. Inspect current main, open PRs, and issues before changes. Make one coherent branch/PR per bounded batch. Never force-push main. No mass issue generation or competing feature branches.

**Current gameplay execution policy — owner direction in #14:** Build a substantial
connected gameplay batch code-first. Defer comprehensive test authoring/runs until
the implementation and player-facing integration are complete; do not use stepwise
TDD or rerun full suites after each small feature. Compilation checks are permitted.
At the end run regression, gameplay/UI and save/restart verification together, fix
failures, and merge only after the final combined verification succeeds.

## Technology constraints
Godot Standard 4.7.2, typed GDScript-first, session-scoped composition and selective event-driven/lazy world simulation are accepted in **docs/adr/ADR-001-RUNTIME-FOUNDATION.md**. Web remains a target. [Kiosk on the Nile](https://github.com/MohamedXIV/kiosk-on-the-nile) is verified reference evidence for Godot 4.7.2 + GDScript + inkgd on Web; do not invent a C# prerequisite for Ink. Mobile export and BTL-specific integration still require checks. Read the [Life & Livelihood GDD](docs/08-LIFE-LIVELIHOOD-GDD.md) before implementing inventory, crafting, farming, fishing, housing or trade. Favor text-first assets and agent-readable code; avoid binary/graph-only gameplay logic without a compelling case.

