class_name CombatRules
extends SessionDomain
## Real-time skill-based non-guard combat with readable telegraphs, weak-spot windows,
## timed dodge/block counters, spatial outspacing, and first-class retreat.
## Guards are never valid combat targets (Constitution §6, D-008, D-009).

const DOMAIN: String = "combat"
const VALID_PHASES: Array = ["poised", "light_windup", "heavy_windup", "vulnerable", "resolved"]
const ACTIVE_PHASES: Array = ["poised", "light_windup", "heavy_windup", "vulnerable"]
const VALID_STATUSES: Array = ["engaged", "victory", "retreated", "winded"]
const VALID_DEFENSES: Array = ["none", "dodge", "block"]
const VALID_EVENTS: Array = [
	"engaged",
	"telegraph_light",
	"telegraph_heavy",
	"dodge_ready",
	"dodge_early",
	"block_ready",
	"block_early",
	"dodged_counter",
	"blocked_counter",
	"outspaced_counter",
	"heavy_crushed_block",
	"threat_hit_light",
	"threat_hit_heavy",
	"weak_spot_closed",
	"struck_weak_spot",
	"struck_poised",
	"struck_guarded_windup",
	"victory",
	"retreated",
	"spatial_retreat",
	"winded",
	"recovered",
]

var _actor_max_health: int
var _base_strike_damage: int
var _weak_spot_damage: int
var _threats: Dictionary = {}
var _interactions: InteractionRules
var _law: LawRules

static func create(config: Dictionary, interactions: InteractionRules, law: LawRules = null) -> CombatRules:
	if interactions == null or not WorldData.valid(config): return null
	if not WorldData.keys(config, ["actor_max_health", "base_strike_damage", "weak_spot_damage", "threats"]): return null
	if not WorldData.integer(config.actor_max_health, 1, 20): return null
	if not WorldData.integer(config.base_strike_damage, 1, 10): return null
	if not WorldData.integer(config.weak_spot_damage, int(config.base_strike_damage) + 1, 20): return null
	if not config.threats is Dictionary or config.threats.is_empty(): return null
	var rules := CombatRules.new()
	rules._actor_max_health = int(config.actor_max_health)
	rules._base_strike_damage = int(config.base_strike_damage)
	rules._weak_spot_damage = int(config.weak_spot_damage)
	rules._interactions = interactions
	rules._law = law
	var valid_targets := interactions.target_ids()
	var actors := interactions.actors()
	for id in config.threats:
		if not WorldData.id(id) or not id in valid_targets or id in actors: return null
		if law != null and law.is_guard(id): return null
		var threat: Variant = config.threats[id]
		if not WorldData.keys(threat, [
			"label",
			"weak_spot_label",
			"max_health",
			"engage_range",
			"disengage_range",
			"poised_ms",
			"light_windup_ms",
			"heavy_windup_ms",
			"weak_spot_ms",
			"light_damage",
			"heavy_damage",
			"pattern",
			"retreat_point",
		]): return null
		if not threat.label is String or threat.label.is_empty(): return null
		if not threat.weak_spot_label is String or threat.weak_spot_label.is_empty(): return null
		if not WorldData.integer(threat.max_health, 1, 50): return null
		if not _number(threat.engage_range) or float(threat.engage_range) < 40.0 or float(threat.engage_range) > 320.0: return null
		if not _number(threat.disengage_range) or float(threat.disengage_range) < float(threat.engage_range) + 24.0 or float(threat.disengage_range) > 600.0: return null
		if not WorldData.integer(threat.poised_ms, 200, 5000): return null
		if not WorldData.integer(threat.light_windup_ms, 250, 5000): return null
		if not WorldData.integer(threat.heavy_windup_ms, 300, 5000): return null
		if not WorldData.integer(threat.weak_spot_ms, 250, 5000): return null
		if not WorldData.integer(threat.light_damage, 1, 10): return null
		if not WorldData.integer(threat.heavy_damage, int(threat.light_damage), 15): return null
		if not threat.pattern is Array or threat.pattern.is_empty(): return null
		for step_kind in threat.pattern:
			if not step_kind is String or not step_kind in ["light", "heavy"]: return null
		if not WorldData.keys(threat.retreat_point, ["x", "y"]) or not _number(threat.retreat_point.x) or not _number(threat.retreat_point.y): return null
		rules._threats[id] = threat.duplicate(true)
	return rules

func domain_id() -> String:
	return DOMAIN

func initial_state() -> Dictionary:
	return {"next_encounter": 1, "encounters": {}}

func threats() -> Dictionary:
	return _threats.duplicate(true)

