class_name WorldScheduler
extends RefCounted
## Small durable queue: due time then insertion sequence. No per-frame scanning.

var _events: Dictionary
var _next_sequence: int

func _init(data: Dictionary) -> void:
	_events = data.events.duplicate(true)
	_next_sequence = data.next_sequence

func schedule(event: Dictionary, now: int, entities: Dictionary, kinds: Array) -> String:
	if not WorldData.keys(event, ["id", "kind", "target_id", "due"], ["payload"]): return "event_schema"
	if not WorldData.id(event.id) or not WorldData.id(event.kind) or not WorldData.id(event.target_id): return "event_identity"
	if _events.has(event.id): return "duplicate_event"
	if not event.kind in kinds: return "unknown_event_kind"
	if not entities.has(event.target_id): return "unknown_event_target"
	if not WorldData.integer(event.due, now) or _next_sequence >= WorldData.MAX_COUNTER: return "event_time_or_sequence"
	var payload: Variant = event.get("payload", {})
	if not payload is Dictionary or not WorldData.valid(payload): return "event_payload"
	var record := event.duplicate(true)
	record.payload = payload.duplicate(true)
	record.sequence = _next_sequence
	record.status = "pending"
	_events[event.id] = record
	_next_sequence += 1
	return ""

func cancel(event_id: String) -> String:
	if not _events.has(event_id) or _events[event_id].status != "pending": return "event_not_pending"
	_events[event_id].status = "cancelled"
	return ""

func next_due(target: int) -> Dictionary:
	var first: Dictionary = {}
	for record in _events.values():
		if record.status != "pending" or record.due > target: continue
		if first.is_empty() or record.due < first.due or (record.due == first.due and record.sequence < first.sequence):
			first = record
	return first.duplicate(true)

func complete(event_id: String) -> void:
	_events[event_id].status = "completed"

func snapshot() -> Dictionary:
	return {"events": _events.duplicate(true), "next_sequence": _next_sequence}

static func validate(data: Variant, now: int, entities: Dictionary, kinds: Array) -> String:
	if not WorldData.keys(data, ["events", "next_sequence"]) or not data.events is Dictionary or not WorldData.integer(data.next_sequence, 1):
		return "scheduler_schema"
	var sequences: Dictionary = {}
	for key in data.events:
		var record: Variant = data.events[key]
		if not WorldData.keys(record, ["id", "kind", "target_id", "due", "payload", "sequence", "status"]): return "event_schema"
		if not WorldData.id(key) or not WorldData.id(record.id) or not WorldData.id(record.kind) or not WorldData.id(record.target_id): return "event_identity"
		if key != record.id: return "event_identity"
		if not record.kind in kinds or not entities.has(record.target_id): return "event_reference"
		if not WorldData.integer(record.due) or not WorldData.integer(record.sequence, 1, data.next_sequence - 1): return "event_time_or_sequence"
		if sequences.has(record.sequence): return "duplicate_sequence"
		sequences[record.sequence] = true
		if not record.status in ["pending", "completed", "cancelled"]: return "event_status"
		if record.status == "pending" and record.due < now: return "overdue_event"
		if record.status == "completed" and record.due > now: return "future_completed_event"
		if not record.payload is Dictionary or not WorldData.valid(record.payload): return "event_payload"
	return ""
