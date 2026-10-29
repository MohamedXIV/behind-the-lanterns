class_name CraftingRules
extends SessionDomain
## Short active-play preparation. Inputs stay in the inventory's reservation ledger.

const DOMAIN: String = "crafting"
var _recipes: Dictionary
var _stations: Dictionary
var _inventory: InventoryRules
var _interactions: InteractionRules

static func create(config: Dictionary, inventory: InventoryRules, interactions: InteractionRules) -> CraftingRules:
	if not WorldData.valid(config) or not WorldData.keys(config, ["recipes", "stations"]): return null
	if not config.recipes is Dictionary or not config.stations is Dictionary: return null
	for id in config.stations:
		var station: Variant = config.stations[id]
		if not id in interactions.target_ids() or not WorldData.keys(station, ["access", "owner_id"]): return null
		if not station.access in ["public", "owner"] or not station.owner_id is String: return null
		if station.access == "owner" and not WorldData.id(station.owner_id): return null
	for id in config.recipes:
		var recipe: Variant = config.recipes[id]
		if not WorldData.id(id) or not WorldData.keys(recipe, ["label", "station_definition", "ingredients", "outputs", "duration_seconds"]): return null
		if not recipe.label is String or not WorldData.id(recipe.station_definition): return null
		if not _seconds(recipe.duration_seconds): return null
		for field in ["ingredients", "outputs"]:
			if not recipe[field] is Dictionary or recipe[field].is_empty(): return null
			for item in recipe[field]:
				if inventory.item_definition(item).is_empty() or not WorldData.integer(recipe[field][item], 1): return null
	var rules := CraftingRules.new()
	rules._recipes = config.recipes.duplicate(true)
	rules._stations = config.stations.duplicate(true)
	rules._inventory = inventory
	rules._interactions = interactions
	return rules