func threat_ids() -> Array:
	var ids: Array = _threats.keys()
	ids.sort()
	return ids

func is_threat(entity_id: String) -> bool:
	return _threats.has(entity_id)

func actor_max_health() -> int:
	return _actor_max_health

func base_strike_damage() -> int:
	return _base_strike_damage

func weak_spot_damage() -> int:
	return _weak_spot_damage

func encounter(snapshot: Dictionary, actor_id: String) -> Dictionary:
	if not snapshot.domains.has(DOMAIN): return {}
	return snapshot.domains[DOMAIN].encounters.get(actor_id, {}).duplicate(true)

func phase_duration(threat_id: String, phase: String) -> int:
	if not _threats.has(threat_id): return 0
	var threat: Dictionary = _threats[threat_id]
	match phase:
		"poised": return int(threat.poised_ms)
		"light_windup": return int(threat.light_windup_ms)
		"heavy_windup": return int(threat.heavy_windup_ms)
		"vulnerable": return int(threat.weak_spot_ms)
	return 0

func validate_world(world: Dictionary) -> bool:
	for id in _threats:
		if not world.entities.has(id): return false
		var region_id: String = world.entities[id].region_id
		var threat: Dictionary = _threats[id]
		var retreat_vec := Vector2(float(threat.retreat_point.x), float(threat.retreat_point.y))
		var bounds := _interactions.bounds()
		if retreat_vec.x < 0.0 or retreat_vec.y < 0.0 or retreat_vec.x > bounds.x or retreat_vec.y > bounds.y: return false
		if not _interactions.geometry_for(region_id).walkable(retreat_vec): return false
	return true

func nearby_threat(snapshot: Dictionary, actor_id: String, point: Vector2 = Vector2.INF) -> String:
	if not snapshot.entities.has(actor_id): return ""
	var active := encounter(snapshot, actor_id)
	var actor_region: String = snapshot.entities[actor_id].region_id
	if active.get("status", "") == "engaged":
		var active_id: String = active.get("threat_id", "")
		if snapshot.entities.has(active_id) and snapshot.entities[active_id].region_id == actor_region:
			return active_id
	var origin := point if point.is_finite() else _interactions.position_of(snapshot, actor_id)
	var best_id := ""
	var best_dist := INF
	for id in threat_ids():
		if not snapshot.entities.has(id) or snapshot.entities[id].region_id != actor_region: continue
		var threat_pos := _interactions.position_of(snapshot, id)
		var dist := origin.distance_to(threat_pos)
		if dist > float(_threats[id].disengage_range): continue
		if not _interactions.reach_geometry(snapshot, actor_region, id).clear_segment(origin, threat_pos): continue
		if dist < best_dist:
			best_dist = dist
			best_id = id
	return best_id

func engage(tx: WorldTransaction, actor_id: String, threat_id: String) -> String:
	if not actor_id in _interactions.actors(): return "unknown_actor"
	if _law != null and _law.is_guard(threat_id): return "guard_not_combat_target"
	if not _threats.has(threat_id): return "unknown_threat"
	var state := tx.read_domain(DOMAIN)
	var previous: Dictionary = state.encounters.get(actor_id, {})
	if previous.get("status", "") == "engaged": return "combat_in_progress"
	if previous.get("status", "") == "winded": return "actor_winded"
	if state.next_encounter >= WorldData.MAX_COUNTER: return "encounter_counter_exhausted"
	if tx.entity(actor_id).region_id != tx.entity(threat_id).region_id: return "different_region"
	var snapshot := tx.snapshot()
	var actor_pos := _interactions.position_of(snapshot, actor_id)
	var threat_pos := _interactions.position_of(snapshot, threat_id)
	var threat: Dictionary = _threats[threat_id]
	if actor_pos.distance_to(threat_pos) > float(threat.engage_range): return "out_of_engage_range"
	if not _interactions.reach_geometry(snapshot, tx.entity(actor_id).region_id, threat_id).clear_segment(actor_pos, threat_pos): return "combat_obstructed"
	var start_health := int(previous.get("actor_health", _actor_max_health))
	if start_health <= 0: start_health = _actor_max_health
	state.encounters[actor_id] = {
		"threat_id": threat_id,
		"ordinal": state.next_encounter,
		"status": "engaged",
		"actor_health": start_health,
		"threat_health": int(threat.max_health),
		"phase": "poised",
		"elapsed_ms": 0,
		"step": 0,
		"defense": "none",
		"last_event": "engaged",
	}
	state.next_encounter += 1
	return "" if tx.write_domain(DOMAIN, state) else "combat_write_failed"

