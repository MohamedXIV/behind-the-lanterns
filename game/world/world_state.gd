class_name WorldState
extends RefCounted
## Minimal factual truth store. Rich domain state belongs to domain services later.

var _facts: Dictionary = {}

func set_fact(id: String, exists: bool) -> bool:
    if id.is_empty():
        return false
    _facts[id] = exists
    return true

func has_fact(id: String) -> bool:
    return _facts.get(id, false) == true

func snapshot() -> Dictionary:
    return _facts.duplicate(true)

func restore(data: Variant) -> bool:
    if typeof(data) != TYPE_DICTIONARY:
        return false
    for key in data:
        if typeof(key) != TYPE_STRING or String(key).is_empty():
            return false
        if typeof(data[key]) != TYPE_BOOL:
            return false
    _facts = data.duplicate(true)
    return true
