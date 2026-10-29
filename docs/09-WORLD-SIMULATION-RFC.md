# RFC 002 — Selective World Simulation & Time Advancement

**Behind the Lanterns** · 2026-10-29 · **Status: PROPOSED / owner review; not an accepted Architecture Decision Record**

## Goal and foundational distinction

The world advances while the player is elsewhere, but offscreen objects must not all execute gameplay logic continuously. The player's proposal separates **important persistent consequences**, **less consequential state that can be reconciled from elapsed time**, and **objects that need no update at all**. Add a fourth category for active, loaded-scene real-time interactions.

**Principle:** *The world should behave as though time passed, without simulating every moment of that time.*

A distant field left for five in-game days must show the correctly grown or stressed crop when visited; it must not start growing from the point at which the player departed. But if a contract pays out on day three, that payment and its consequences must occur at day three, not retroactively on day five.

This RFC is design guidance, not permission to create a large simulation framework before the domain contracts are approved.

## 1. Modes: classify work, not entire systems

| Mode | Trigger | Examples | Persistence |
| --- | --- | --- | --- |
| **Active local** | While the scene is loaded, as needed | Player controls, nearby NPC navigation, combat, fishing timing minigame, short active crafting | Commit meaningful outcomes; do not save every visual frame |
| **Scheduled consequential** | World-time deadline or important semantic event, even if region unloaded | A promised NPC visit, caravan delivery, sale deadline, consequential contract, legal sentence completion | Durable event descriptor and its result |
| **Lazy / time-anchored** | Query, action, region load, or an important event's dependency | Remote crop growth, routine NPC position, ordinary vendor availability, future food spoilage | Persistent anchors, relevant history, deterministic projection |
| **Static / on-demand** | An explicit world action changes it; no time passage update | Hidden doorway, ordinary decoration, unchanging geography | Definition and explicit edits only |

**Decision rule:** if *when* a transition happens matters to another system, schedule that transition or an explicit consequential boundary. If only the state at a requested time matters, derive it lazily. If time does not affect it, do not update it.

Distance or player ownership alone does not make a task Scheduled. A player-owned remote crop can be Lazy if nothing depends on the moment it ripens. An unrelated NPC appointment can be Scheduled when it changes a player's relationship or a world agreement. An NPC can simultaneously have Active presentation when nearby, a Lazy routine when distant, and one Scheduled exceptional meeting.

## 2. Roles and ownership

| Component | Role | Anti-responsibility |
| --- | --- | --- |
| **GameSession** | Scope of the current save/run, authoritative world-state ownership, service references and lifecycle | Giant GameManager or every-frame engine of all services |
| **WorldClock** | One monotonic in-world time, day/calendar and explicit time advancement | Game-specific crop/NPC/quest handlers |
| **SimulationCoordinator** | Chronological advancement, event dispatch, dependency reconciliation, stable ordering, coherent commit boundaries | A full world scan every tick or owning each domain's gameplay rules |
| **WorldScheduler** | Durable pending event descriptors keyed by stable IDs, due time, handler kind, dependencies, status and tie-break | Raw live Callable/Node subscriptions serialized to disk |
| **Domain services** | Farming, trade, NPC schedules, inventory, law and narrative each own their facts, policies, projections and state changes | Duplicate other domain state or rely on unloaded scene Nodes |
| **Active region and UI Nodes** | Physics, sprites, interactive controls, animation and presentation signals | Offscreen source of truth |

Suggested Godot realization: a session assembled with explicit dependencies; mostly RefCounted for pure world services, and Nodes for loaded region/presentation. **No separate global manager for every domain, no DI framework and no generic ECS required.**

## 3. Durable subscription is not a scene Signal

A Godot Signal connection to a live NPC Node is suitable for local UI and momentary interactions. That Node can disappear on region unload, so its connection cannot guarantee that an offscreen event occurs.

Instead, important offscreen events are *serializable semantic records*, e.g.:

```text
event_id: delivery_184
kind: caravan_arrival
subject_id: caravan_12
due_world_minute: 18420
status: pending
```

At the due time the coordinator resolves the event through the appropriate domain handler, even with no live caravan scene. Store enough event result/execution identity to prevent replay. Do not broadcast every minute to thousands of sleeping crop or NPC Nodes.

This is **not full event sourcing**: an authoritative snapshot plus pending events, completed important outcomes and reconciliation anchors is enough unless evidence requires more.

## 4. Chronological time jumps

All world-time changes (sleep, travel, imprisonment and ordinary play progression) go through one interface. A conceptual algorithm:

1. Validate target time is >= the current WorldClock time.
2. Find the next *consequential* due event no later than target.
3. Advance the clock to **that event's actual timestamp**.
4. Reconcile only the domain facts required by that event **to the event timestamp**, validate and commit its state changes exactly once.
5. Enqueue resulting important events; repeat using stable ordering for equal timestamps.
6. Advance to target without updating unrelated distant objects.
7. On region entry or relevant authoritative query, reconcile just the affected entities to the current time.

Never jump directly to 20:00 and then execute a 10:00 contract as though it occurred at 20:00. Never first reconcile a crop to day five and then attempt to replay a day-three transaction as if day-five state were available on day three.