func sync_spatial(tx: WorldTransaction, actor_id: String) -> String:
	var state := tx.read_domain(DOMAIN)
	var record: Dictionary = state.encounters.get(actor_id, {})
	if record.get("status", "") != "engaged": return ""
	var threat_id: String = record.threat_id
	var threat: Dictionary = _threats[threat_id]
	var same_region: bool = tx.entity(actor_id).region_id == tx.entity(threat_id).region_id
	var snapshot := tx.snapshot()
	var dist := _interactions.position_of(snapshot, actor_id).distance_to(_interactions.position_of(snapshot, threat_id)) if same_region else INF
	if not same_region or dist > float(threat.disengage_range):
		record.status = "retreated"
		record.phase = "resolved"
		record.elapsed_ms = 0
		record.defense = "none"
		record.last_event = "spatial_retreat"
		return "" if tx.write_domain(DOMAIN, state) else "combat_write_failed"
	return ""

func progress(tx: WorldTransaction, actor_id: String, milliseconds: Variant) -> String:
	if not WorldData.integer(milliseconds, 1, 10000): return "invalid_combat_duration"
	var state := tx.read_domain(DOMAIN)
	var record: Dictionary = state.encounters.get(actor_id, {})
	if record.get("status", "") != "engaged": return "combat_not_engaged"
	var threat_id: String = record.threat_id
	var threat: Dictionary = _threats[threat_id]
	var same_region: bool = tx.entity(actor_id).region_id == tx.entity(threat_id).region_id
	var snapshot := tx.snapshot()
	var dist := _interactions.position_of(snapshot, actor_id).distance_to(_interactions.position_of(snapshot, threat_id)) if same_region else INF
	if not same_region or dist > float(threat.disengage_range):
		record.status = "retreated"
		record.phase = "resolved"
		record.elapsed_ms = 0
		record.defense = "none"
		record.last_event = "spatial_retreat"
		return "" if tx.write_domain(DOMAIN, state) else "combat_write_failed"
	var remaining := int(milliseconds)
	while remaining > 0 and record.status == "engaged":
		var duration := phase_duration(threat_id, record.phase)
		var needed := duration - int(record.elapsed_ms)
		if remaining < needed:
			record.elapsed_ms = int(record.elapsed_ms) + remaining
			remaining = 0
		else:
			remaining -= needed
			record.elapsed_ms = 0
			var error := _advance_phase(tx, actor_id, record, threat, dist)
			if not error.is_empty(): return error
	return "" if tx.write_domain(DOMAIN, state) else "combat_write_failed"

func _advance_phase(tx: WorldTransaction, actor_id: String, record: Dictionary, threat: Dictionary, dist: float) -> String:
	match record.phase:
		"poised":
			var kind: String = threat.pattern[int(record.step)]
			record.phase = "heavy_windup" if kind == "heavy" else "light_windup"
			record.defense = "none"
			record.last_event = "telegraph_heavy" if kind == "heavy" else "telegraph_light"
		"light_windup":
			var committed: String = record.defense
			record.defense = "none"
			if committed == "dodge":
				record.phase = "vulnerable"
				record.last_event = "dodged_counter"
			elif committed == "block":
				record.phase = "vulnerable"
				record.last_event = "blocked_counter"
			elif dist > float(threat.engage_range):
				record.phase = "vulnerable"
				record.last_event = "outspaced_counter"
			else:
				record.actor_health = maxi(0, int(record.actor_health) - int(threat.light_damage))
				record.step = (int(record.step) + 1) % threat.pattern.size()
				if int(record.actor_health) == 0:
					return _apply_winded(tx, actor_id, record, threat)
				record.phase = "poised"
				record.last_event = "threat_hit_light"
		"heavy_windup":
			var committed_heavy: String = record.defense
			record.defense = "none"
			if committed_heavy == "dodge":
				record.phase = "vulnerable"
				record.last_event = "dodged_counter"
			elif dist > float(threat.engage_range):
				record.phase = "vulnerable"
				record.last_event = "outspaced_counter"
			elif committed_heavy == "block":
				var chip := maxi(1, int(threat.heavy_damage) - 1)
				record.actor_health = maxi(0, int(record.actor_health) - chip)
				record.step = (int(record.step) + 1) % threat.pattern.size()
				if int(record.actor_health) == 0:
					return _apply_winded(tx, actor_id, record, threat)
				record.phase = "poised"
				record.last_event = "heavy_crushed_block"
			else:
				record.actor_health = maxi(0, int(record.actor_health) - int(threat.heavy_damage))
				record.step = (int(record.step) + 1) % threat.pattern.size()
				if int(record.actor_health) == 0:
					return _apply_winded(tx, actor_id, record, threat)
				record.phase = "poised"
				record.last_event = "threat_hit_heavy"
		"vulnerable":
			record.phase = "poised"
			record.defense = "none"
			record.step = (int(record.step) + 1) % threat.pattern.size()
			record.last_event = "weak_spot_closed"
	return ""

