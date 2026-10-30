class_name LawRules
extends SessionDomain
## Law, pursuit, scripted guard arrest, and watchhouse detention rules.
## Guards are never combat targets; attempting to strike a guard triggers
## scripted arrest. Jail is a traversable social space with zero reward farming.

const DOMAIN: String = "law"
const COOLDOWN_EVENT: String = "law.cooldown"
const RELEASE_EVENT: String = "law.release"
const VALID_STATUSES: Array[String] = ["clear", "pursued", "detained"]

var _config: Dictionary
var _interactions: InteractionRules
var _commerce: CommerceRules
var _work: WorkRules

static func create(config: Dictionary, world: Dictionary, interactions: InteractionRules, commerce: CommerceRules, work: WorkRules) -> LawRules:
	if interactions == null or commerce == null or work == null or not WorldData.valid(config): return null
	var req := [
		"treasury_id", "cooldown_minutes",
		"base_fine", "repeat_fine_step", "max_fine",
		"base_sentence_minutes", "repeat_sentence_step", "max_sentence_minutes",
		"jail", "release", "guards", "restricted_targets", "refuges",
	]
	if not WorldData.keys(config, req): return null
	if not config.treasury_id is String or not commerce.has_wallet(config.treasury_id): return null
	if not WorldData.integer(config.cooldown_minutes, 1): return null
	if not WorldData.integer(config.base_fine, 1) or not WorldData.integer(config.repeat_fine_step, 0) or not WorldData.integer(config.max_fine, config.base_fine): return null
	if not WorldData.integer(config.base_sentence_minutes, 1) or not WorldData.integer(config.repeat_sentence_step, 0) or not WorldData.integer(config.max_sentence_minutes, config.base_sentence_minutes): return null
	if not WorldData.keys(config.jail, ["region_id", "x", "y", "exit_portal"]): return null
	if not config.jail.region_id in world.regions or not interactions.is_portal(config.jail.exit_portal): return null
	if not WorldData.integer(config.jail.x, 0) or not WorldData.integer(config.jail.y, 0): return null
	if not interactions.geometry_for(config.jail.region_id).walkable(Vector2(config.jail.x, config.jail.y)): return null
	if not WorldData.keys(config.release, ["region_id", "x", "y"]): return null
	if not config.release.region_id in world.regions: return null
	if not WorldData.integer(config.release.x, 0) or not WorldData.integer(config.release.y, 0): return null
	if not interactions.geometry_for(config.release.region_id).walkable(Vector2(config.release.x, config.release.y)): return null
	if not config.guards is Dictionary or config.guards.is_empty(): return null
	for guard_id in config.guards:
		var guard: Variant = config.guards[guard_id]
		if not guard_id in interactions.target_ids() or not WorldData.keys(guard, ["label", "sight_range", "voucher_jobs"]): return null
		if not guard.label is String or guard.label.is_empty() or not WorldData.integer(guard.sight_range, 1): return null
		if not guard.voucher_jobs is Array: return null
		for job_id in guard.voucher_jobs:
			if not job_id is String or not work.definitions().has(job_id): return null
	if not config.restricted_targets is Dictionary or config.restricted_targets.is_empty(): return null
	for target_id in config.restricted_targets:
		var item: Variant = config.restricted_targets[target_id]
		if not target_id in interactions.target_ids() or not WorldData.keys(item, ["offense", "label"]): return null
		if not WorldData.id(item.offense) or not item.label is String or item.label.is_empty(): return null
	if not config.refuges is Dictionary or config.refuges.is_empty(): return null
	for refuge_id in config.refuges:
		var refuge: Variant = config.refuges[refuge_id]
		if not refuge_id in interactions.target_ids() or not WorldData.keys(refuge, ["label"]): return null
		if not refuge.label is String or refuge.label.is_empty(): return null
	var rules := LawRules.new()
	rules._config = config.duplicate(true)
	rules._interactions = interactions
	rules._commerce = commerce
	rules._work = work
	return rules

func domain_id() -> String:
	return DOMAIN

func schema_version() -> int:
	return 1

func initial_state() -> Dictionary:
	return {"records": {}}

func guards() -> Dictionary:
	return _config.guards.duplicate(true)

func is_guard(entity_id: String) -> bool:
	return _config.guards.has(entity_id)

func restricted_targets() -> Dictionary:
	return _config.restricted_targets.duplicate(true)

func refuges() -> Dictionary:
	return _config.refuges.duplicate(true)

func jail_config() -> Dictionary:
	return _config.jail.duplicate(true)

func status_of(snapshot: Dictionary, actor_id: String) -> Dictionary:
	var records: Dictionary = snapshot.domains.get(DOMAIN, {}).get("records", {})
	if records.has(actor_id):
		return records[actor_id].duplicate(true)
	return _default_record()

