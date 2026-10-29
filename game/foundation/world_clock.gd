class_name WorldClock
extends RefCounted
## Transaction-owned world time. The session is the only public advancement entry.

const MINUTES_PER_DAY: int = 1440
var _minute: int

func _init(minute: int = 0) -> void:
	_minute = minute

func now() -> int:
	return _minute

func day() -> int:
	return _minute / MINUTES_PER_DAY + 1

func advance_to(target: int) -> bool:
	if target < _minute or not WorldData.integer(target): return false
	_minute = target
	return true
