class_name SimulationCoordinator
extends RefCounted
## Advances to consequential events in chronological order; never ticks distant scenes.

const MAX_EVENTS_PER_ADVANCE: int = 1024

var _clock: WorldClock
var _scheduler: WorldScheduler
var _handlers: Dictionary = {}

func configure(clock: WorldClock, scheduler: WorldScheduler) -> void:
    _clock = clock
    _scheduler = scheduler

func register_handler(kind: String, handler: Callable) -> bool:
    if kind.is_empty() or not handler.is_valid():
        return false
    _handlers[kind] = handler
    return true

func advance_to(target_minute: int) -> bool:
    if _clock == null or _scheduler == null:
        return false
    if target_minute < _clock.current_minute() or target_minute > WorldClock.MAX_WORLD_MINUTE:
        return false
    var executed := 0
    while true:
        var event := _scheduler.next_due(target_minute)
        if event.is_empty():
            return _clock.advance_to(target_minute)
        if executed >= MAX_EVENTS_PER_ADVANCE:
            return false
        var due_minute: int = event["due_minute"]
        if due_minute < _clock.current_minute():
            return false
        var kind: String = event["kind"]
        if not _handlers.has(kind):
            return false
        var handler: Callable = _handlers[kind]
        if not handler.is_valid():
            return false
        if not _clock.advance_to(due_minute):
            return false
        # Handlers must validate and atomically commit their own domain effects.
        # Never save a session after an unsuccessful advance.
        var succeeded: Variant = handler.call(event.duplicate(true))
        if succeeded != true:
            return false
        if not _scheduler.complete(String(event["id"])):
            return false
        executed += 1