func _default_record(offense_count: int = 0) -> Dictionary:
	return {
		"status": "clear",
		"offense": "",
		"witness_id": "",
		"offense_count": offense_count,
		"fine": 0,
		"started_at": -1,
		"until_minute": -1,
		"event_id": "",
	}

func can_vouch(snapshot: Dictionary, actor_id: String, guard_id: String) -> bool:
	if not _config.guards.has(guard_id): return false
	var current := status_of(snapshot, actor_id)
	if current.offense == "guard_assault" or current.offense_count > 0: return false
	for job_id in _config.guards[guard_id].voucher_jobs:
		if _work.job_for(snapshot, actor_id, job_id).get("status", "") == "completed":
			return true
	return false

func portal_error(snapshot: Dictionary, actor_id: String, portal_id: String) -> String:
	if portal_id == _config.jail.exit_portal and status_of(snapshot, actor_id).status == "detained":
		return "detained_until_release"
	return ""

func public_travel_error(snapshot: Dictionary, actor_id: String) -> String:
	match status_of(snapshot, actor_id).status:
		"detained": return "actor_detained"
		"pursued": return "carrier_refuses_pursuit"
	return ""

func confront_guard(tx: WorldTransaction, actor_id: String, target_id: String) -> String:
	if not _config.guards.has(target_id): return "non_hostile_target"
	var error := _interactions.reach_error(tx, actor_id, target_id)
	if not error.is_empty(): return error
	if not _interactions.available(target_id, tx.now()): return "person_unavailable"
	return _arrest(tx, actor_id, "guard_assault", target_id, true)

func tamper_restricted(tx: WorldTransaction, actor_id: String, target_id: String) -> String:
	if not _config.restricted_targets.has(target_id): return "not_restricted_target"
	var current := status_of(tx.snapshot(), actor_id)
	if current.status == "detained": return "actor_detained"
	var error := _interactions.reach_error(tx, actor_id, target_id)
	if not error.is_empty(): return error
	var witness := _find_witness(tx, actor_id)
	if witness.is_empty(): return "restricted_unwitnessed"
	var offense: String = _config.restricted_targets[target_id].offense
	if current.status == "pursued":
		return _arrest(tx, actor_id, offense, witness, false)
	var due: int = tx.now() + int(_config.cooldown_minutes)
	if due > WorldData.MAX_COUNTER: return "law_time_overflow"
	var ev_id := _make_event_id("cooldown", actor_id, tx.now(), tx.snapshot().revision)
	var fine := _compute_fine(current.offense_count, false)
	var state := tx.read_domain(DOMAIN)
	state.records[actor_id] = {
		"status": "pursued",
		"offense": offense,
		"witness_id": witness,
		"offense_count": current.offense_count,
		"fine": fine,
		"started_at": tx.now(),
		"until_minute": due,
		"event_id": ev_id,
	}
	if not tx.write_domain(DOMAIN, state): return "law_write_failed"
	return tx.schedule({"id": ev_id, "kind": COOLDOWN_EVENT, "target_id": actor_id, "due": due, "payload": {"actor_id": actor_id}})

func evade_pursuit(tx: WorldTransaction, actor_id: String, refuge_id: String) -> String:
	if not _config.refuges.has(refuge_id): return "not_refuge"
	var current := status_of(tx.snapshot(), actor_id)
	if current.status != "pursued": return "not_pursued"
	var error := _interactions.reach_error(tx, actor_id, refuge_id)
	if not error.is_empty(): return error
	if not _nearby_guard(tx, actor_id).is_empty(): return "guard_too_close"
	error = tx.cancel(current.event_id)
	if not error.is_empty(): return error
	var state := tx.read_domain(DOMAIN)
	state.records[actor_id] = _default_record(current.offense_count)
	return "" if tx.write_domain(DOMAIN, state) else "law_write_failed"

func persuade_guard(tx: WorldTransaction, actor_id: String, guard_id: String) -> String:
	if not _config.guards.has(guard_id): return "unknown_guard"
	var current := status_of(tx.snapshot(), actor_id)
	if current.status != "pursued": return "not_pursued"
	var error := _interactions.reach_error(tx, actor_id, guard_id)
	if not error.is_empty(): return error
	if not _interactions.available(guard_id, tx.now()): return "person_unavailable"
	if current.offense == "guard_assault" or current.offense_count > 0: return "persuasion_refused"
	if not can_vouch(tx.snapshot(), actor_id, guard_id): return "voucher_required"
	error = tx.cancel(current.event_id)
	if not error.is_empty(): return error
	var state := tx.read_domain(DOMAIN)
	state.records[actor_id] = _default_record(current.offense_count)
	return "" if tx.write_domain(DOMAIN, state) else "law_write_failed"

