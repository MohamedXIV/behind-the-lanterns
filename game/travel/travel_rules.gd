class_name TravelRules
extends SessionDomain

const DOMAIN: String = "travel"
const ARRIVAL_EVENT: String = "travel.arrival"

var _routes: Dictionary
var _interactions: InteractionRules
var _commerce: CommerceRules

static func create(config: Dictionary, world: Dictionary, interactions: InteractionRules, commerce: CommerceRules) -> TravelRules:
	if interactions == null or commerce == null or not WorldData.valid(config): return null
	if not WorldData.keys(config, ["routes"]) or not config.routes is Dictionary or config.routes.is_empty(): return null
	for route_id in config.routes:
		var route: Variant = config.routes[route_id]
		if not WorldData.id(route_id) or not WorldData.keys(route, ["label", "mode", "carrier_id", "origin_region", "destination_region", "x", "y", "fare", "duration_minutes", "log"]): return null
		if not route.label is String or route.label.is_empty() or not route.log is String or route.log.is_empty(): return null
		if not route.mode in ["ship", "caravan"] or not WorldData.id(route.carrier_id): return null
		if not route.origin_region in world.regions or not route.destination_region in world.regions or route.origin_region == route.destination_region: return null
		if not route.carrier_id in interactions.target_ids() or not commerce.has_wallet(route.carrier_id): return null
		if world.entities.get(route.carrier_id, {}).get("region_id", "") != route.origin_region: return null
		if not _number(route.x) or not _number(route.y): return null
		if not interactions.geometry_for(route.destination_region).walkable(Vector2(route.x, route.y)): return null
		if not WorldData.integer(route.fare, 1) or not WorldData.integer(route.duration_minutes, 1): return null
	var rules := TravelRules.new()
	rules._routes = config.routes.duplicate(true)
	rules._interactions = interactions
	rules._commerce = commerce
	return rules

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

func domain_id() -> String:
	return DOMAIN

func initial_state() -> Dictionary:
	return {"active": {}, "journeys": {}}

func event_kinds() -> Array[String]:
	return [ARRIVAL_EVENT]

func route(route_id: String) -> Dictionary:
	return _routes.get(route_id, {}).duplicate(true)

func is_carrier(entity_id: String) -> bool:
	for definition in _routes.values():
		if definition.carrier_id == entity_id: return true
	return false

func route_ids(snapshot: Dictionary, actor_id: String, carrier_id: String = "") -> Array[String]:
	var result: Array[String] = []
	var origin: String = snapshot.entities.get(actor_id, {}).get("region_id", "")
	for route_id in _routes:
		var definition: Dictionary = _routes[route_id]
		if definition.origin_region == origin and (carrier_id.is_empty() or definition.carrier_id == carrier_id): result.append(route_id)
	result.sort()
	return result

func arrival_minute(snapshot: Dictionary, route_id: String) -> int:
	if not _routes.has(route_id): return -1
	var duration: int = _routes[route_id].duration_minutes
	if duration > WorldData.MAX_COUNTER - snapshot.minute: return -1
	return snapshot.minute + duration

static func journey_id(intent: String) -> String:
	return "journey." + intent.sha256_text()

static func arrival_event_id(id: String) -> String:
	return "travel-arrival." + id.sha256_text()

func board(tx: WorldTransaction, actor_id: String, route_id: String, id: String) -> String:
	if not _routes.has(route_id): return "unknown_route"
	if not WorldData.id(id): return "invalid_journey"
	var state := tx.read_domain(DOMAIN)
	if state.active.has(actor_id): return "journey_in_progress"
	if state.journeys.has(id): return "duplicate_journey"
	var definition: Dictionary = _routes[route_id]
	if tx.entity(actor_id).get("region_id", "") != definition.origin_region: return "different_region"
	var error := _interactions.reach_error(tx, actor_id, definition.carrier_id)
	if not error.is_empty(): return error
	if not _interactions.available(definition.carrier_id, tx.now()): return "person_unavailable"
	if definition.duration_minutes > WorldData.MAX_COUNTER - tx.now(): return "travel_time_overflow"
	var arrival: int = tx.now() + definition.duration_minutes
	var event_id := arrival_event_id(id)
	error = _commerce.transfer_funds(tx, actor_id, definition.carrier_id, definition.fare)
	if not error.is_empty(): return error
	state.active[actor_id] = {"id": id, "route_id": route_id, "actor_id": actor_id, "departed_at": tx.now(), "arrival_minute": arrival, "event_id": event_id}
	if not tx.write_domain(DOMAIN, state): return "travel_write_failed"
	return tx.schedule({"id": event_id, "kind": ARRIVAL_EVENT, "target_id": actor_id, "due": arrival, "payload": {"journey_id": id}})