static func _seconds(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value > 0 and value <= WorldData.MAX_COUNTER

func domain_id() -> String:
	return DOMAIN

func initial_state() -> Dictionary:
	return {"jobs": {}}

func recipes() -> Dictionary:
	return _recipes.duplicate(true)

func station_ids() -> Array:
	return _stations.keys()

func active_job(snapshot: Dictionary, actor_id: String) -> Dictionary:
	for id in snapshot.domains[DOMAIN].jobs:
		var job: Dictionary = snapshot.domains[DOMAIN].jobs[id]
		if job.actor_id == actor_id and job.status in ["working", "ready"]:
			var result := job.duplicate(true)
			result.id = id
			return result
	return {}

func station_error(tx: WorldTransaction, actor_id: String, station_id: String) -> String:
	if not _stations.has(station_id): return "unknown_station"
	var station: Dictionary = _stations[station_id]
	if station.access == "owner" and station.owner_id != actor_id: return "access_denied"
	return _interactions.reach_error(tx, actor_id, station_id)

func start(tx: WorldTransaction, actor_id: String, recipe_id: String, station_id: String, job_id: String) -> String:
	if not _recipes.has(recipe_id) or not WorldData.id(job_id): return "unknown_recipe"
	var error := station_error(tx, actor_id, station_id)
	if not error.is_empty(): return error
	var recipe: Dictionary = _recipes[recipe_id]
	if tx.entity(station_id).definition_id != recipe.station_definition: return "wrong_station"
	if not active_job(tx.snapshot(), actor_id).is_empty(): return "craft_in_progress"
	var state := tx.read_domain(DOMAIN)
	if state.jobs.has(job_id): return "duplicate_craft"
	error = _inventory.reserve(tx, job_id, actor_id, recipe.ingredients, DOMAIN)
	if not error.is_empty(): return error
	state.jobs[job_id] = {"actor_id": actor_id, "recipe_id": recipe_id, "station_id": station_id, "started_at": tx.now(), "elapsed": 0, "status": "working"}
	return "" if tx.write_domain(DOMAIN, state) else "craft_write_failed"

func progress(tx: WorldTransaction, actor_id: String, seconds: Variant) -> String:
	if not _seconds(seconds): return "invalid_active_duration"
	var job := active_job(tx.snapshot(), actor_id)
	if job.is_empty() or job.status != "working": return "craft_not_working"
	var error := station_error(tx, actor_id, job.station_id)
	if not error.is_empty(): return error
	var state := tx.read_domain(DOMAIN)
	var duration: float = _recipes[job.recipe_id].duration_seconds
	state.jobs[job.id].elapsed = minf(float(job.elapsed) + float(seconds), duration)
	if state.jobs[job.id].elapsed >= duration: state.jobs[job.id].status = "ready"
	if not tx.write_domain(DOMAIN, WorldData.normalize(state)): return "craft_write_failed"
	if state.jobs[job.id].status == "ready":
		error = collect(tx, actor_id)
		# A ready craft keeps its inputs reserved until outputs can fit, or cancellation.
		if error == "container_full": return ""
		return error
	return ""

func collect(tx: WorldTransaction, actor_id: String) -> String:
	var job := active_job(tx.snapshot(), actor_id)
	if job.is_empty() or job.status != "ready": return "craft_not_ready"
	var error := station_error(tx, actor_id, job.station_id)
	if not error.is_empty(): return error
	error = _inventory.transform_reserved(tx, job.id, _recipes[job.recipe_id].outputs)
	if not error.is_empty(): return error
	var state := tx.read_domain(DOMAIN)
	state.jobs[job.id].status = "completed"
	return "" if tx.write_domain(DOMAIN, state) else "craft_write_failed"

func cancel(tx: WorldTransaction, actor_id: String) -> String:
	var job := active_job(tx.snapshot(), actor_id)
	if job.is_empty(): return "craft_not_active"
	var error := _inventory.release(tx, job.id)
	if not error.is_empty(): return error
	var state := tx.read_domain(DOMAIN)
	state.jobs[job.id].status = "cancelled"
	return "" if tx.write_domain(DOMAIN, state) else "craft_write_failed"

func validate(state: Dictionary, snapshot: Dictionary) -> String:
	if not WorldData.keys(state, ["jobs"]) or not state.jobs is Dictionary: return "craft_schema"
	var inventory: Variant = snapshot.domains.get(InventoryRules.DOMAIN)
	if not WorldData.keys(inventory, ["contents", "reservations"]) or not inventory.reservations is Dictionary: return "craft_inventory_state"
	for station_id in _stations:
		if not snapshot.entities.has(station_id): return "craft_station_reference"
		var owner: String = _stations[station_id].owner_id
		if not owner.is_empty() and not snapshot.entities.has(owner): return "craft_station_owner"
	var active: Dictionary = {}
	for id in state.jobs:
		var job: Variant = state.jobs[id]
		if not WorldData.id(id) or not WorldData.keys(job, ["actor_id", "recipe_id", "station_id", "started_at", "elapsed", "status"]): return "craft_record"
		if not job.actor_id in _interactions.actors() or not job.recipe_id is String or not _recipes.has(job.recipe_id): return "craft_recipe_or_actor"
		if not job.station_id is String or not _stations.has(job.station_id): return "craft_station_reference"
		var recipe: Dictionary = _recipes[job.recipe_id]
		if snapshot.entities[job.station_id].definition_id != recipe.station_definition: return "craft_station_type"
		if not WorldData.integer(job.started_at, 0, snapshot.minute) or not typeof(job.elapsed) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(job.elapsed)): return "craft_time"
		if job.elapsed < 0 or job.elapsed > recipe.duration_seconds: return "craft_elapsed"
		if not job.status in ["working", "ready", "completed", "cancelled"]: return "craft_status"
		if job.status == "working" and job.elapsed >= recipe.duration_seconds: return "craft_working_time"
		if job.status in ["ready", "completed"] and job.elapsed != recipe.duration_seconds: return "craft_ready_time"
		if job.status in ["working", "ready"]:
			if active.has(job.actor_id): return "duplicate_active_craft"
			active[job.actor_id] = true
			var reservation: Variant = inventory.reservations.get(id)
			if not WorldData.keys(reservation, ["container_id", "owner_domain", "goods"]): return "missing_craft_reservation"
			if not reservation.container_id is String or not reservation.owner_domain is String or not reservation.goods is Dictionary: return "craft_reservation_schema"
			if reservation.container_id != job.actor_id or reservation.owner_domain != DOMAIN or reservation.goods != recipe.ingredients: return "craft_reservation_mismatch"
		elif inventory.reservations.has(id): return "terminal_craft_reservation"
	for id in inventory.reservations:
		var reservation: Variant = inventory.reservations[id]
		if reservation is Dictionary and reservation.get("owner_domain") is String and reservation.owner_domain == DOMAIN and not state.jobs.has(id): return "orphan_craft_reservation"
	return ""
