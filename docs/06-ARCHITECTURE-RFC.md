# RFC 001 — Godot Language, Lifetime, Service Boundaries and DI
**Status: OPEN FOR DISCUSSION — NOT ACCEPTED**
**Date:** 2026-10-29
**Scope:** architecture options and decision criteria, not binding implementation instructions.

## 1. What needs deciding first?

We agreed on Godot, mobile-first, fixed-angle 2D oblique art, authored Ink narratives, semantic knowledge, persistent sandbox systems, and systems-first development. We **have not** agreed on:
- GDScript vs C# vs a deliberate minimal hybrid.
- Root game lifetime and dependency injection.
- Whether global Autoloads, managers, one orchestrator, or UE5-style subsystems should own simulation.
- The authoritative system inventory and what gets saved.
- The Ink runtime plugin, including native mobile/export implications.
- How world simulation advances unloaded regions.

**Do not scaffold production code from this RFC until these are decided.**

## 2. Platform constraints (verified sources, not our own tests)

As of 2026-10-29, Godot **4.7.2 stable** is available; the later 4.8 line is beta. Godot 4 .NET C# can export Android and iOS but official docs still mark that support **experimental**; Godot 4 C# cannot export Web. GDScript remains the simpler engine-native cross-platform option. See:
- https://godotengine.org/download/archive/
- https://docs.godotengine.org/en/4.7/tutorials/scripting/c_sharp/
- https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html

Ink integration options **need real testing**:
- **GodotInk:** official Ink C# runtime and compiler wrapped for Godot, accessible from C# or GDScript, but its installation involves a Godot .NET project and C# compilation; GDScript calls do **not** remove that dependency. https://github.com/paulloz/godot-ink
- **inkgd:** implementation of Ink in pure GDScript; Godot 4 variant lives on a branch, no officially tagged Godot 4 release according to its README; the port is slower than original C# runtime. https://github.com/ephread/inkgd

Do not interpret repository support claims as validated export compatibility on our devices.

## 3. Language decision matrix

| Choice | Benefits | Risks | Consider if |
| --- | --- | --- | --- |
| **A. GDScript-first** | Native Godot workflow, simpler mobile/Web export route, signals/scenes effortless | Less expressive compile-time architecture and standalone tests; GDScript Ink port maintenance/perf tradeoffs | Mobile stability and future web route dominate |
| **B. C#-first (.NET)** | Strong types, interfaces, unit tests, reusable domain libraries, familiar tooling, original Ink runtime | Experimental Android/iOS support; no Godot 4 Web export; .NET build/export complexity | Native mobile + Steam dominate and export probe passes |
| **C. Explicit narrow hybrid** | Use C# for pure simulation/Ink and GDScript for thin node/UI scripts | Boundary duplication, serialization/calls across languages, agent confusion, still inherits C# export limits | A concrete tested benefit outweighs cost |

**Provisional recommendation:** **B, C#-first**, only after a successful **actual Android export + Ink save/load probe**. If export compatibility, footprint, or stability proves unacceptable, reconsider **A** rather than adopting a broad split-language architecture. No user decision is assumed here.

## 4. DI vs global managers vs Godot Autoloads

Godot has scene trees, nodes, resources, signals and Autoloads; it has no 1:1 built-in equivalent of UE5 GameInstanceSubsystem / WorldSubsystem / LocalPlayerSubsystem with the same lifecycle contracts. Godot's official guide says Autoloads are not true singletons and advises limiting global scope to independently scoped concerns:
- https://docs.godotengine.org/en/4.7/tutorials/best_practices/autoloads_versus_regular_nodes.html
- https://docs.godotengine.org/en/4.7/tutorials/best_practices/scene_organization.html

| Approach | Strength | Failure mode | Our stance |
| --- | --- | --- | --- |
| One huge `GameManager` | Easy first 5 days | Unbounded responsibility, giant coupled dependency graph | **Reject** |
| Many globally accessible `*Manager` Autoloads | Convenient calls from any scene | Hidden dependencies, lifetime leaks, poor testability | **Avoid as default** |
| Full DI container / framework | Formal setup and lifetime management | Abstraction, startup/exports/reflection, agent complexity | **Not justified yet** |
| Scene-local nodes + explicit references | Godot-native, reusable and isolated | Needs wiring and defined cross-scene lifetime | **Prefer for presentation & local actors** |
| One composition root + plain services + small Godot adapters | Explicit lifetime/dependencies, unit-testable domain | Need to define composition and disposal carefully | **Preferred candidate** |
| One facade per feature | Clear API for UI/Ink | Turns into god object if allowed to own everything | **Use narrow facades at boundaries only** |

### Proposed lifecycle (needs approval)
```text
Godot Engine / SceneTree
  |
  +-- AppRoot (one persistent bootstrap Autoload Node)
  |      +-- Preferences / platform services (app-wide)
  |      +-- SessionFactory
  |
  +-- GameSession (one active save/run; disposed on load/new game)
  |      +-- Persistent WorldState & PlayerKnowledge
  |      +-- WorldClock
  |      +-- Save / Checkpoint coordinator
  |      +-- Systems: Story/Ink, Region travel, economy, actors, law...
  |
  +-- ScenePresentation (active region, actor nodes, camera, UI)
         +-- RegionController (per region/loaded scene)
         +-- Actor presenters (many, spawned and disposed per region)
         +-- View/UI controllers (HUD, dialogue, inventory, map...)
```
**Lifetime discipline:** App-level settings are not game state; game-session services survive scene changes and are disposed when starting/loading a different game; local scene nodes should not keep state for unloaded NPCs or persistent world entities.

