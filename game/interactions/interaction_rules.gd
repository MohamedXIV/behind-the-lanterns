class_name InteractionRules
extends SessionDomain
## Persistent actor positions and access checks; active movement is presentation.

const DOMAIN: String = "interactions"
var _config: Dictionary
var _inventory: InventoryRules
var _commerce: CommerceRules

static func create(config: Dictionary, inventory: InventoryRules, commerce: CommerceRules) -> InteractionRules:
	if inventory == null or commerce == null or not WorldData.valid(config): return null
	if not WorldData.keys(config, ["actors", "positions", "bounds", "reach"]): return null
	if not config.actors is Array or config.actors.is_empty() or not config.positions is Dictionary: return null
	if not WorldData.keys(config.bounds, ["width", "height"]): return null
	if not WorldData.integer(config.bounds.width, 1) or not WorldData.integer(config.bounds.height, 1): return null
	if not _number(config.reach) or config.reach <= 0: return null
	var rules := InteractionRules.new()
	rules._config = config.duplicate(true)
	rules._inventory = inventory
	rules._commerce = commerce
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
	if not WorldData.keys(commerce_state, ["wallets"]) or not commerce_state.wallets is Dictionary: return "actor_wallet_reference"
	for id in _config.positions:
		if not snapshot.entities.has(id): return "position_entity_reference"
	for actor in _config.actors:
		if not state.positions.has(actor) or not _valid_point(state.positions[actor]): return "invalid_actor_position"
		if not commerce_state.wallets.has(actor): return "actor_wallet_reference"
	return ""

func position_of(snapshot: Dictionary, entity_id: String) -> Vector2:
	var point: Dictionary = snapshot.domains[DOMAIN].positions.get(entity_id, _config.positions.get(entity_id, {}))
	return Vector2(point.x, point.y) if not point.is_empty() else Vector2.INF

func bounds() -> Vector2:
	return Vector2(_config.bounds.width, _config.bounds.height)

func reach() -> float:
	return _config.reach

func actors() -> Array:
	return _config.actors.duplicate()

func move_actor(tx: WorldTransaction, actor_id: String, x: Variant, y: Variant) -> String:
	if not actor_id in _config.actors: return "unknown_actor"
	if not _valid_point({"x": x, "y": y}): return "invalid_position"
	var state := tx.read_domain(DOMAIN)
	state.positions[actor_id] = WorldData.normalize({"x": x, "y": y})
	return "" if tx.write_domain(DOMAIN, state) else "position_write_failed"

func interact(tx: WorldTransaction, actor_id: String, target_id: String, item_id: String, amount: Variant, verb: String, unit_quote: Variant) -> String:
	if not actor_id in _config.actors: return "unknown_actor"
	if actor_id == target_id or not _config.positions.has(target_id): return "unknown_interaction_target"
	if tx.entity(actor_id).region_id != tx.entity(target_id).region_id: return "different_region"
	var snapshot := tx.snapshot()
	if position_of(snapshot, actor_id).distance_to(position_of(snapshot, target_id)) > reach(): return "out_of_reach"
	match verb:
		"take", "store":
			if not _inventory.can_access(actor_id, target_id): return "access_denied"
			return _inventory.transfer(tx, target_id if verb == "take" else actor_id, actor_id if verb == "take" else target_id, item_id, amount)
		"buy", "sell":
			return _commerce.exchange(tx, actor_id, target_id, item_id, amount, unit_quote, verb == "buy")
	return "unknown_action"

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

func _valid_point(point: Variant) -> bool:
	if not WorldData.keys(point, ["x", "y"]) or not _number(point.x) or not _number(point.y): return false
	return point.x >= 0 and point.y >= 0 and point.x <= _config.bounds.width and point.y <= _config.bounds.height