func _apply_winded(tx: WorldTransaction, actor_id: String, record: Dictionary, threat: Dictionary) -> String:
	if tx.entity(actor_id).region_id == tx.entity(record.threat_id).region_id:
		var move_err := _interactions.move_actor(tx, actor_id, threat.retreat_point.x, threat.retreat_point.y)
		if not move_err.is_empty(): return move_err
	record.status = "winded"
	record.phase = "resolved"
	record.elapsed_ms = 0
	record.defense = "none"
	record.last_event = "winded"
	return ""

func strike(tx: WorldTransaction, actor_id: String, target_id: String = "") -> String:
	if not actor_id in _interactions.actors(): return "unknown_actor"
	if not target_id.is_empty() and _law != null and _law.is_guard(target_id): return "guard_not_combat_target"
	var state := tx.read_domain(DOMAIN)
	var record: Dictionary = state.encounters.get(actor_id, {})
	if record.get("status", "") != "engaged": return "combat_not_engaged"
	var threat_id: String = record.threat_id
	if not target_id.is_empty() and target_id != threat_id: return "target_mismatch"
	if tx.entity(actor_id).region_id != tx.entity(threat_id).region_id: return "different_region"
	var snapshot := tx.snapshot()
	var actor_pos := _interactions.position_of(snapshot, actor_id)
	var threat_pos := _interactions.position_of(snapshot, threat_id)
	var threat: Dictionary = _threats[threat_id]
	if actor_pos.distance_to(threat_pos) > float(threat.engage_range): return "out_of_engage_range"
	if not _interactions.reach_geometry(snapshot, tx.entity(actor_id).region_id, threat_id).clear_segment(actor_pos, threat_pos): return "combat_obstructed"
	record.defense = "none"
	if record.phase == "vulnerable":
		record.threat_health = maxi(0, int(record.threat_health) - _weak_spot_damage)
		if int(record.threat_health) == 0:
			record.status = "victory"
			record.phase = "resolved"
			record.elapsed_ms = 0
			record.last_event = "victory"
		else:
			record.phase = "poised"
			record.elapsed_ms = 0
			record.step = (int(record.step) + 1) % threat.pattern.size()
			record.last_event = "struck_weak_spot"
	elif record.phase == "poised":
		record.threat_health = maxi(0, int(record.threat_health) - _base_strike_damage)
		if int(record.threat_health) == 0:
			record.status = "victory"
			record.phase = "resolved"
			record.elapsed_ms = 0
			record.last_event = "victory"
		else:
			var kind: String = threat.pattern[int(record.step)]
			record.phase = "heavy_windup" if kind == "heavy" else "light_windup"
			record.elapsed_ms = 0
			record.last_event = "struck_poised"
	else:
		record.last_event = "struck_guarded_windup"
	return "" if tx.write_domain(DOMAIN, state) else "combat_write_failed"

func dodge(tx: WorldTransaction, actor_id: String) -> String:
	if not actor_id in _interactions.actors(): return "unknown_actor"
	var state := tx.read_domain(DOMAIN)
	var record: Dictionary = state.encounters.get(actor_id, {})
	if record.get("status", "") != "engaged": return "combat_not_engaged"
	var threat_id: String = record.threat_id
	if tx.entity(actor_id).region_id != tx.entity(threat_id).region_id: return "different_region"
	if record.phase in ["light_windup", "heavy_windup"]:
		record.defense = "dodge"
		record.last_event = "dodge_ready"
	else:
		record.defense = "none"
		record.last_event = "dodge_early"
	return "" if tx.write_domain(DOMAIN, state) else "combat_write_failed"

func block(tx: WorldTransaction, actor_id: String) -> String:
	if not actor_id in _interactions.actors(): return "unknown_actor"
	var state := tx.read_domain(DOMAIN)
	var record: Dictionary = state.encounters.get(actor_id, {})
	if record.get("status", "") != "engaged": return "combat_not_engaged"
	var threat_id: String = record.threat_id
	if tx.entity(actor_id).region_id != tx.entity(threat_id).region_id: return "different_region"
	if record.phase in ["light_windup", "heavy_windup"]:
		record.defense = "block"
		record.last_event = "block_ready"
	else:
		record.defense = "none"
		record.last_event = "block_early"
	return "" if tx.write_domain(DOMAIN, state) else "combat_write_failed"