### DI recommendation (candidate)
- **Manual constructor injection** into plain C# domain services (or explicit `setup(dependencies)` if GDScript is chosen).
- One simple composition root wires implementations in known order, validates dependencies at startup and disposes session scope.
- No global `GameManager.Instance.GetAnything()` from every script.
- Node-facing adapters get the minimal required interfaces/references at spawn/ready. Godot `Node` lifecycles and scene signals remain idiomatic.
- Do **not** introduce Microsoft.Extensions.DependencyInjection (or other container) without a demonstrated need.
- Do not create one interface per trivial class; create abstractions at stateful, testable, boundary-crossing seams.

## 5. Layers and ownership (proposed)
**Content definitions:** stable IDs, immutable descriptions, config and authored Ink; Godot Resources / data files appropriate to the chosen language. Definitions are not save state.

**Pure domain/model:** world clock value, inventory rules, economy formulas, knowledge facts, actor schedule calculations, law rules. As node-free as practical.

**Application/session services:** coordinated operations: rest/advance-time, trade/purchase, travel, reveal/discover, arrest/release, load/save. These invoke domain rules and persist a consistent state.

**Godot presentation/adapters:** Nodes, scenes, input, UI, animation, collision and transitions. These render state and submit intents; they are not the canonical owner of offscreen state.

**Narrative adapter:** Ink text/choices and tags, semantic inputs and validated commands. Ink does **not** directly rewrite scene nodes or serialize an independent second universe.

## 6. Communication: commands, queries, events, and signals
A modest mix, not an enormous enterprise CQRS framework:

1. A user/actor **intent** calls a narrow session service, e.g. `TryTravel(routeId)`.
2. The service validates game rules, reads/writes authoritative state atomically enough for save correctness.
3. The service may produce domain notifications such as `TravelCompleted` or `FactDiscovered`.
4. Relevant presenters listen and update visuals; Ink may react through a narrative adapter.
5. Local Godot **signals** remain fine for UI and scene-local notifications. No global opaque event bus for everything.
6. Read-only **queries** such as `CanEnter(locationId)` must not secretly mutate WorldState.

A facade is allowed to aggregate a feature's public operations (e.g. `ITravelService`), not to become the all-knowing game kernel.

## 7. Four cross-system tests that decide architecture quality
**A. Discovery without rumor:** A hidden passage is physically reachable. Entering marks discovery; asking an NPC afterwards reveals tailored dialogue. Rumor-first produces a different conversational path but the same physical location.

**B. Ship travel:** Route availability and price checked against clock, economy and world rules; spending, time advance, actor schedule reconciliation and arrival region persistence happen coherently; travel log is presentation, not a mutation authority.

**C. Guard attack:** Input targets a city guard; ordinary damage/combat targeting is refused, the law service invokes scripted arrest, game time advances, fines/status persist, and Ink can supply jail dialogue without owning the arrest calculation.

**D. Death vs mobile suspension:** A dangerous expedition has a gameplay checkpoint. Suspending/restarting the app must protect appropriate technical progress without letting defeat reload from a later hidden autosave and bypass the checkpoint cost. Final user-facing rollback rule remains **OPEN**.

## 8. Godot-specific design boundaries
- Per-region NPC sprites/physics are short-lived presentations of persistent actor definitions/states.
- Not all offscreen actors run `_Process` or pathfinding each frame; reconcile schedule and coarse consequences when appropriate.
- Explicit region identity; avoid storing direct `NodePath` references as the only persistence mechanism.
- Deterministic seeded randomness for authored-independent simulation; separate cosmetic randomness where necessary.
- Time and inventory state must be updated once, not in UI or Ink callbacks.
- Treat performance on real Android targets as a required verification step; desktop editor speed is not acceptance evidence.
- UI has mobile landscape safe-area, touch hit targets, and desktop-debug mapping.
- No global service may assume `Alexandria`, `StableBoy`, or `Quest001` identifiers.

## 9. Decision gates before the first production scene
1. Decide intended release order: Android, iOS, desktop/Steam, any Web target.
2. Run a minimal Godot 4.7.2 **.NET Android build** and Ink runtime test, including saves, with reproducible evidence.
3. Compare with a tiny GDScript + inkgd path if the .NET build/probe fails or Web is vital.
4. Decide language, Ink integration, lifetime root and manual DI boundaries.
5. Accept a **minimal canonical system inventory**; defer detailed submodules.
6. Turn decisions into an accepted ADR and update `docs/DECISIONS.md` and AGENTS.md.
7. Only then scaffold the core runtime.

## 10. Explicitly unresolved
- Exact lifecycle implementation, save/checkpoint contract and minimum pure-domain boundary.
- Whether a `WorldSession` or `GameSession` owns simulation per run.
- Whether GDScript-compatible narratives require a C# runtime dependency.
- Which systems ship in first public release versus subsequent updates.
- Whether any UI systems should become separate Autoloads.
- Detailed editor tooling and on-disk content schema.

**This is a discussion document. Nothing here overrides the Constitution or decides the language.**
