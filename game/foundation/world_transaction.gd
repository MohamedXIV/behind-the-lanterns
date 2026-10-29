class_name WorldTransaction
extends RefCounted
## Detached unit of work. Never publish this object's mutable references.

var _data: Dictionary
var _definition: WorldDefinition
var _clock: WorldClock
var _scheduler: WorldScheduler
var _kinds: Array
var _fault: String = ""
var _executing_event: String = ""

func _init(data: Dictionary, definition: WorldDefinition, kinds: Array) -> void:
	_data = data.duplicate(true)
	_definition = definition
	_clock = WorldClock.new(data.minute)
	_scheduler = WorldScheduler.new(data.scheduler)
	_kinds = kinds.duplicate()

func now() -> int:
	return _clock.now()

func read_domain(domain_id: String) -> Dictionary:
	return _data.domains.get(domain_id, {}).duplicate(true)

func write_domain(domain_id: String, state: Dictionary) -> bool:
	if not _fault.is_empty(): return false
	if not _data.domains.has(domain_id) or not WorldData.valid(state):
		_reject("invalid_domain_write")
		return false
	_data.domains[domain_id] = state.duplicate(true)
	return true

func entity(entity_id: String) -> Dictionary:
	return _data.entities.get(entity_id, {}).duplicate(true)

func create_entity(definition_id: String, region_id: String) -> String:
	if not _fault.is_empty(): return ""
	if not _definition.has_definition(definition_id) or not _definition.has_region(region_id) or _data.next_entity >= WorldData.MAX_COUNTER:
		_reject("invalid_entity_creation")
		return ""
	var entity_id := "r:%d" % _data.next_entity
	_data.next_entity += 1
	_data.entities[entity_id] = {"definition_id": definition_id, "region_id": region_id}
	return entity_id

func move_entity(entity_id: String, region_id: String) -> String:
	if not _fault.is_empty(): return _fault
	if not _data.entities.has(entity_id) or not _definition.has_region(region_id): return _reject("unknown_entity_or_region")
	_data.entities[entity_id].region_id = region_id
	return ""

func discover(claim_id: String, certainty: String) -> String:
	if not _fault.is_empty(): return _fault
	if not _definition.has_claim(claim_id) or not certainty in ["heard", "confirmed"]: return _reject("invalid_knowledge")
	if _data.knowledge.get(claim_id, "") != "confirmed":
		_data.knowledge[claim_id] = certainty
	return ""

func schedule(event: Dictionary) -> String:
	if not _fault.is_empty(): return _fault
	return _reject(_scheduler.schedule(event, now(), _data.entities, _kinds))

func cancel(event_id: String) -> String:
	if not _fault.is_empty(): return _fault
	if event_id == _executing_event: return _reject("event_already_executing")
	return _reject(_scheduler.cancel(event_id))

func _reject(reason: String) -> String:
	if _fault.is_empty(): _fault = reason
	return _fault

func snapshot() -> Dictionary:
	var result := _data.duplicate(true)
	result.minute = now()
	result.scheduler = _scheduler.snapshot()
	return result
