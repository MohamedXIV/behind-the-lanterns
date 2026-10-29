class_name WorkRules
extends SessionDomain
## Optional one-shot supply deliveries, backed by real goods and held payment.

const DOMAIN: String = "work"
const EXPIRE: String = "work.expire"
var _definitions: Dictionary
var _inventory: InventoryRules
var _commerce: CommerceRules
var _interactions: InteractionRules

static func create(config: Dictionary, inventory: InventoryRules, commerce: CommerceRules, interactions: InteractionRules) -> WorkRules:
	if not WorldData.valid(config): return null
	for id in config:
		var job: Variant = config[id]
		if not WorldData.id(id) or not WorldData.keys(job, ["label", "giver_id", "recipient_id", "requirements", "reward", "deadline_minutes"]): return null
		if not job.label is String or not job.giver_id is String or not job.recipient_id is String: return null
		if not commerce.has_wallet(job.giver_id) or inventory.container_definition(job.recipient_id).is_empty(): return null
		if not job.giver_id in interactions.target_ids() or not job.recipient_id in interactions.target_ids(): return null
		if not WorldData.integer(job.reward, 1) or not WorldData.integer(job.deadline_minutes, 1): return null
		if not job.requirements is Dictionary or job.requirements.is_empty(): return null
		for item in job.requirements:
			if inventory.item_definition(item).is_empty() or not WorldData.integer(job.requirements[item], 1): return null
	var rules := WorkRules.new()
	rules._definitions = config.duplicate(true)
	rules._inventory = inventory
	rules._commerce = commerce
	rules._interactions = interactions
	return rules

func domain_id() -> String:
	return DOMAIN

func initial_state() -> Dictionary:
	return {"jobs": {}}

func definitions() -> Dictionary:
	return _definitions.duplicate(true)

func job_for(snapshot: Dictionary, actor_id: String, definition_id: String) -> Dictionary:
	for id in snapshot.domains[DOMAIN].jobs:
		var job: Dictionary = snapshot.domains[DOMAIN].jobs[id]
		if job.actor_id == actor_id and job.definition_id == definition_id:
			var result := job.duplicate(true)
			result.id = id
			return result
	return {}

static func expiry_id(job_id: String) -> String:
	return "work-expire." + job_id.sha256_text()

func accept(tx: WorldTransaction, actor_id: String, definition_id: String, job_id: String) -> String:
	if not _definitions.has(definition_id) or not WorldData.id(job_id): return "unknown_job"
	var definition: Dictionary = _definitions[definition_id]
	if actor_id == definition.giver_id or actor_id == definition.recipient_id or not _commerce.has_wallet(actor_id): return "invalid_job_actor"
	var error := _interactions.reach_error(tx, actor_id, definition.giver_id)
	if not error.is_empty(): return error
	if not _interactions.available(definition.giver_id, tx.now()): return "person_unavailable"
	if not job_for(tx.snapshot(), actor_id, definition_id).is_empty(): return "job_already_taken"
	if definition.deadline_minutes > WorldData.MAX_COUNTER - tx.now(): return "job_deadline_overflow"
	var state := tx.read_domain(DOMAIN)
	if state.jobs.has(job_id): return "duplicate_job"
	error = _commerce.hold_payment(tx, job_id, definition.giver_id, actor_id, definition.reward, DOMAIN)
	if not error.is_empty(): return error
	var deadline: int = tx.now() + definition.deadline_minutes
	state.jobs[job_id] = {"definition_id": definition_id, "actor_id": actor_id, "status": "accepted", "accepted_at": tx.now(), "deadline": deadline, "resolved_at": -1}
	if not tx.write_domain(DOMAIN, state): return "work_write_failed"
	return tx.schedule({"id": expiry_id(job_id), "kind": EXPIRE, "target_id": definition.giver_id, "due": deadline, "payload": {"job_id": job_id}})

func deliver(tx: WorldTransaction, actor_id: String, definition_id: String) -> String:
	var record := job_for(tx.snapshot(), actor_id, definition_id)
	if record.is_empty() or record.status != "accepted": return "job_not_active"
	if tx.now() >= record.deadline: return "job_expired"
	var definition: Dictionary = _definitions[definition_id]
	var error := _interactions.reach_error(tx, actor_id, definition.recipient_id)
	if not error.is_empty(): return error
	if not _interactions.available(definition.recipient_id, tx.now()): return "person_unavailable"
	for item in definition.requirements:
		error = _inventory.transfer(tx, actor_id, definition.recipient_id, item, definition.requirements[item])
		if not error.is_empty(): return error
	error = _commerce.resolve_payment(tx, record.id, true)
	if not error.is_empty(): return error
	error = tx.cancel(expiry_id(record.id))
	if not error.is_empty(): return error
	return _set_outcome(tx, record.id, "completed")

