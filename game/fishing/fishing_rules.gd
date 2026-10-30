class_name FishingRules
extends SessionDomain
## One saved opportunity per actor; active milliseconds, seeded location pools.
const DOMAIN: String = "fishing"
var _spots: Dictionary
var _inventory: InventoryRules
var _interactions: InteractionRules

static func create(config: Dictionary, inventory: InventoryRules, interactions: InteractionRules) -> FishingRules:
	if not WorldData.keys(config, ["spots"]) or not config.spots is Dictionary: return null
	for id in config.spots:
		var spot: Variant = config.spots[id]
		if not id in interactions.target_ids() or not WorldData.keys(spot, ["label", "bite_ms", "window_ms", "pool"]): return null
		if not spot.label is String or not WorldData.integer(spot.bite_ms, 500, 10000) or not WorldData.integer(spot.window_ms, 300, 5000): return null
		if not spot.pool is Array or spot.pool.is_empty(): return null
		for entry in spot.pool:
			if not WorldData.keys(entry, ["bait", "fish", "weight"]): return null
			if not entry.bait is String or not entry.fish is String or inventory.item_definition(entry.bait).is_empty() or inventory.item_definition(entry.fish).is_empty() or not WorldData.integer(entry.weight, 1, 1000): return null
	var rules := FishingRules.new()
	rules._spots = config.spots.duplicate(true)
	rules._inventory = inventory
	rules._interactions = interactions
	return rules

func domain_id() -> String:
	return DOMAIN

func initial_state() -> Dictionary:
	return {"next_cast": 1, "attempts": {}}

func spots() -> Dictionary:
	return _spots.duplicate(true)

func attempt(snapshot: Dictionary, actor_id: String) -> Dictionary:
	return snapshot.domains[DOMAIN].attempts.get(actor_id, {}).duplicate(true)

func baits() -> Array:
	var result: Array = []
	for spot in _spots.values():
		for entry in spot.pool:
			if not entry.bait in result: result.append(entry.bait)
	result.sort()
	return result

func _fish(world_id: String, spot_id: String, bait: String, ordinal: int) -> String:
	var pool: Array = _spots[spot_id].pool.filter(func(entry): return entry.bait == bait)
	var total := 0
	for entry in pool: total += int(entry.weight)
	if total == 0: return ""
	var roll := (world_id + "/" + spot_id + "/" + bait + "/" + str(ordinal)).sha256_text().substr(0, 8).hex_to_int() % total
	for entry in pool:
		roll -= int(entry.weight)
		if roll < 0: return entry.fish
	return ""

func cast(tx: WorldTransaction, actor_id: String, spot_id: String, bait: String) -> String:
	if not _spots.has(spot_id): return "unknown_fishing_spot"
	var error := _interactions.reach_error(tx, actor_id, spot_id)
	if not error.is_empty(): return error
	var previous := attempt(tx.snapshot(), actor_id)
	if previous.get("status", "") in ["waiting", "ready"]: return "fishing_in_progress"
	var state := tx.read_domain(DOMAIN)
	if state.next_cast >= WorldData.MAX_COUNTER: return "cast_counter_exhausted"
	var fish := _fish(tx.snapshot().world_id, spot_id, bait, state.next_cast)
	if fish.is_empty(): return "bait_unsuitable"
	var reservation := "fishing.bait." + str(state.next_cast)
	error = _inventory.reserve(tx, reservation, actor_id, {bait: 1}, DOMAIN)
	if not error.is_empty(): return error
	# Bait is spent at cast, including misses/cancellation. No reserved duplicate remains.
	error = _inventory.transform_reserved(tx, reservation, {})
	if not error.is_empty(): return error
	state.attempts[actor_id] = {"spot_id": spot_id, "bait": bait, "fish": fish, "ordinal": state.next_cast, "elapsed_ms": 0, "status": "waiting"}
	state.next_cast += 1
	return "" if tx.write_domain(DOMAIN, state) else "fishing_write_failed"

func progress(tx: WorldTransaction, actor_id: String, milliseconds: Variant) -> String:
	if not WorldData.integer(milliseconds, 1, 10000): return "invalid_fishing_duration"
	var state := tx.read_domain(DOMAIN)
	var record: Dictionary = state.attempts.get(actor_id, {})
	if record.get("status", "") != "waiting": return "fishing_not_waiting"
	var error := _interactions.reach_error(tx, actor_id, record.spot_id)
	if not error.is_empty(): return error
	var spot: Dictionary = _spots[record.spot_id]
	record.elapsed_ms = mini(record.elapsed_ms + int(milliseconds), spot.bite_ms + spot.window_ms)
	if record.elapsed_ms >= spot.bite_ms + spot.window_ms: record.status = "missed"
	return "" if tx.write_domain(DOMAIN, state) else "fishing_write_failed"

func reel(tx: WorldTransaction, actor_id: String) -> String:
	var state := tx.read_domain(DOMAIN)
	var record: Dictionary = state.attempts.get(actor_id, {})
	if not record.get("status", "") in ["waiting", "ready"]: return "nothing_to_reel"
	var error := _interactions.reach_error(tx, actor_id, record.spot_id)
	if not error.is_empty(): return error
	if record.status == "waiting" and record.elapsed_ms < _spots[record.spot_id].bite_ms:
		record.status = "missed"
	else:
		error = _inventory.add_goods(tx, actor_id, {record.fish: 1})
		if error == "container_full": record.status = "ready"
		elif not error.is_empty(): return error
		else: record.status = "caught"
	return "" if tx.write_domain(DOMAIN, state) else "fishing_write_failed"

func cancel(tx: WorldTransaction, actor_id: String) -> String:
	var state := tx.read_domain(DOMAIN)
	if not state.attempts.has(actor_id) or not state.attempts[actor_id].status in ["waiting", "ready"]: return "no_active_fishing"
	state.attempts[actor_id].status = "cancelled"
	return "" if tx.write_domain(DOMAIN, state) else "fishing_write_failed"

func validate(state: Dictionary, snapshot: Dictionary) -> String:
	if not WorldData.keys(state, ["next_cast", "attempts"]) or not WorldData.integer(state.next_cast, 1) or not state.attempts is Dictionary: return "fishing_schema"
	var ordinals: Array = []
	for actor in state.attempts:
		var record: Variant = state.attempts[actor]
		if not actor in _interactions.actors() or not WorldData.keys(record, ["spot_id", "bait", "fish", "ordinal", "elapsed_ms", "status"]): return "fishing_record"
		if not record.spot_id is String or not _spots.has(record.spot_id) or not record.bait is String or not record.fish is String or record.fish.is_empty(): return "fishing_reference"
		if not WorldData.integer(record.ordinal, 1, state.next_cast - 1) or record.ordinal in ordinals: return "fishing_ordinal"
		ordinals.append(record.ordinal)
		if record.fish != _fish(snapshot.world_id, record.spot_id, record.bait, record.ordinal): return "fishing_seed"
		var spot: Dictionary = _spots[record.spot_id]
		if not WorldData.integer(record.elapsed_ms, 0, spot.bite_ms + spot.window_ms) or not record.status in ["waiting", "ready", "caught", "missed", "cancelled"]: return "fishing_status"
		if record.status == "waiting" and record.elapsed_ms >= spot.bite_ms + spot.window_ms: return "fishing_expired"
		if record.status in ["ready", "caught"] and (record.elapsed_ms < spot.bite_ms or record.elapsed_ms >= spot.bite_ms + spot.window_ms): return "fishing_timing"
	return ""
