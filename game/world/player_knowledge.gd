class_name PlayerKnowledge
extends RefCounted
## Awareness is independent of physical existence in WorldState.

var _known: Dictionary = {}

func discover(fact_id: String) -> bool:
    if fact_id.is_empty():
        return false
    _known[fact_id] = true
    return true

func knows(fact_id: String) -> bool:
    return _known.has(fact_id)

func snapshot() -> Dictionary:
    return _known.duplicate(true)

func restore(data: Variant) -> bool:
    if typeof(data) != TYPE_DICTIONARY:
        return false
    for key in data:
        if typeof(key) != TYPE_STRING or String(key).is_empty():
            return false
        if data[key] != true:
            return false
    _known = data.duplicate(true)
    return true