func cancel(tx: WorldTransaction, actor_id: String, definition_id: String) -> String:
	var record := job_for(tx.snapshot(), actor_id, definition_id)
	if record.is_empty() or record.status != "accepted": return "job_not_active"
	if tx.now() >= record.deadline: return "job_expired"
	var error := _commerce.resolve_payment(tx, record.id, false)
	if not error.is_empty(): return error
	error = tx.cancel(expiry_id(record.id))
	if not error.is_empty(): return error
	return _set_outcome(tx, record.id, "cancelled")

func _set_outcome(tx: WorldTransaction, job_id: String, status: String) -> String:
	var state := tx.read_domain(DOMAIN)
	state.jobs[job_id].status = status
	state.jobs[job_id].resolved_at = tx.now()
	return "" if tx.write_domain(DOMAIN, state) else "work_write_failed"

func event_kinds() -> Array[String]:
	return [EXPIRE]

func validate_event(event: Dictionary, snapshot: Dictionary) -> String:
	if not WorldData.keys(event.payload, ["job_id"]) or not event.payload.job_id is String: return "expiry_payload"
	var jobs: Variant = snapshot.domains[DOMAIN].get("jobs")
	if not jobs is Dictionary or not jobs.has(event.payload.job_id): return "expiry_job_reference"
	var record: Dictionary = jobs[event.payload.job_id]
	if event.id != expiry_id(event.payload.job_id) or event.due != record.deadline: return "expiry_identity"
	if event.target_id != _definitions[record.definition_id].giver_id: return "expiry_target"
	return ""

func handle_event(event: Dictionary, tx: WorldTransaction) -> String:
	var job_id: String = event.payload.job_id
	var record: Dictionary = tx.read_domain(DOMAIN).jobs[job_id]
	if record.status != "accepted" or record.deadline != tx.now(): return "invalid_expiry"
	var error := _commerce.resolve_payment(tx, job_id, false)
	if not error.is_empty(): return error
	return _set_outcome(tx, job_id, "expired")

func validate(state: Dictionary, snapshot: Dictionary) -> String:
	if not WorldData.keys(state, ["jobs"]) or not state.jobs is Dictionary: return "work_schema"
	var money: Variant = snapshot.domains.get(CommerceRules.DOMAIN)
	if not WorldData.keys(money, ["wallets", "holds"]) or not money.holds is Dictionary: return "work_payment_state"
	if not WorldData.keys(snapshot.scheduler, ["events", "next_sequence"]) or not snapshot.scheduler.events is Dictionary: return "work_scheduler_state"
	var seen: Dictionary = {}
	for id in state.jobs:
		var job: Variant = state.jobs[id]
		if not WorldData.id(id) or not WorldData.keys(job, ["definition_id", "actor_id", "status", "accepted_at", "deadline", "resolved_at"]): return "work_record"
		if not job.definition_id is String or not _definitions.has(job.definition_id) or not job.actor_id in _interactions.actors(): return "work_reference"
		var unique := "%s/%s" % [job.actor_id, job.definition_id]
		if seen.has(unique): return "duplicate_work_offer"
		seen[unique] = true
		var definition: Dictionary = _definitions[job.definition_id]
		if not WorldData.integer(job.accepted_at, 0, snapshot.minute) or not WorldData.integer(job.deadline, 1): return "work_time"
		if job.deadline != job.accepted_at + definition.deadline_minutes: return "work_deadline"
		if not job.status in ["accepted", "completed", "expired", "cancelled"]: return "work_status"
		var pending: bool = job.status == "accepted"
		if pending:
			if not WorldData.integer(job.resolved_at, -1, -1) or job.deadline < snapshot.minute: return "stale_work"
			var hold: Variant = money.holds.get(id)
			if not WorldData.keys(hold, ["payer", "payee", "amount", "owner_domain"]): return "missing_work_payment"
			if not hold.payer is String or not hold.payee is String or not hold.owner_domain is String or not WorldData.integer(hold.amount, 1): return "work_payment_mismatch"
			if hold.payer != definition.giver_id or hold.payee != job.actor_id or hold.amount != definition.reward or hold.owner_domain != DOMAIN: return "work_payment_mismatch"
		else:
			if money.holds.has(id) or not WorldData.integer(job.resolved_at, job.accepted_at, snapshot.minute): return "terminal_work_payment"
			if job.status == "expired" and job.resolved_at != job.deadline: return "work_expiry_time"
			if job.status != "expired" and job.resolved_at >= job.deadline: return "work_resolution_time"
		var event: Variant = snapshot.scheduler.events.get(expiry_id(id))
		if not event is Dictionary or not event.has("status"): return "missing_work_expiry"
		var expected: String = "pending" if pending else "completed" if job.status == "expired" else "cancelled"
		if not event.status is String or event.status != expected: return "work_expiry_status"
	for id in money.holds:
		var hold: Variant = money.holds[id]
		if hold is Dictionary and hold.get("owner_domain") is String and hold.owner_domain == DOMAIN and not state.jobs.has(id): return "orphan_work_payment"
	return ""