func journeys_for(snapshot: Dictionary, actor_id: String) -> Array:
	var result: Array = []
	for record in snapshot.domains[DOMAIN].journeys.values():
		if record.actor_id == actor_id: result.append(record.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.arrival_minute == b.arrival_minute: return a.id < b.id
		return a.arrival_minute > b.arrival_minute)
	return result

func validate_event(event: Dictionary, snapshot: Dictionary) -> String:
	if event.kind != ARRIVAL_EVENT or not WorldData.keys(event.payload, ["journey_id"]) or not event.payload.journey_id is String: return "arrival_payload"
	var state: Dictionary = snapshot.domains[DOMAIN]
	var active: Dictionary = state.active.get(event.target_id, {})
	var completed: Dictionary = state.journeys.get(event.payload.journey_id, {})
	var record: Dictionary = completed if not completed.is_empty() else active
	if record.is_empty(): return "arrival_journey_reference"
	var error := _record_error(record, snapshot)
	if not error.is_empty(): return error
	if record.id != event.payload.journey_id or record.event_id != event.id or record.actor_id != event.target_id or record.arrival_minute != event.due: return "arrival_identity"
	if event.status == "pending" and active.is_empty(): return "arrival_pending_state"
	if event.status == "completed" and completed.is_empty(): return "arrival_completed_state"
	if event.status == "cancelled": return "arrival_cancelled_state"
	return ""

func handle_event(event: Dictionary, tx: WorldTransaction) -> String:
	var state := tx.read_domain(DOMAIN)
	var record: Dictionary = state.active.get(event.target_id, {})
	if record.is_empty() or record.id != event.payload.journey_id or record.event_id != event.id or record.arrival_minute != tx.now(): return "invalid_arrival"
	var definition: Dictionary = _routes[record.route_id]
	var error := _interactions.relocate_actor(tx, record.actor_id, definition.destination_region, definition.x, definition.y)
	if not error.is_empty(): return error
	state.active.erase(record.actor_id)
	state.journeys[record.id] = record.duplicate(true)
	return "" if tx.write_domain(DOMAIN, state) else "travel_write_failed"

func validate(state: Dictionary, snapshot: Dictionary) -> String:
	if not WorldData.keys(state, ["active", "journeys"]) or not state.active is Dictionary or not state.journeys is Dictionary: return "travel_schema"
	if not WorldData.keys(snapshot.scheduler, ["events", "next_sequence"]) or not snapshot.scheduler.events is Dictionary: return "travel_scheduler_state"
	var active_ids: Dictionary = {}
	for actor_id in state.active:
		var record: Variant = state.active[actor_id]
		if not actor_id in _interactions.actors(): return "active_actor_reference"
		var error := _record_error(record, snapshot)
		if not error.is_empty() or record.actor_id != actor_id: return "active_journey_record"
		if active_ids.has(record.id) or state.journeys.has(record.id): return "duplicate_active_journey"
		active_ids[record.id] = true
		var event: Variant = snapshot.scheduler.events.get(record.event_id)
		if not event is Dictionary or event.get("status", "") != "pending": return "active_arrival_event"
	for journey_id in state.journeys:
		var record: Variant = state.journeys[journey_id]
		if not record is Dictionary or journey_id != record.get("id", ""): return "journey_identity"
		var error := _record_error(record, snapshot)
		if not error.is_empty(): return error
		if record.arrival_minute > snapshot.minute: return "future_journey_log"
		var event: Variant = snapshot.scheduler.events.get(record.event_id)
		if not event is Dictionary or event.get("status", "") != "completed": return "completed_arrival_event"
	return ""

func _record_error(record: Variant, snapshot: Dictionary) -> String:
	if not WorldData.keys(record, ["id", "route_id", "actor_id", "departed_at", "arrival_minute", "event_id"]): return "journey_schema"
	if not WorldData.id(record.id) or not record.route_id is String or not _routes.has(record.route_id): return "journey_reference"
	if not record.actor_id in _interactions.actors() or not WorldData.integer(record.departed_at, 0, snapshot.minute): return "journey_actor_or_time"
	var definition: Dictionary = _routes[record.route_id]
	if not WorldData.integer(record.arrival_minute, 1) or record.arrival_minute != record.departed_at + definition.duration_minutes: return "journey_duration"
	if not record.event_id is String or record.event_id != arrival_event_id(record.id): return "journey_event_identity"
	return ""
