class_name NpcScheduleRules
extends RefCounted
## Pure in-region routine lookup. No offscreen Nodes, pathfinding or minute ticks.

var _routines: Dictionary

static func create(config: Dictionary, world: Dictionary, interaction_config: Dictionary) -> NpcScheduleRules:
	if not WorldData.valid(config): return null
	if not world.get("entities") is Dictionary or not interaction_config.get("actors") is Array: return null
	var bounds: Variant = interaction_config.get("bounds")
	if not WorldData.keys(bounds, ["width", "height"]): return null
	if not WorldData.integer(bounds.width, 1) or not WorldData.integer(bounds.height, 1): return null
	if not interaction_config.get("regions", {}) is Dictionary: return null
	var geometry := WorldGeometry.create(interaction_config.get("geometry", {"radius": 0, "obstacles": []}), Vector2(bounds.width, bounds.height))
	if geometry == null: return null
	for id in config:
		var routine: Variant = config[id]
		if not WorldData.id(id) or not world.entities.has(id) or id in interaction_config.actors: return null
		geometry = WorldGeometry.create(interaction_config.get("regions", {}).get(world.entities[id].region_id, interaction_config.get("geometry", {"radius": 0, "obstacles": []})), Vector2(bounds.width, bounds.height))
		if geometry == null: return null
		if not WorldData.keys(routine, ["period_minutes", "slots"]) or not WorldData.integer(routine.period_minutes, 1): return null
		if not routine.slots is Array or routine.slots.is_empty(): return null
		var previous: int = -1
		for slot in routine.slots:
			if not WorldData.keys(slot, ["start", "x", "y", "available", "activity"]): return null
			if not WorldData.integer(slot.start, 0, routine.period_minutes - 1) or slot.start <= previous: return null
			if previous == -1 and slot.start != 0: return null
			if not _coordinate(slot.x, bounds.width) or not _coordinate(slot.y, bounds.height): return null
			if not geometry.walkable(Vector2(slot.x, slot.y)): return null
			if not slot.available is bool or not slot.activity is String: return null
			previous = slot.start
	var rules := NpcScheduleRules.new()
	rules._routines = config.duplicate(true)
	return rules

static func _coordinate(value: Variant, maximum: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= 0 and value <= maximum

func ids() -> Array:
	return _routines.keys()

func projection(entity_id: String, minute: int) -> Dictionary:
	if not _routines.has(entity_id): return {}
	var routine: Dictionary = _routines[entity_id]
	var phase: int = minute % int(routine.period_minutes)
	var chosen: Dictionary = routine.slots[0]
	for slot in routine.slots:
		if slot.start > phase: break
		chosen = slot
	return chosen.duplicate(true)

func available(entity_id: String, minute: int) -> bool:
	var result := projection(entity_id, minute)
	return result.is_empty() or result.available
