class_name WorldClock
extends RefCounted
## Monotonic WORLD time. Never advances from OS wall-clock time automatically.

const MINUTES_PER_DAY: int = 1440
const MAX_WORLD_MINUTE: int = 2147483647

var _minute: int = 0

func current_minute() -> int:
    return _minute

func advance_to(target_minute: int) -> bool:
    if target_minute < _minute or target_minute > MAX_WORLD_MINUTE:
        return false
    _minute = target_minute
    return true

func snapshot() -> int:
    return _minute

func restore(value: Variant) -> bool:
    if not _is_valid_minute(value):
        return false
    _minute = int(value)
    return true

static func _is_valid_minute(value: Variant) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    var candidate := float(value)
    return is_finite(candidate) and candidate >= 0.0 \
        and candidate <= float(MAX_WORLD_MINUTE) and floor(candidate) == candidate
