# ADR-001 — Godot Runtime Foundation and Selective World Simulation
**Status: Accepted for the initial runtime foundation** · 2026-10-29 · Scope: technical architecture, not every gameplay mechanic.

## Context
Behind the Lanterns targets native mobile, Web and eventually desktop/Steam. Its many authored regions, NPC routines, plants, items, optional stories and scheduled consequences cannot rely on an always-loaded city scene or per-frame offscreen simulation. The owner favors GDScript, has already validated inkgd on Godot 4.7.2/Web in Kiosk on the Nile, and approved moving forward with this foundation. Prior proposals are in RFC-001/002.

## Decision
1. **Godot Standard 4.7.2, typed GDScript-first**. Use GDScript for the game runtime and tools; no .NET dependency. Consider C++/Rust GDExtension only for demonstrated profiling needs and validated Web/mobile portability. Pin exact addon revisions when integrated. Native Android/iOS export is not yet verified in this repository.
2. **Godot-native composition and shallow inheritance.** One persistent Main scene composes a **single current GameSession**. Services/models without SceneTree needs are RefCounted; active world/UI live in Scenes/Nodes. Content definitions may use Resources. Use manual explicit dependencies; no DI container or omniscient GameManager. Few app-lifetime Autoloads only with a demonstrated cross-session need.
3. **State ownership:** GameSession scopes the clock, scheduler, coordinator and authoritative domain stores; it does not implement their algorithms. Region Nodes and UI represent persistent facts and send commands but do not own offscreen truth. Player knowledge and world facts are distinct. Ink, when added, asks for validated commands through a narrow bridge.
4. **WorldClock:** one monotonic in-game time source. App closure does not automatically advance time by real-world duration; short active fishing/crafting timers use active-play time, subject to later UX tuning.
5. **Selective offscreen execution:** Active local Nodes run in loaded scenes; important consequences are durable scheduled event descriptors that execute on their correct world timestamp even if a region is absent; less consequential state is reconciled lazily **to the result of actual elapsed time** when accessed; static world facts do not tick. Policies apply per event/state, not wholesale per feature. A crop can be lazy while a contract using it is scheduled.
6. **Coordinator / Scheduler:** SimulationCoordinator advances to the next due event chronologically, resolves only dependencies needed at that time, invokes a registered domain handler and commits at-most-once logical effects; then proceeds to target time. WorldScheduler stores data-only event descriptors, not serialized Callables/NodePaths. On failure no unchecked advancing past unresolved consequential events. Stable IDs and ordering. Do not schedule tiny routine ticks for every item/crop.
7. **Persistence:** save WorldClock, world facts, knowledge, pending/completed important events, and lazy state anchors together in a versioned consistent snapshot. Restore into a candidate session before replacing the live one. Serialized state is data, not scene/node references. Avoid save-time mutations and content-specific magic IDs.
8. **Verification:** test a distant crop after five in-game days with no offscreen loop; an important event firing in an unloaded region at its due time; a static secret discoverable without rumor; chronological event order, save/load and idempotence. Use disposable test fixtures, **not** a permanent gameplay vertical slice.
9. **Implementation discipline:** Do not implement a generic trait framework, global event bus, ECS, event sourcing, huge inheritance lattice or dozens of empty managers. Domain services remain coherent, with bounded composable policy objects when needed.

## Explicit remaining decisions
- World minutes per active second; pause/resume behavior for active crafts; priorities and failure-retry rules for scheduled events.
- Runtime Ink adapter details specific to this game, exact plugin revision, Android/iOS export and device acceptance.
- Save/checkpoint semantics after defeat vs technical suspend recovery.
- Concrete item definition schemas and release content scope.
- Data-driven environmental histories for weather/watering and sophisticated domain reconciliation (proposed in RFC-002, not implemented by basic scaffold).
- Whether production needs a more advanced scheduler data structure after measuring actual event volume.

## Consequences
**Benefits:** limited background work, believable distant-world continuity, testable plain GDScript, unified item/world truth, strong Web path and small runtime scope.

**Tradeoffs:** event ordering/idempotence and state history must be designed carefully; not every hidden interaction can be derived from an elapsed-time subtraction. Cross-domain consequences may need explicit scheduled boundaries. Headless tests cannot replace mobile UX/performance and export tests.

## Rejected for the foundation
- C#/.NET-first due to Godot 4 Web export constraints.
- Thousands of global managers/Autoloads or a dependency injection framework.
- Every offscreen actor/crop/item as a live Node receiving every world tick.
- Only updating distant world state *from the moment the player returns*.
- Building a content-heavy village as canonical architecture.

## Supersession

Implementation clarification under review: [ADR-002](ADR-002-TRANSACTIONAL-FOUNDATION.md)
specifies candidate-state atomicity, FIFO ties, identity and native recovery. It
does not treat PR #10 as canonical or alter the locked gameplay principles.
This accepted ADR decides the runtime foundation where it differs from provisional options in RFC-001/002. Those RFCs remain as explanatory design and open-detail references. The Game Constitution still governs game design; ADR-001 does not decide unapproved content or feature scope.

