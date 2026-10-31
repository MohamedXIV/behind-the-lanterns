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
var narrative: NarrativeRules
var fishing: FishingRules
var farming: FarmingRules
var law: LawRules
var travel: TravelRules
var housing: HousingRules
var combat: CombatRules

static func create(data: Dictionary, world_id: String) -> GameplayModel:
	if not WorldData.valid(data) or not WorldData.keys(data, ["world", "inventory", "economy", "interactions"], ["presentation", "npcs", "crafting", "work", "start_minute", "narrative", "fishing", "farming", "law", "travel", "housing", "combat"]): return null
	# Match the codec's canonical numeric representation at content ingestion.
	data = WorldData.normalize(data)
	for field in ["world", "inventory", "economy", "interactions"]:
		if not data[field] is Dictionary: return null
	for field in ["npcs", "crafting", "work", "narrative", "fishing", "farming", "law", "travel", "housing", "combat"]:
		if data.has(field) and not data[field] is Dictionary: return null
	if not WorldData.integer(data.get("start_minute", 0)): return null
	var content := {"inventory": data.inventory, "economy": data.economy, "interactions": data.interactions}
	for field in ["npcs", "crafting", "work", "start_minute", "narrative", "fishing", "farming", "law", "travel", "housing", "combat"]:
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
	var domains: Array = [model.inventory, model.commerce, model.interactions, model.crafting, model.work]
	if data.has("narrative"):
		model.narrative = NarrativeRules.create(data.narrative, data.world, model.interactions, model.work)
		if model.narrative == null: return null
		domains.append(model.narrative)
	if data.has("fishing"):
		model.fishing = FishingRules.create(data.fishing, model.inventory, model.interactions)
		if model.fishing == null: return null
		domains.append(model.fishing)
	if data.has("farming"):
		model.farming = FarmingRules.create(data.farming, model.inventory, model.interactions)
		if model.farming == null: return null
		domains.append(model.farming)
	if data.has("law"):
		model.law = LawRules.create(data.law, data.world, model.interactions, model.commerce, model.work)
		if model.law == null: return null
		domains.append(model.law)
	if data.has("travel"):
		model.travel = TravelRules.create(data.travel, data.world, model.interactions, model.commerce)
		if model.travel == null: return null
		domains.append(model.travel)
	if data.has("housing"):
		model.housing = HousingRules.create(data.housing, data.world, model.interactions, model.commerce)
		if model.housing == null: return null
		model.interactions.housing = model.housing
		domains.append(model.housing)
	if data.has("combat"):
		model.combat = CombatRules.create(data.combat, model.interactions, model.law)
		if model.combat == null or not model.combat.validate_world(data.world): return null
		domains.append(model.combat)
	model.session = GameSession.create(definition, domains, world_id)
	if model.session != null and not model.session.advance_to(data.get("start_minute", 0)).ok: return null
	return model if model.session != null else null

func act(intent: String, actor_id: String, target_id: String, item_id: String, amount: Variant, verb: String, unit_quote: Variant = 0) -> OperationResult:
	return session.transact(intent, func(tx: WorldTransaction) -> String:
		return interactions.interact(tx, actor_id, target_id, item_id, amount, verb, unit_quote))

func move_actor(intent: String, actor_id: String, x: Variant, y: Variant) -> OperationResult:
	return session.transact(intent, func(tx: WorldTransaction) -> String:
		var error := interactions.move_actor(tx, actor_id, x, y)
		if not error.is_empty(): return error
		return combat.sync_spatial(tx, actor_id) if combat != null else "")

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
	return session.transact(intent, func(tx: WorldTransaction) -> String:
		if law != null:
			var law_err := law.portal_error(tx.snapshot(), actor_id, portal_id)
			if not law_err.is_empty(): return law_err
		if narrative != null:
			var error := narrative.observe(tx, actor_id, portal_id)
			if not error.is_empty(): return error
		var enter_err := interactions.enter(tx, actor_id, portal_id)
		if not enter_err.is_empty(): return enter_err
		return combat.sync_spatial(tx, actor_id) if combat != null else "")

func actor_region(actor_id: String) -> String:
	return session.snapshot().entities[actor_id].region_id

func talk(intent: String, actor_id: String, npc_id: String, choice: Variant = -1, expected_turns: int = 0, expected_cursor: String = "") -> OperationResult:
	if narrative == null: return OperationResult.failure("no_narrative")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return narrative.talk(tx, actor_id, npc_id, choice, expected_turns, expected_cursor))

func inspect_object(intent: String, actor_id: String, target_id: String) -> OperationResult:
	if narrative == null: return OperationResult.failure("no_narrative")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return narrative.observe(tx, actor_id, target_id))

func cast_line(intent: String, actor: String, spot: String, bait: String) -> OperationResult:
	if fishing == null: return OperationResult.failure("no_fishing")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return fishing.cast(tx, actor, spot, bait))

func progress_fishing(intent: String, actor: String, milliseconds: Variant) -> OperationResult:
	if fishing == null: return OperationResult.failure("no_fishing")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return fishing.progress(tx, actor, milliseconds))

func reel_line(intent: String, actor: String) -> OperationResult:
	if fishing == null: return OperationResult.failure("no_fishing")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return fishing.reel(tx, actor))

func cancel_fishing(intent: String, actor: String) -> OperationResult:
	if fishing == null: return OperationResult.failure("no_fishing")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return fishing.cancel(tx, actor))

func plant_crop(intent: String, actor: String, plot: String, crop: String) -> OperationResult:
	if farming == null: return OperationResult.failure("no_farming")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return farming.plant(tx, actor, plot, crop))

