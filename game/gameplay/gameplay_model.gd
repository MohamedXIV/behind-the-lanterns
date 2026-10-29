class_name GameplayModel
extends RefCounted
## Concrete gameplay composition and command entry points. No generic action bus.

signal session_replaced(candidate: GameSession)

var session: GameSession
var inventory: InventoryRules
var commerce: CommerceRules
var interactions: InteractionRules
var npcs: NpcScheduleRules
var crafting: CraftingRules
var work: WorkRules

static func create(data: Dictionary, world_id: String) -> GameplayModel:
	if not WorldData.valid(data) or not WorldData.keys(data, ["world", "inventory", "economy", "interactions"], ["presentation", "npcs", "crafting", "work", "start_minute"]): return null
	# Match the codec's canonical numeric representation at content ingestion.
	data = WorldData.normalize(data)
	for field in ["world", "inventory", "economy", "interactions"]:
		if not data[field] is Dictionary: return null
	for field in ["npcs", "crafting", "work"]:
		if data.has(field) and not data[field] is Dictionary: return null
	if not WorldData.integer(data.get("start_minute", 0)): return null
	var content := {"inventory": data.inventory, "economy": data.economy, "interactions": data.interactions}
	for field in ["npcs", "crafting", "work", "start_minute"]:
		if data.has(field): content[field] = data[field]
	var definition := WorldDefinition.create(data.world, content)
	if definition == null: return null
	var model := GameplayModel.new()
	model.inventory = InventoryRules.create(data.inventory)
	if model.inventory == null: return null
	model.commerce = CommerceRules.create(data.economy, model.inventory)
	if model.commerce == null: return null
	model.npcs = NpcScheduleRules.create(data.get("npcs", {}), data.world, data.interactions)
	if model.npcs == null: return null
	model.interactions = InteractionRules.create(data.interactions, model.inventory, model.commerce, model.npcs)
	if model.interactions == null or not model.interactions.validate_world(data.world): return null
	for npc in model.npcs.ids():
		if not npc in model.interactions.target_ids(): return null
	for item_id in model.inventory.item_ids():
		if not definition.has_definition(item_id): return null
	model.crafting = CraftingRules.create(data.get("crafting", {"recipes": {}, "stations": {}}), model.inventory, model.interactions)
	if model.crafting == null: return null
	for recipe in model.crafting.recipes().values():
		if not definition.has_definition(recipe.station_definition): return null
	model.work = WorkRules.create(data.get("work", {}), model.inventory, model.commerce, model.interactions)
	if model.work == null: return null
	model.session = GameSession.create(definition, [model.inventory, model.commerce, model.interactions, model.crafting, model.work], world_id)
	if model.session != null and not model.session.advance_to(data.get("start_minute", 0)).ok: return null
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

func wait_minutes(intent: String, actor_id: String, minutes: Variant) -> OperationResult:
	if not actor_id in interactions.actors() or not WorldData.integer(minutes, 1, WorldData.MAX_COUNTER - session.now()):
		return OperationResult.failure("invalid_wait")
	return session.transact(intent, func(_tx: WorldTransaction) -> String: return "", session.now() + int(minutes))

func accept_job(intent: String, actor_id: String, definition_id: String) -> OperationResult:
	return session.transact(intent, func(tx: WorldTransaction) -> String:
		return work.accept(tx, actor_id, definition_id, "work." + intent.sha256_text()))

func deliver_job(intent: String, actor_id: String, definition_id: String) -> OperationResult:
	return session.transact(intent, func(tx: WorldTransaction) -> String: return work.deliver(tx, actor_id, definition_id))

func cancel_job(intent: String, actor_id: String, definition_id: String) -> OperationResult:
	return session.transact(intent, func(tx: WorldTransaction) -> String: return work.cancel(tx, actor_id, definition_id))

func start_craft(intent: String, actor_id: String, recipe_id: String, station_id: String) -> OperationResult:
	return session.transact(intent, func(tx: WorldTransaction) -> String:
		return crafting.start(tx, actor_id, recipe_id, station_id, "craft." + intent.sha256_text()))

func progress_craft(intent: String, actor_id: String, seconds: Variant) -> OperationResult:
	return session.transact(intent, func(tx: WorldTransaction) -> String: return crafting.progress(tx, actor_id, seconds))

func collect_craft(intent: String, actor_id: String) -> OperationResult:
	return session.transact(intent, func(tx: WorldTransaction) -> String: return crafting.collect(tx, actor_id))

func cancel_craft(intent: String, actor_id: String) -> OperationResult:
	return session.transact(intent, func(tx: WorldTransaction) -> String: return crafting.cancel(tx, actor_id))

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

func enter(intent: String, actor_id: String, portal_id: String) -> OperationResult:
	return session.transact(intent, func(tx: WorldTransaction) -> String: return interactions.enter(tx, actor_id, portal_id))

func actor_region(actor_id: String) -> String:
	return session.snapshot().entities[actor_id].region_id
