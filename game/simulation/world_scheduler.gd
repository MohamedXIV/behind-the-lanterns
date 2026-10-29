class_name WorldScheduler
extends RefCounted
## Data-only due events, no persistent Node/Callable references.
## Small O(n) due search is intentional until actual workload justifies indexing.

var _events: Dictionary = {}

func schedule(event: Dictionary) -> bool:
    var normalized := _normalize(event)
    if normalized.is_empty():
        return false
    var id: String = normalized["id"]
    if _events.has(id):
        return false
    _events[id] = normalized
    return true

func next_due(up_to_minute: int) -> Dictionary:
    var earliest: Dictionary = {}
    for value in _events.values():
        var event: Dictionary = value
        if event["status"] != "pending" or int(event["due_minute"]) > up_to_minute:
            continue
        if earliest.is_empty() or _comes_first(event, earliest):
            earliest = event
    return earliest.duplicate(true)

func complete(event_id: String) -> bool:
    if not _events.has(event_id) or _events[event_id]["status"] != "pending":
        return false
    _events[event_id]["status"] = "completed"
    return true

func pending_count() -> int:
    var count := 0
    for event in _events.values():
        if event["status"] == "pending":
            count += 1
    return count

func status(event_id: String) -> String:
    if not _events.has(event_id):
        return ""
    return String(_events[event_id]["status"])

func snapshot() -> Dictionary:
    return _events.duplicate(true)

func restore(data: Variant) -> bool:
    if typeof(data) != TYPE_DICTIONARY:
        return false
    var candidate: Dictionary = {}
    for key in data:
        if typeof(key) != TYPE_STRING:
            return false
        if typeof(data[key]) != TYPE_DICTIONARY:
            return false
        var event := _normalize(data[key])
        if event.is_empty() or event["id"] != key:
            return false
        candidate[key] = event
    _events = candidate
    return true

func _normalize(input: Dictionary) -> Dictionary:
    for key in ["id", "kind", "due_minute"]:
        if not input.has(key):
            return {}
    if typeof(input["id"]) != TYPE_STRING or typeof(input["kind"]) != TYPE_STRING:
        return {}
    var event_id: String = input["id"]
    var kind: String = input["kind"]
    if event_id.is_empty() or kind.is_empty():
        return {}
    if not WorldClock._is_valid_minute(input["due_minute"]):
        return {}
    var priority: Variant = input.get("priority", 0)
    if typeof(priority) != TYPE_INT and typeof(priority) != TYPE_FLOAT:
        return {}
    if not is_finite(float(priority)) or float(priority) != floor(float(priority)):
        return {}
    if absf(float(priority)) > 100000.0:
        return {}
    var payload: Variant = input.get("payload", {})
    if typeof(payload) != TYPE_DICTIONARY or not _is_data_only(payload):
        return {}
    var event_status: Variant = input.get("status", "pending")
    if event_status != "pending" and event_status != "completed":
        return {}
    return {
        "id": event_id,
        "kind": kind,
        "due_minute": int(input["due_minute"]),
        "priority": int(priority),
        "payload": payload.duplicate(true),
        "status": event_status
    }

func _comes_first(left: Dictionary, right: Dictionary) -> bool:
    var left_time: int = left["due_minute"]
    var right_time: int = right["due_minute"]
    if left_time != right_time:
        return left_time < right_time
    var left_priority: int = left["priority"]
    var right_priority: int = right["priority"]
    if left_priority != right_priority:
        return left_priority < right_priority
    return String(left["id"]) < String(right["id"])

func _is_data_only(value: Variant, depth: int = 0) -> bool:
    if depth > 8:
        return false
    match typeof(value):
        TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
            return true
        TYPE_FLOAT:
            return is_finite(float(value))
        TYPE_ARRAY:
            for entry in value:
                if not _is_data_only(entry, depth + 1):
                    return false
            return true
        TYPE_DICTIONARY:
            for key in value:
                if typeof(key) != TYPE_STRING or not _is_data_only(value[key], depth + 1):
                    return false
            return true
        _:
            return false
