class_name FarmingRules
extends SessionDomain
## Lazy time-anchored cultivation, environment/soil viability, and bounded skill modifiers.

const DOMAIN: String = "farming"
var _plots: Dictionary
var _crops: Dictionary
var _max_skill: int = 3
var _initial_skills: Dictionary = {}
var _inventory: InventoryRules
var _interactions: InteractionRules

static func create(config: Dictionary, inventory: InventoryRules, interactions: InteractionRules) -> FarmingRules:
	if not WorldData.valid(config) or not WorldData.keys(config, ["plots", "crops"], ["max_skill", "initial_skills"]): return null
	if not config.plots is Dictionary or config.plots.is_empty() or not config.crops is Dictionary or config.crops.is_empty(): return null
	var max_skill: int = int(config.get("max_skill", 3))
	if not WorldData.integer(config.get("max_skill", 3), 0, 100): return null
	var initial_skills: Variant = config.get("initial_skills", {})
	if not initial_skills is Dictionary: return null
	for actor in initial_skills:
		if not actor in interactions.actors() or not WorldData.integer(initial_skills[actor], 0, max_skill): return null
	for id in config.plots:
		var plot: Variant = config.plots[id]
		if not id in interactions.target_ids() or not WorldData.keys(plot, ["label", "access", "owner_id", "environment", "soil"]): return null
		if not plot.label is String or plot.label.is_empty() or not plot.access in ["public", "owner"] or not plot.owner_id is String: return null
		if plot.access == "owner" and not WorldData.id(plot.owner_id): return null
		if not WorldData.id(plot.environment) or not WorldData.id(plot.soil): return null
	for id in config.crops:
		var crop: Variant = config.crops[id]
		if not WorldData.id(id) or not WorldData.keys(crop, ["label", "seed", "outputs", "environments", "soils", "growth_minutes", "required_waterings", "watering_interval_minutes"], ["skilled_soils", "soil_skill_min", "max_watering_reduction", "growth_reduction_per_skill", "min_growth_minutes"]): return null
		if not crop.label is String or crop.label.is_empty() or not crop.seed is String or inventory.item_definition(crop.seed).is_empty(): return null
		if not crop.outputs is Dictionary or crop.outputs.is_empty(): return null
		for item in crop.outputs:
			if inventory.item_definition(item).is_empty() or not WorldData.integer(crop.outputs[item], 1): return null
		if not _valid_id_list(crop.environments) or not _valid_id_list(crop.soils): return null
		var skilled: Variant = crop.get("skilled_soils", [])
		if not skilled is Array or (not skilled.is_empty() and not _valid_id_list(skilled)): return null
		for soil in skilled:
			if soil in crop.soils: return null
		if not WorldData.integer(crop.get("soil_skill_min", 1 if not skilled.is_empty() else 0), 0, max_skill): return null
		if not WorldData.integer(crop.growth_minutes, 1) or not WorldData.integer(crop.required_waterings, 1, 100) or not WorldData.integer(crop.watering_interval_minutes, 1): return null
		if not WorldData.integer(crop.get("max_watering_reduction", 0), 0, int(crop.required_waterings) - 1): return null
		if not WorldData.integer(crop.get("growth_reduction_per_skill", 0), 0, int(crop.growth_minutes)): return null
		if not WorldData.integer(crop.get("min_growth_minutes", crop.growth_minutes), 1, int(crop.growth_minutes)): return null
	var rules := FarmingRules.new()
	rules._plots = config.plots.duplicate(true)
	rules._crops = config.crops.duplicate(true)
	rules._max_skill = max_skill
	rules._initial_skills = initial_skills.duplicate(true)
	rules._inventory = inventory
	rules._interactions = interactions
	return rules

static func _valid_id_list(values: Variant) -> bool:
	if not values is Array or values.is_empty(): return false
	var seen: Dictionary = {}
	for entry in values:
		if not WorldData.id(entry) or seen.has(entry): return false
		seen[entry] = true
	return true

func domain_id() -> String:
	return DOMAIN

func initial_state() -> Dictionary:
	return {"plots": {}, "skills": _initial_skills.duplicate(true), "next_plant": 1}

func plots() -> Dictionary:
	return _plots.duplicate(true)

func crops() -> Dictionary:
	return _crops.duplicate(true)

func max_skill() -> int:
	return _max_skill

func skill(snapshot: Dictionary, actor_id: String) -> int:
	return int(snapshot.domains[DOMAIN].skills.get(actor_id, 0))

func can_access(actor_id: String, plot_id: String) -> bool:
	if not _plots.has(plot_id): return false
	var plot: Dictionary = _plots[plot_id]
	return plot.access == "public" or (plot.access == "owner" and plot.owner_id == actor_id)

