class_name InteractionRules
extends SessionDomain
## Persistent actor positions and access checks; active movement is presentation.

const DOMAIN: String = "interactions"
# Binary-exact subpixel coordinates survive JSON readback without drift.
const POSITION_STEP: float = 1.0 / 256.0
var geometry: WorldGeometry
var _regions: Dictionary = {}
var _portals: Dictionary = {}
var _config: Dictionary
var _inventory: InventoryRules
var _commerce: CommerceRules
var _npcs: NpcScheduleRules

static func create(config: Dictionary, inventory: InventoryRules, commerce: CommerceRules, npcs: NpcScheduleRules = null) -> InteractionRules:
	if inventory == null or commerce == null or not WorldData.valid(config): return null
	if not WorldData.keys(config, ["actors", "positions", "bounds", "reach"], ["geometry", "regions", "portals"]): return null
	if not config.actors is Array or config.actors.is_empty() or not config.positions is Dictionary: return null
	if not WorldData.keys(config.bounds, ["width", "height"]): return null
	if not WorldData.integer(config.bounds.width, 1) or not WorldData.integer(config.bounds.height, 1): return null
	if not _number(config.reach) or config.reach <= 0: return null
	var rules := InteractionRules.new()
	rules._config = config.duplicate(true)
	rules.geometry = WorldGeometry.create(config.get("geometry", {"radius": 0, "obstacles": []}), rules.bounds())
	if rules.geometry == null: return null
	if not config.get("regions", {}) is Dictionary or not config.get("portals", {}) is Dictionary: return null
	for region in config.get("regions", {}):
		if not WorldData.id(region): return null
		var local := WorldGeometry.create(config.regions[region], rules.bounds())
		if local == null: return null
		rules._regions[region] = local
	rules._portals = config.get("portals", {}).duplicate(true)
	for id in rules._portals:
		var portal: Variant = rules._portals[id]
		if not config.positions.has(id) or not WorldData.keys(portal, ["region_id", "x", "y"]): return null
		if not WorldData.id(portal.region_id): return null
		if not rules._valid_point({"x": portal.x, "y": portal.y}) or not rules.geometry_for(portal.region_id).walkable(Vector2(portal.x, portal.y)): return null
	rules._inventory = inventory
	rules._commerce = commerce
	rules._npcs = npcs
	var seen: Dictionary = {}
	for actor in config.actors:
		if not WorldData.id(actor) or seen.has(actor) or not config.positions.has(actor): return null
		var bag := inventory.container_definition(actor)
		if bag.is_empty() or bag.access != "owner" or bag.owner_id != actor: return null
		seen[actor] = true
	for holder in inventory.container_ids():
		if not config.positions.has(holder): return null
	for id in config.positions:
		if not WorldData.id(id) or not rules._valid_point(config.positions[id]): return null
	return rules

func domain_id() -> String:
	return DOMAIN

func initial_state() -> Dictionary:
	var positions: Dictionary = {}
	for actor in _config.actors: positions[actor] = _config.positions[actor].duplicate(true)
	return {"positions": positions}

func validate(state: Dictionary, snapshot: Dictionary) -> String:
	if not WorldData.keys(state, ["positions"]) or not state.positions is Dictionary or state.positions.size() != _config.actors.size(): return "position_schema"
	var commerce_state: Variant = snapshot.domains.get(CommerceRules.DOMAIN)
	if not WorldData.keys(commerce_state, ["wallets", "holds"]) or not commerce_state.wallets is Dictionary: return "actor_wallet_reference"
	for id in _config.positions:
		if not snapshot.entities.has(id): return "position_entity_reference"
	for actor in _config.actors:
		if not state.positions.has(actor) or not _valid_point(state.positions[actor]) or not geometry_for(snapshot.entities[actor].region_id).walkable(Vector2(state.positions[actor].x, state.positions[actor].y)): return "invalid_actor_position"
		if not commerce_state.wallets.has(actor): return "actor_wallet_reference"
	return ""

func position_of(snapshot: Dictionary, entity_id: String) -> Vector2:
	if _npcs != null:
		var projected := _npcs.projection(entity_id, snapshot.minute)
		if not projected.is_empty(): return Vector2(projected.x, projected.y)
	var point: Dictionary = snapshot.domains[DOMAIN].positions.get(entity_id, _config.positions.get(entity_id, {}))
	return Vector2(point.x, point.y) if not point.is_empty() else Vector2.INF

func bounds() -> Vector2:
	return Vector2(_config.bounds.width, _config.bounds.height)

func reach() -> float:
	return _config.reach

func actors() -> Array:
	return _config.actors.duplicate()

func target_ids() -> Array:
	var result: Array = _config.positions.keys()
	result.sort()
	return result