func retreat(tx: WorldTransaction, actor_id: String) -> String:
	if not actor_id in _interactions.actors(): return "unknown_actor"
	var state := tx.read_domain(DOMAIN)
	var record: Dictionary = state.encounters.get(actor_id, {})
	if record.get("status", "") != "engaged": return "combat_not_engaged"
	var threat_id: String = record.threat_id
	var threat: Dictionary = _threats[threat_id]
	if tx.entity(actor_id).region_id == tx.entity(threat_id).region_id:
		var move_err := _interactions.move_actor(tx, actor_id, threat.retreat_point.x, threat.retreat_point.y)
		if not move_err.is_empty(): return move_err
	record.status = "retreated"
	record.phase = "resolved"
	record.elapsed_ms = 0
	record.defense = "none"
	record.last_event = "retreated"
	return "" if tx.write_domain(DOMAIN, state) else "combat_write_failed"

func recover(tx: WorldTransaction, actor_id: String) -> String:
	if not actor_id in _interactions.actors(): return "unknown_actor"
	var state := tx.read_domain(DOMAIN)
	var record: Dictionary = state.encounters.get(actor_id, {})
	if record.is_empty(): return "already_recovered"
	if record.get("status", "") == "engaged": return "combat_in_progress"
	if int(record.get("actor_health", _actor_max_health)) == _actor_max_health and record.get("status", "") != "winded":
		return "already_recovered"
	record.actor_health = _actor_max_health
	if record.get("status", "") == "winded":
		record.status = "retreated"
	record.phase = "resolved"
	record.elapsed_ms = 0
	record.defense = "none"
	record.last_event = "recovered"
	return "" if tx.write_domain(DOMAIN, state) else "combat_write_failed"

func validate(state: Dictionary, snapshot: Dictionary) -> String:
	if not WorldData.keys(state, ["next_encounter", "encounters"]) or not WorldData.integer(state.next_encounter, 1) or not state.encounters is Dictionary:
		return "combat_schema"
	var ordinals: Array = []
	for actor in state.encounters:
		var record: Variant = state.encounters[actor]
		if not actor in _interactions.actors() or not WorldData.keys(record, [
			"threat_id",
			"ordinal",
			"status",
			"actor_health",
			"threat_health",
			"phase",
			"elapsed_ms",
			"step",
			"defense",
			"last_event",
		]): return "combat_record"
		if not record.threat_id is String or not _threats.has(record.threat_id): return "combat_threat_reference"
		if _law != null and _law.is_guard(record.threat_id): return "combat_guard_forbidden"
		if not WorldData.integer(record.ordinal, 1, int(state.next_encounter) - 1) or record.ordinal in ordinals: return "combat_ordinal"
		ordinals.append(record.ordinal)
		var threat: Dictionary = _threats[record.threat_id]
		if not record.status is String or not record.status in VALID_STATUSES: return "combat_status"
		if not WorldData.integer(record.actor_health, 0, _actor_max_health): return "combat_actor_health"
		if not WorldData.integer(record.threat_health, 0, int(threat.max_health)): return "combat_threat_health"
		if not record.phase is String or not record.phase in VALID_PHASES: return "combat_phase"
		if not WorldData.integer(record.step, 0, threat.pattern.size() - 1): return "combat_step"
		if not record.defense is String or not record.defense in VALID_DEFENSES: return "combat_defense"
		if not record.last_event is String or not record.last_event in VALID_EVENTS: return "combat_event"
		if record.status == "engaged":
			if int(record.actor_health) < 1 or int(record.threat_health) < 1: return "combat_engaged_health"
			if not record.phase in ACTIVE_PHASES: return "combat_engaged_phase"
			if not WorldData.integer(record.elapsed_ms, 0, phase_duration(record.threat_id, record.phase)): return "combat_elapsed"
			if record.defense != "none" and not record.phase in ["light_windup", "heavy_windup"]: return "combat_defense_phase"
			if not snapshot.entities.has(actor) or not snapshot.entities.has(record.threat_id): return "combat_entity_reference"
			if snapshot.entities[actor].region_id != snapshot.entities[record.threat_id].region_id: return "combat_engaged_region"
		else:
			if record.phase != "resolved" or not WorldData.integer(record.elapsed_ms, 0, 0) or record.defense != "none": return "combat_resolved_state"
			if record.status == "victory" and (int(record.threat_health) != 0 or int(record.actor_health) < 1): return "combat_victory_health"
			if record.status == "winded" and int(record.actor_health) != 0: return "combat_winded_health"
			if record.status == "retreated" and int(record.actor_health) < 1: return "combat_retreated_health"
	return ""

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