func effective_rules(crop_id: String, actor_skill: int) -> Dictionary:
	if not _crops.has(crop_id): return {}
	var crop: Dictionary = _crops[crop_id]
	var clamped := clampi(actor_skill, 0, _max_skill)
	var max_red: int = int(crop.get("max_watering_reduction", 0))
	var waterings := maxi(1, int(crop.required_waterings) - mini(clamped, max_red))
	var step_red: int = int(crop.get("growth_reduction_per_skill", 0))
	var min_growth: int = int(crop.get("min_growth_minutes", crop.growth_minutes))
	var growth := maxi(min_growth, int(crop.growth_minutes) - clamped * step_red)
	var allowed_soils: Array = crop.soils.duplicate()
	var skilled_soils: Array = crop.get("skilled_soils", [])
	if clamped >= int(crop.get("soil_skill_min", 1 if not skilled_soils.is_empty() else 0)):
		for soil in skilled_soils:
			if not soil in allowed_soils: allowed_soils.append(soil)
	return {
		"required_waterings": waterings,
		"growth_minutes": growth,
		"watering_interval_minutes": int(crop.watering_interval_minutes),
		"environments": crop.environments.duplicate(),
		"soils": allowed_soils
	}

func compatibility_error(plot_id: String, crop_id: String, actor_skill: int) -> String:
	if not _plots.has(plot_id): return "unknown_plot"
	if not _crops.has(crop_id): return "unknown_crop"
	var plot: Dictionary = _plots[plot_id]
	var crop: Dictionary = _crops[crop_id]
	if not plot.environment in crop.environments: return "incompatible_environment"
	var effective := effective_rules(crop_id, actor_skill)
	if plot.soil in effective.soils: return ""
	if plot.soil in crop.get("skilled_soils", []): return "skill_required_for_soil"
	return "unsuitable_soil"

func plot_error(tx: WorldTransaction, actor_id: String, plot_id: String) -> String:
	if not _plots.has(plot_id): return "unknown_plot"
	if not can_access(actor_id, plot_id): return "access_denied"
	return _interactions.reach_error(tx, actor_id, plot_id)

func projection(snapshot: Dictionary, plot_id: String) -> Dictionary:
	var state: Dictionary = snapshot.domains[DOMAIN]
	if not state.plots.has(plot_id): return {}
	var record: Dictionary = state.plots[plot_id]
	var crop: Dictionary = _crops[record.crop_id]
	var effective := effective_rules(record.crop_id, int(record.skill))
	var elapsed: int = int(snapshot.minute) - int(record.planted_at)
	var watered: int = record.waterings.size()
	var needed: int = effective.required_waterings
	var interval: int = effective.watering_interval_minutes
	var growth: int = effective.growth_minutes
	var next_water_in: int = 0
	if watered < needed and not record.waterings.is_empty():
		next_water_in = maxi(0, int(record.waterings[-1]) + interval - int(snapshot.minute))
	var can_water: bool = record.status == "growing" and watered < needed and next_water_in == 0
	var ripe: bool = record.status == "ready" or (elapsed >= growth and watered >= needed)
	var stage: String = "ready" if record.status == "ready" else "ripe" if ripe else "parched" if elapsed >= growth and watered < needed else "needs_water" if can_water else "growing"
	return {
		"plot_id": plot_id,
		"crop_id": record.crop_id,
		"label": crop.label,
		"actor_id": record.actor_id,
		"skill": int(record.skill),
		"planted_at": int(record.planted_at),
		"elapsed_minutes": elapsed,
		"growth_minutes": growth,
		"remaining_minutes": maxi(0, growth - elapsed),
		"waterings_done": watered,
		"waterings_needed": needed,
		"next_water_in": next_water_in,
		"can_water": can_water,
		"ripe": ripe,
		"status": record.status,
		"stage": stage
	}

func plant(tx: WorldTransaction, actor_id: String, plot_id: String, crop_id: String) -> String:
	if not _crops.has(crop_id): return "unknown_crop"
	var error := plot_error(tx, actor_id, plot_id)
	if not error.is_empty(): return error
	var state := tx.read_domain(DOMAIN)
	if state.plots.has(plot_id): return "plot_occupied"
	if state.next_plant >= WorldData.MAX_COUNTER: return "plant_counter_exhausted"
	var current_skill := skill(tx.snapshot(), actor_id)
	error = compatibility_error(plot_id, crop_id, current_skill)
	if not error.is_empty(): return error
	var crop: Dictionary = _crops[crop_id]
	var reservation := "farming.seed." + str(state.next_plant)
	error = _inventory.reserve(tx, reservation, actor_id, {crop.seed: 1}, DOMAIN)
	if not error.is_empty(): return error
	# Planting consumes one seed and creates one planted plot instance.
	error = _inventory.transform_reserved(tx, reservation, {})
	if not error.is_empty(): return error
	state.plots[plot_id] = {
		"crop_id": crop_id,
		"actor_id": actor_id,
		"skill": current_skill,
		"ordinal": state.next_plant,
		"planted_at": tx.now(),
		"waterings": [],
		"status": "growing"
	}
	state.next_plant += 1
	return "" if tx.write_domain(DOMAIN, state) else "farming_write_failed"