**Illustration:** the player sleeps from 08:00 to 20:00. A courier deadline at 10:00, promised arrival at 13:00, and legal consequence at 17:00 are processed chronologically. A remote farm is left alone until relevant; on returning its growth is computed from elapsed world time and care/environment history.

## 5. Exact meaning of Lazy Reconciliation

Lazy does **not** mean frozen state.

Example crop record: planted time, last-reconciled time, species/plot IDs, accrued growth, watering/moisture changes and relevant environmental conditions. At a requested later time, Farming computes the stage the crop *should* have reached.

- **Constant-rate processes:** derive directly from elapsed time without simulating missing frames.
- **Changing conditions:** preserve compact intervals, meaningful events or bounded summaries. Knowing only start and end weather is insufficient if frost or missed watering mattered midway.
- **NPC routines:** resolve schedules from time and stable route data, including exceptions such as arrest, injury, travel or an appointment.
- **Markets:** predictable restocking may reconcile lazily, but must not overwrite an earlier reservation or purchase.
- **Perishability, if later adopted:** evaluate through world time and container/storage history; don't create a per-item Timer Node.
- **Static secrets:** the secret entrance exists regardless of whether its rumor was heard; no time update or quest-gated existence.

A pure query can project state without side effects. Before committing a gameplay action, a domain service can explicitly ensure the referenced object is reconciled. A UI refresh must never secretly transfer money or spawn goods.

**Escalation rule:** a remote crop's ripening is Lazy, but an automatic contract that sells its yield *at a due date* is Scheduled; the contract handler first projects the crop to the due date and then resolves the sale at that timestamp.

## 6. World time versus active-play time

- **WorldClock** is the authority for growing, appointments, sentence duration, travel and (if used) spoilage.
- A short fishing timing minigame, combat recovery and the approved few-seconds crafting actions can use active gameplay duration as appropriate, without becoming offline mobile idle timers.
- Real wall-clock time while Android/Web is suspended is **not** automatically added to world time; no crops are killed or items spoiled merely because the user closes the app for a week.
- Precise speed/pausing rules are still open and must be tested on mobile/Web.

## 7. Ordering, failure and save rules

**Required invariants for implementation:**
1. Stable event IDs, deterministic ordering by due time and documented tie-break.
2. Exactly-once logical effect under repeat calls/save-load (idempotent handlers or durable execution status).
3. State transactions are committed coherently: no delivery payout without the matching completed event record; no double inventory transfer.
4. WorldClock monotonic; no retroactive event side effects after later interactions have already been committed.
5. Scheduled descriptors and last-reconciled anchors survive save/load, session swap and region unload.
6. Event handlers resolve by stable IDs, not only NodePaths, loaded sprites or serialized live Callables.
7. Failure has an explicit status/strategy: completed, cancelled, expired or blocked/retryable. Avoid silent infinite retry each frame.
8. Large time jumps must be bounded; aggregate repetitive independent effects when safe and guard against event storms.
9. Separate gameplay checkpoint/defeat rollback policy from technical suspension recovery.
10. Deterministic seeded rules must not reroll a resolved catch, crop harvest or scheduled reward on reload.

Do not implement a queue, dependency DAG, event broker or long-running offscreen worker beyond what real cases justify. Start with a small sorted due-event collection; only optimize if measured costs justify it.

## 8. Minimum proof before adopting implementation

Use disposable fixtures, *not* a permanent vertical slice:

| Fixture/test | Expected outcome |
| --- | --- |
| Distant crop, five world days | Correct maturity/soil/watering outcome on return; no five-day frame replay |
| A scheduled appointment in an unloaded region | Fires at its due timestamp and persists across save |
| Static secret no player knowledge | Exists and is reachable before rumor |
| Sleep across several events | Chronological and stable order; no duplicate outcomes |
| Two events same minute | Deterministic tie-break across replays |
| Distant vendor with reservation | Lazy stock update preserves committed transaction |
| NPC routine + important exception | Correct expected location without active offscreen pathfinding |
| Reenter same region twice | No second reconciliation consequence |
| Web/mobile app closed for days | No unapproved real-time world advancement |
| Farming conditions change while away | Uses relevant past intervals, not just final weather |

## 9. Existing proven reference and what NOT to copy

[Kiosk on the Nile](https://github.com/MohamedXIV/kiosk-on-the-nile) already contains `game/time/game_clock.gd`, `simulation_coordinator.gd`, `world_scheduler.gd`, and `session_advance.gd`. The clock is monotonic; coordinator orders registered systems, scheduler maintains durable jobs, and sleep applies elapsed effects. It is useful code/design evidence.

Kiosk's registered-system stepping and job-list scanning should **not** become a mandatory every-tick scan of a much larger multi-region world. Reuse proven explicit ordering and save invariants; introduce selective due-time processing plus per-domain lazy projection for this project's scope.

## 10. Open implementation details and sign-off

Still open: exact clock precision, active-play/world-time relationship, scheduler data structure, handler registry shape, weather and care history storage, failure retry policy, full GameSession lifetime, and technical save/checkpoint semantics.

**Owner's proposed offscreen classification is recorded as Provisional.** This RFC does not settle the language/DI/Session architecture ADR or authorize writing production systems yet.
