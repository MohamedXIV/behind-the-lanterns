class_name GameSession
extends RefCounted
## Session-scoped composition and save snapshot; no gameplay God Object.

const SNAPSHOT_VERSION: int = 1

var clock: WorldClock
var scheduler: WorldScheduler
var coordinator: SimulationCoordinator
var world: WorldState
var knowledge: PlayerKnowledge

var _unsafe_after_failed_advance: bool = false

func _init() -> void:
    clock = WorldClock.new()
    scheduler = WorldScheduler.new()
    coordinator = SimulationCoordinator.new()
    world = WorldState.new()
    knowledge = PlayerKnowledge.new()
    coordinator.configure(clock, scheduler)

func register_event_handler(kind: String, handler: Callable) -> bool:
    return coordinator.register_handler(kind, handler)

func schedule_event(event: Dictionary) -> bool:
    if _unsafe_after_failed_advance:
        return false
    if not event.has("due_minute") or not WorldClock._is_valid_minute(event["due_minute"]):
        return false
    if int(event["due_minute"]) < clock.current_minute():
        return false
    return scheduler.schedule(event)

func advance_to(target_minute: int) -> bool:
    if _unsafe_after_failed_advance:
        return false
    if coordinator.advance_to(target_minute):
        return true
    # Could have failed halfway through a domain command. Rebuild from a known
    # committed snapshot rather than saving an inconsistent in-memory session.
    _unsafe_after_failed_advance = true
    return false

func snapshot() -> Dictionary:
    if _unsafe_after_failed_advance:
        return {}
    return {
        "version": SNAPSHOT_VERSION,
        "world_minute": clock.snapshot(),
        "scheduled_events": scheduler.snapshot(),
        "world_facts": world.snapshot(),
        "player_knowledge": knowledge.snapshot()
    }

static func from_snapshot(data: Variant) -> GameSession:
    if typeof(data) != TYPE_DICTIONARY:
        return null
    if data.get("version") != SNAPSHOT_VERSION:
        return null
    var required := ["world_minute", "scheduled_events", "world_facts", "player_knowledge"]
    for key in required:
        if not data.has(key):
            return null
    var candidate := GameSession.new()
    if not candidate.clock.restore(data["world_minute"]):
        return null
    if not candidate.scheduler.restore(data["scheduled_events"]):
        return null
    if not candidate.world.restore(data["world_facts"]):
        return null
    if not candidate.knowledge.restore(data["player_knowledge"]):
        return null
    # A pending event before current time is an invalid restored timeline.
    var old_due := candidate.scheduler.next_due(candidate.clock.current_minute() - 1)
    if not old_due.is_empty():
        return null
    return candidate