func water(tx: WorldTransaction, actor_id: String, plot_id: String) -> String:
	var error := plot_error(tx, actor_id, plot_id)
	if not error.is_empty(): return error
	var state := tx.read_domain(DOMAIN)
	if not state.plots.has(plot_id): return "nothing_to_water"
	var record: Dictionary = state.plots[plot_id]
	if record.status != "growing": return "watering_complete"
	var effective := effective_rules(record.crop_id, int(record.skill))
	if record.waterings.size() >= effective.required_waterings: return "watering_complete"
	if not record.waterings.is_empty() and tx.now() - int(record.waterings[-1]) < effective.watering_interval_minutes: return "already_watered_recently"
	record.waterings.append(tx.now())
	return "" if tx.write_domain(DOMAIN, state) else "farming_write_failed"

func harvest(tx: WorldTransaction, actor_id: String, plot_id: String) -> String:
	var error := plot_error(tx, actor_id, plot_id)
	if not error.is_empty(): return error
	var state := tx.read_domain(DOMAIN)
	if not state.plots.has(plot_id): return "nothing_to_harvest"
	var record: Dictionary = state.plots[plot_id]
	var projected := projection(tx.snapshot(), plot_id)
	if record.status != "ready" and not projected.ripe:
		if projected.elapsed_minutes >= projected.growth_minutes and projected.waterings_done < projected.waterings_needed:
			return "watering_required"
		return "crop_not_ripe"
	var crop: Dictionary = _crops[record.crop_id]
	error = _inventory.add_goods(tx, actor_id, crop.outputs)
	if error == "container_full":
		if record.status == "ready": return "container_full"
		record.status = "ready"
		return "" if tx.write_domain(DOMAIN, state) else "farming_write_failed"
	if not error.is_empty(): return error
	state.plots.erase(plot_id)
	var current_skill: int = int(state.skills.get(actor_id, 0))
	state.skills[actor_id] = mini(current_skill + 1, _max_skill)
	return "" if tx.write_domain(DOMAIN, state) else "farming_write_failed"

func clear(tx: WorldTransaction, actor_id: String, plot_id: String) -> String:
	var error := plot_error(tx, actor_id, plot_id)
	if not error.is_empty(): return error
	var state := tx.read_domain(DOMAIN)
	if not state.plots.has(plot_id): return "nothing_to_clear"
	state.plots.erase(plot_id)
	return "" if tx.write_domain(DOMAIN, state) else "farming_write_failed"

func validate(state: Dictionary, snapshot: Dictionary) -> String:
	if not WorldData.keys(state, ["plots", "skills", "next_plant"]) or not state.plots is Dictionary or not state.skills is Dictionary or not WorldData.integer(state.next_plant, 1): return "farming_schema"
	var inventory: Variant = snapshot.domains.get(InventoryRules.DOMAIN)
	if not WorldData.keys(inventory, ["contents", "reservations"]) or not inventory.reservations is Dictionary: return "farming_inventory_state"
	for plot_id in _plots:
		if not snapshot.entities.has(plot_id): return "farming_plot_entity"
		var owner: String = _plots[plot_id].owner_id
		if not owner.is_empty() and not snapshot.entities.has(owner): return "farming_plot_owner"
	for actor in state.skills:
		if not actor in _interactions.actors() or not WorldData.integer(state.skills[actor], 0, _max_skill): return "farming_skill"
	var ordinals: Array = []
	for plot_id in state.plots:
		if not _plots.has(plot_id): return "farming_unknown_plot"
		var record: Variant = state.plots[plot_id]
		if not WorldData.keys(record, ["crop_id", "actor_id", "skill", "ordinal", "planted_at", "waterings", "status"]): return "farming_record"
		if not record.crop_id is String or not _crops.has(record.crop_id) or not record.actor_id in _interactions.actors(): return "farming_reference"
		if not WorldData.integer(record.skill, 0, _max_skill): return "farming_record_skill"
		if not can_access(record.actor_id, plot_id): return "farming_access"
		if not compatibility_error(plot_id, record.crop_id, int(record.skill)).is_empty(): return "farming_incompatible"
		if not WorldData.integer(record.ordinal, 1, state.next_plant - 1) or record.ordinal in ordinals: return "farming_ordinal"
		ordinals.append(record.ordinal)
		if not WorldData.integer(record.planted_at, 0, snapshot.minute): return "farming_planted_time"
		if not record.waterings is Array or not record.status in ["growing", "ready"]: return "farming_status"
		var effective := effective_rules(record.crop_id, int(record.skill))
		if record.waterings.size() > effective.required_waterings: return "farming_overwatered"
		var previous: int = -1
		for timestamp in record.waterings:
			if not WorldData.integer(timestamp, record.planted_at, snapshot.minute): return "farming_watering_time"
			if previous != -1 and int(timestamp) < previous + effective.watering_interval_minutes: return "farming_watering_order"
			previous = int(timestamp)
		if record.status == "ready" and (snapshot.minute - record.planted_at < effective.growth_minutes or record.waterings.size() < effective.required_waterings):
			return "farming_premature_ready"
	for id in inventory.reservations:
		var reservation: Variant = inventory.reservations[id]
		if reservation is Dictionary and reservation.get("owner_domain") is String and reservation.owner_domain == DOMAIN: return "orphan_farming_reservation"
	return ""