func water_crop(intent: String, actor: String, plot: String) -> OperationResult:
	if farming == null: return OperationResult.failure("no_farming")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return farming.water(tx, actor, plot))

func harvest_crop(intent: String, actor: String, plot: String) -> OperationResult:
	if farming == null: return OperationResult.failure("no_farming")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return farming.harvest(tx, actor, plot))

func clear_plot(intent: String, actor: String, plot: String) -> OperationResult:
	if farming == null: return OperationResult.failure("no_farming")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return farming.clear(tx, actor, plot))

func confront_guard(intent: String, actor: String, target: String) -> OperationResult:
	if law == null: return OperationResult.failure("no_law")
	return session.transact(intent, func(tx: WorldTransaction) -> String:
		var err := law.confront_guard(tx, actor, target)
		if not err.is_empty(): return err
		return combat.sync_spatial(tx, actor) if combat != null else "")

func tamper_restricted(intent: String, actor: String, target: String) -> OperationResult:
	if law == null: return OperationResult.failure("no_law")
	return session.transact(intent, func(tx: WorldTransaction) -> String:
		var err := law.tamper_restricted(tx, actor, target)
		if not err.is_empty(): return err
		return combat.sync_spatial(tx, actor) if combat != null else "")

func evade_pursuit(intent: String, actor: String, refuge: String) -> OperationResult:
	if law == null: return OperationResult.failure("no_law")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return law.evade_pursuit(tx, actor, refuge))

func persuade_guard(intent: String, actor: String, guard_id: String) -> OperationResult:
	if law == null: return OperationResult.failure("no_law")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return law.persuade_guard(tx, actor, guard_id))

func surrender_to_guard(intent: String, actor: String, guard_id: String) -> OperationResult:
	if law == null: return OperationResult.failure("no_law")
	return session.transact(intent, func(tx: WorldTransaction) -> String:
		var err := law.surrender_to_guard(tx, actor, guard_id)
		if not err.is_empty(): return err
		return combat.sync_spatial(tx, actor) if combat != null else "")

func pay_fine(intent: String, actor: String, guard_id: String) -> OperationResult:
	if law == null: return OperationResult.failure("no_law")
	return session.transact(intent, func(tx: WorldTransaction) -> String:
		var err := law.pay_fine(tx, actor, guard_id)
		if not err.is_empty(): return err
		return combat.sync_spatial(tx, actor) if combat != null else "")

func serve_sentence(intent: String, actor: String) -> OperationResult:
	if law == null: return OperationResult.failure("no_law")
	var record := law.status_of(session.snapshot(), actor)
	if record.status != "detained": return OperationResult.failure("not_detained")
	return session.transact(intent, func(tx: WorldTransaction) -> String:
		return combat.sync_spatial(tx, actor) if combat != null else "", record.until_minute)

func take_route(intent: String, actor: String, route_id: String) -> OperationResult:
	if travel == null: return OperationResult.failure("no_travel")
	if session.snapshot().commands.has(intent):
		return session.transact(intent, func(_tx: WorldTransaction) -> String: return "must_not_run")
	if travel.route(route_id).is_empty(): return OperationResult.failure("unknown_route")
	var arrival := travel.arrival_minute(session.snapshot(), route_id)
	if arrival < 0: return OperationResult.failure("travel_time_overflow")
	return session.transact(intent, func(tx: WorldTransaction) -> String:
		if law != null:
			var law_error := law.public_travel_error(tx.snapshot(), actor)
			if not law_error.is_empty(): return law_error
		var board_err := travel.board(tx, actor, route_id, TravelRules.journey_id(intent))
		if not board_err.is_empty(): return board_err
		return combat.sync_spatial(tx, actor) if combat != null else "", arrival)

func acquire_housing(intent: String, actor: String, property_id: String) -> OperationResult:
	if housing == null: return OperationResult.failure("no_housing")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return housing.acquire(tx, actor, property_id))

func place_furnishing(intent: String, actor: String, id: String, property_id: String, cell_id: String) -> OperationResult:
	if housing == null: return OperationResult.failure("no_housing")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return housing.place(tx, actor, id, property_id, cell_id))

func pack_furnishing(intent: String, actor: String, id: String) -> OperationResult:
	if housing == null: return OperationResult.failure("no_housing")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return housing.pack(tx, actor, id))

func engage_combat(intent: String, actor: String, threat_id: String) -> OperationResult:
	if combat == null: return OperationResult.failure("no_combat")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return combat.engage(tx, actor, threat_id))

func progress_combat(intent: String, actor: String, milliseconds: Variant) -> OperationResult:
	if combat == null: return OperationResult.failure("no_combat")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return combat.progress(tx, actor, milliseconds))

func strike_combat(intent: String, actor: String, target_id: String = "") -> OperationResult:
	if combat == null: return OperationResult.failure("no_combat")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return combat.strike(tx, actor, target_id))

func dodge_combat(intent: String, actor: String) -> OperationResult:
	if combat == null: return OperationResult.failure("no_combat")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return combat.dodge(tx, actor))

func block_combat(intent: String, actor: String) -> OperationResult:
	if combat == null: return OperationResult.failure("no_combat")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return combat.block(tx, actor))

func retreat_combat(intent: String, actor: String) -> OperationResult:
	if combat == null: return OperationResult.failure("no_combat")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return combat.retreat(tx, actor))

func recover_combat(intent: String, actor: String) -> OperationResult:
	if combat == null: return OperationResult.failure("no_combat")
	return session.transact(intent, func(tx: WorldTransaction) -> String: return combat.recover(tx, actor))