func surrender_to_guard(tx: WorldTransaction, actor_id: String, guard_id: String) -> String:
	if not _config.guards.has(guard_id): return "unknown_guard"
	var current := status_of(tx.snapshot(), actor_id)
	if current.status != "pursued": return "not_pursued"
	var error := _interactions.reach_error(tx, actor_id, guard_id)
	if not error.is_empty(): return error
	if not _interactions.available(guard_id, tx.now()): return "person_unavailable"
	return _arrest(tx, actor_id, current.offense, guard_id, false)

func pay_fine(tx: WorldTransaction, actor_id: String, guard_id: String) -> String:
	if not _config.guards.has(guard_id): return "unknown_guard"
	var current := status_of(tx.snapshot(), actor_id)
	if not current.status in ["pursued", "detained"]: return "no_active_fine"
	var error := _interactions.reach_error(tx, actor_id, guard_id)
	if not error.is_empty(): return error
	if not _interactions.available(guard_id, tx.now()): return "person_unavailable"
	error = _commerce.transfer_funds(tx, actor_id, _config.treasury_id, current.fine)
	if not error.is_empty(): return error
	error = tx.cancel(current.event_id)
	if not error.is_empty(): return error
	var next_count: int = mini(WorldData.MAX_COUNTER, int(current.offense_count) + 1) if current.status == "pursued" else int(current.offense_count)
	if current.status == "detained":
		error = _interactions.relocate_actor(tx, actor_id, _config.release.region_id, _config.release.x, _config.release.y)
		if not error.is_empty(): return error
	var state := tx.read_domain(DOMAIN)
	state.records[actor_id] = _default_record(next_count)
	return "" if tx.write_domain(DOMAIN, state) else "law_write_failed"

func _arrest(tx: WorldTransaction, actor_id: String, offense: String, guard_id: String, is_assault: bool) -> String:
	var current := status_of(tx.snapshot(), actor_id)
	if current.status in ["pursued", "detained"] and not current.event_id.is_empty():
		var cancel_err := tx.cancel(current.event_id)
		if not cancel_err.is_empty(): return cancel_err
	var next_count: int = mini(WorldData.MAX_COUNTER, int(current.offense_count) + 1)
	var fine: int = _compute_fine(int(current.offense_count), is_assault)
	var duration: int = _compute_sentence(int(current.offense_count), is_assault)
	var due: int = tx.now() + duration
	if due > WorldData.MAX_COUNTER: return "law_time_overflow"
	var relocate_err := _interactions.relocate_actor(tx, actor_id, _config.jail.region_id, _config.jail.x, _config.jail.y)
	if not relocate_err.is_empty(): return relocate_err
	var ev_id := _make_event_id("release", actor_id, tx.now(), tx.snapshot().revision)
	var state := tx.read_domain(DOMAIN)
	state.records[actor_id] = {
		"status": "detained",
		"offense": offense,
		"witness_id": guard_id,
		"offense_count": next_count,
		"fine": fine,
		"started_at": tx.now(),
		"until_minute": due,
		"event_id": ev_id,
	}
	if not tx.write_domain(DOMAIN, state): return "law_write_failed"
	return tx.schedule({"id": ev_id, "kind": RELEASE_EVENT, "target_id": actor_id, "due": due, "payload": {"actor_id": actor_id}})

func _compute_fine(prior_offenses: int, is_assault: bool) -> int:
	var steps := prior_offenses + (1 if is_assault else 0)
	return mini(int(_config.max_fine), int(_config.base_fine) + steps * int(_config.repeat_fine_step))

func _compute_sentence(prior_offenses: int, is_assault: bool) -> int:
	var steps := prior_offenses + (1 if is_assault else 0)
	return mini(int(_config.max_sentence_minutes), int(_config.base_sentence_minutes) + steps * int(_config.repeat_sentence_step))

func _find_witness(tx: WorldTransaction, actor_id: String) -> String:
	var snapshot := tx.snapshot()
	var actor_region: String = snapshot.entities[actor_id].region_id
	var actor_pos := _interactions.position_of(snapshot, actor_id)
	var best_guard := ""
	var best_dist := INF
	for guard_id in _config.guards:
		if snapshot.entities[guard_id].region_id != actor_region: continue
		if not _interactions.available(guard_id, tx.now()): continue
		var dist := actor_pos.distance_to(_interactions.position_of(snapshot, guard_id))
		if dist <= float(_config.guards[guard_id].sight_range) and dist < best_dist:
			best_guard = guard_id
			best_dist = dist
	return best_guard