func available(entity_id: String, minute: int) -> bool:
	return _npcs == null or _npcs.available(entity_id, minute)

func reach_error(tx: WorldTransaction, actor_id: String, target_id: String) -> String:
	if not actor_id in _config.actors: return "unknown_actor"
	if actor_id == target_id or not _config.positions.has(target_id): return "unknown_interaction_target"
	if tx.entity(actor_id).region_id != tx.entity(target_id).region_id: return "different_region"
	var snapshot := tx.snapshot()
	if position_of(snapshot, actor_id).distance_to(position_of(snapshot, target_id)) > reach(): return "out_of_reach"
	if not geometry_for(tx.entity(actor_id).region_id).clear_segment(position_of(snapshot, actor_id), position_of(snapshot, target_id)): return "interaction_obstructed"
	return ""

func move_actor(tx: WorldTransaction, actor_id: String, x: Variant, y: Variant) -> String:
	if not actor_id in _config.actors: return "unknown_actor"
	if not _valid_point({"x": x, "y": y}): return "invalid_position"
	x = snappedf(float(x), POSITION_STEP)
	y = snappedf(float(y), POSITION_STEP)
	var local := geometry_for(tx.entity(actor_id).region_id)
	if not local.walkable(Vector2(x, y)): return "position_blocked"
	if local.route(position_of(tx.snapshot(), actor_id), Vector2(x, y)).is_empty() and not position_of(tx.snapshot(), actor_id).is_equal_approx(Vector2(x, y)): return "position_unreachable"
	var state := tx.read_domain(DOMAIN)
	state.positions[actor_id] = WorldData.normalize({"x": x, "y": y})
	return "" if tx.write_domain(DOMAIN, state) else "position_write_failed"

func interact(tx: WorldTransaction, actor_id: String, target_id: String, item_id: String, amount: Variant, verb: String, unit_quote: Variant) -> String:
	var reach_result := reach_error(tx, actor_id, target_id)
	if not reach_result.is_empty(): return reach_result
	match verb:
		"take", "store":
			if not _inventory.can_access(actor_id, target_id): return "access_denied"
			return _inventory.transfer(tx, target_id if verb == "take" else actor_id, actor_id if verb == "take" else target_id, item_id, amount)
		"buy", "sell":
			if not available(target_id, tx.now()): return "person_unavailable"
			return _commerce.exchange(tx, actor_id, target_id, item_id, amount, unit_quote, verb == "buy")
	return "unknown_action"

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

func _valid_point(point: Variant) -> bool:
	if not WorldData.keys(point, ["x", "y"]) or not _number(point.x) or not _number(point.y): return false
	return point.x >= 0 and point.y >= 0 and point.x <= _config.bounds.width and point.y <= _config.bounds.height

func geometry_for(region_id: String) -> WorldGeometry:
	return _regions.get(region_id, geometry)

func is_portal(id: String) -> bool:
	return _portals.has(id)

func validate_world(world: Dictionary) -> bool:
	for region in _regions:
		if not region in world.regions: return false
	for id in _config.positions:
		if not world.entities.has(id): return false
		var point: Dictionary = _config.positions[id]
		if not geometry_for(world.entities[id].region_id).walkable(Vector2(point.x, point.y)): return false
	for id in _portals:
		if not world.entities.has(id) or not _portals[id].region_id in world.regions: return false
	return true

func enter(tx: WorldTransaction, actor_id: String, portal_id: String) -> String:
	if not _portals.has(portal_id): return "unknown_portal"
	var error := reach_error(tx, actor_id, portal_id)
	if not error.is_empty(): return error
	var destination: Dictionary = _portals[portal_id]
	error = tx.move_entity(actor_id, destination.region_id)
	if not error.is_empty(): return error
	var state := tx.read_domain(DOMAIN)
	state.positions[actor_id] = {"x": destination.x, "y": destination.y}
	return "" if tx.write_domain(DOMAIN, state) else "position_write_failed"

func relocate_actor(tx: WorldTransaction, actor_id: String, region_id: String, x: Variant, y: Variant) -> String:
	if not actor_id in _config.actors: return "unknown_actor"
	if not _valid_point({"x": x, "y": y}): return "invalid_position"
	x = snappedf(float(x), POSITION_STEP)
	y = snappedf(float(y), POSITION_STEP)
	if not geometry_for(region_id).walkable(Vector2(x, y)): return "position_blocked"
	var error := tx.move_entity(actor_id, region_id)
	if not error.is_empty(): return error
	var state := tx.read_domain(DOMAIN)
	state.positions[actor_id] = WorldData.normalize({"x": x, "y": y})
	return "" if tx.write_domain(DOMAIN, state) else "position_write_failed"
