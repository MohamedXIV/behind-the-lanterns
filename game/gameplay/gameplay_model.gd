class_name GameplayModel
extends RefCounted
## Concrete gameplay composition and command entry points. No generic action bus.

signal session_replaced(candidate: GameSession)

var session: GameSession
var inventory: InventoryRules
var commerce: CommerceRules
var interactions: InteractionRules

static func create(data: Dictionary, world_id: String) -> GameplayModel:
	if not WorldData.valid(data) or not WorldData.keys(data, ["world", "inventory", "economy", "interactions"], ["presentation"]): return null
	# Match the codec's canonical numeric representation at content ingestion.
	data = WorldData.normalize(data)
	for field in ["world", "inventory", "economy", "interactions"]:
		if not data[field] is Dictionary: return null
	var model := GameplayModel.new()
	model.inventory = InventoryRules.create(data.inventory)
	if model.inventory == null: return null
	model.commerce = CommerceRules.create(data.economy, model.inventory)
	if model.commerce == null: return null
	model.interactions = InteractionRules.create(data.interactions, model.inventory, model.commerce)
	if model.interactions == null: return null
	var definition := WorldDefinition.create(data.world, {"inventory": data.inventory, "economy": data.economy, "interactions": data.interactions})
	if definition == null: return null
	for item_id in model.inventory.item_ids():
		if not definition.has_definition(item_id): return null
	model.session = GameSession.create(definition, [model.inventory, model.commerce, model.interactions], world_id)
	return model if model.session != null else null

func act(intent: String, actor_id: String, target_id: String, item_id: String, amount: Variant, verb: String, unit_quote: Variant = 0) -> OperationResult:
	return session.transact(intent, func(tx: WorldTransaction) -> String:
		return interactions.interact(tx, actor_id, target_id, item_id, amount, verb, unit_quote))

func move_actor(intent: String, actor_id: String, x: Variant, y: Variant) -> OperationResult:
	return session.transact(intent, func(tx: WorldTransaction) -> String:
		return interactions.move_actor(tx, actor_id, x, y))

func position_of(entity_id: String) -> Vector2:
	return interactions.position_of(session.snapshot(), entity_id)

func wallet(entity_id: String) -> int:
	return session.snapshot().domains.commerce.wallets.get(entity_id, 0)

func adopt(candidate: GameSession) -> bool:
	if candidate == null or candidate.is_closed(): return false
	if candidate == session: return true
	var old := session.snapshot()
	var incoming := candidate.snapshot()
	if incoming.world_id != old.world_id or incoming.content_hash != old.content_hash or incoming.domain_versions != old.domain_versions: return false
	if not session.close(): return false
	session = candidate
	session_replaced.emit(candidate)
	return true