func _nearby_guard(tx: WorldTransaction, actor_id: String) -> String:
	var snapshot := tx.snapshot()
	var actor_region: String = snapshot.entities[actor_id].region_id
	var actor_pos := _interactions.position_of(snapshot, actor_id)
	for guard_id in _config.guards:
		if snapshot.entities[guard_id].region_id != actor_region: continue
		if not _interactions.available(guard_id, tx.now()): continue
		if actor_pos.distance_to(_interactions.position_of(snapshot, guard_id)) <= _interactions.reach():
			return guard_id
	return ""

static func _make_event_id(prefix: String, actor_id: String, minute: int, revision: int) -> String:
	return "law-%s.%s" % [prefix, ("%s:%d:%d" % [actor_id, minute, revision]).sha256_text()]

func event_kinds() -> Array[String]:
	return [COOLDOWN_EVENT, RELEASE_EVENT]

func validate_event(event: Dictionary, snapshot: Dictionary) -> String:
	if not WorldData.keys(event.payload, ["actor_id"]) or not event.payload.actor_id is String: return "law_event_payload"
	var actor_id: String = event.payload.actor_id
	if not actor_id in _interactions.actors() or event.target_id != actor_id: return "law_event_actor"
	if event.get("status") == "pending":
		var records: Variant = snapshot.domains.get(DOMAIN, {}).get("records")
		if not records is Dictionary or not records.has(actor_id): return "law_event_actor"
		var record: Dictionary = records[actor_id]
		if event.id != record.event_id or event.due != record.until_minute: return "law_event_identity"
		if event.kind == COOLDOWN_EVENT and record.status != "pursued": return "law_cooldown_status"
		if event.kind == RELEASE_EVENT and record.status != "detained": return "law_release_status"
	return ""

func handle_event(event: Dictionary, tx: WorldTransaction) -> String:
	var actor_id: String = event.payload.actor_id
	var state := tx.read_domain(DOMAIN)
	if not state.records.has(actor_id): return "missing_law_record"
	var record: Dictionary = state.records[actor_id]
	if record.event_id != event.id or record.until_minute != tx.now(): return "stale_law_event"
	if event.kind == RELEASE_EVENT:
		if record.status != "detained": return "invalid_release_state"
		var relocate_err := _interactions.relocate_actor(tx, actor_id, _config.release.region_id, _config.release.x, _config.release.y)
		if not relocate_err.is_empty(): return relocate_err
	elif event.kind == COOLDOWN_EVENT:
		if record.status != "pursued": return "invalid_cooldown_state"
	else:
		return "unknown_law_event"
	state.records[actor_id] = _default_record(record.offense_count)
	return "" if tx.write_domain(DOMAIN, state) else "law_write_failed"

func validate(state: Dictionary, snapshot: Dictionary) -> String:
	if not WorldData.keys(state, ["records"]) or not state.records is Dictionary: return "law_schema"
	if not WorldData.keys(snapshot.scheduler, ["events", "next_sequence"]) or not snapshot.scheduler.events is Dictionary: return "law_scheduler_state"
	for actor_id in state.records:
		if not actor_id in _interactions.actors(): return "law_actor_reference"
		var record: Variant = state.records[actor_id]
		if not WorldData.keys(record, ["status", "offense", "witness_id", "offense_count", "fine", "started_at", "until_minute", "event_id"]): return "law_record_schema"
		if not record.status in VALID_STATUSES: return "law_status"
		if not WorldData.integer(record.offense_count, 0): return "law_offense_count"
		if record.status == "clear":
			if record.offense != "" or record.witness_id != "" or record.fine != 0 or record.started_at != -1 or record.until_minute != -1 or record.event_id != "":
				return "law_clear_record"
		else:
			if not record.offense is String or record.offense.is_empty(): return "law_offense"
			if not _config.guards.has(record.witness_id): return "law_witness"
			if not WorldData.integer(record.fine, _config.base_fine, _config.max_fine): return "law_fine"
			if not WorldData.integer(record.started_at, 0, snapshot.minute): return "law_started_at"
			if not WorldData.integer(record.until_minute, record.started_at + 1): return "law_until_minute"
			if record.until_minute < snapshot.minute: return "law_overdue_active_state"
			if not WorldData.id(record.event_id) or not snapshot.scheduler.events.has(record.event_id): return "law_missing_scheduled_event"
			var ev: Dictionary = snapshot.scheduler.events[record.event_id]
			var expected_kind := COOLDOWN_EVENT if record.status == "pursued" else RELEASE_EVENT
			if ev.kind != expected_kind or ev.status != "pending" or ev.due != record.until_minute: return "law_scheduled_event_mismatch"
			if record.status == "detained" and snapshot.entities[actor_id].region_id != _config.jail.region_id: return "law_detained_region_mismatch"
	return ""
