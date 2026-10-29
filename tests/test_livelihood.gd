extends RefCounted
## Consolidated end-of-batch verification of the connected gameplay loop.

class InterruptedAdvance:
	extends SessionDomain
	func domain_id() -> String: return "interruption"
	func initial_state() -> Dictionary: return {}
	func validate(_state: Dictionary, _snapshot: Dictionary) -> String: return ""
	func event_kinds() -> Array[String]: return ["fixture.interrupt"]
	func validate_event(_event: Dictionary, _snapshot: Dictionary) -> String: return ""
	func handle_event(_event: Dictionary, _tx: WorldTransaction) -> String: return "interrupted"

var _data: Dictionary

func run(t) -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/connected_gameplay.json"))
	var game := _make()
	t.check(game != null, "connected content composes")
	if game == null: return
	_test_full_delivery(t)
	_test_reservations_and_active_craft(t)
	_test_ready_and_cancellation(t)
	_test_routines_and_deadlines(t)
	_test_failed_advance_and_money_bounds(t)
	_test_restore_validation(t)

func _make(data: Dictionary = {}) -> GameplayModel:
	return GameplayModel.create(_data if data.is_empty() else data, "world.connected-tests")

func _id(game: GameplayModel, prefix: String) -> String:
	return "%s:%d" % [prefix, game.session.snapshot().revision]

func _walk(game: GameplayModel, target: String) -> OperationResult:
	var at := game.position_of(target)
	return game.move_actor(_id(game, "walk"), "a:player", at.x, at.y)

func _take(game: GameplayModel, item: String, quantity: int) -> OperationResult:
	_walk(game, "a:supplies")
	return game.act(_id(game, "take"), "a:player", "a:supplies", item, quantity, "take")

func _count(game: GameplayModel, holder: String, item: String) -> int:
	return game.inventory.contents(game.session.snapshot(), holder).get(item, 0)

func _money(game: GameplayModel) -> int:
	var state: Dictionary = game.session.snapshot().domains.commerce
	var total: int = 0
	for amount in state.wallets.values(): total += amount
	for hold in state.holds.values(): total += hold.amount
	return total

func _accept(game: GameplayModel, offer: String) -> OperationResult:
	_walk(game, "a:merchant")
	return game.accept_job(_id(game, "accept"), "a:player", offer)

func _start(game: GameplayModel) -> OperationResult:
	_walk(game, "a:workbench")
	return game.start_craft(_id(game, "craft"), "a:player", "recipe.provisions", "a:workbench")

func _test_full_delivery(t) -> void:
	var game := _make()
	t.check(_take(game, "item.grain", 6).ok and _take(game, "item.dates", 1).ok, "gather actual ingredients and delivery goods")
	t.check(_accept(game, "work.provisions").ok and _accept(game, "work.grain").ok, "accept two optional jobs")
	t.check(game.wallet("a:merchant") == 62 and _money(game) == 90, "rewards held without creating currency")
	t.check(_start(game).ok, "start preparation at a valid bench")
	t.check(game.progress_craft("finish", "a:player", 3).ok, "active preparation completes")
	t.check(_count(game, "a:player", "item.grain") == 4 and _count(game, "a:player", "item.provisions") == 2, "exact recipe inputs consumed and outputs created")
	_walk(game, "a:courier")
	t.check(not game.deliver_job("too_early", "a:player", "work.provisions").ok, "off-duty recipient cannot accept delivery")
	t.check(game.wait_minutes("morning", "a:player", 60).ok, "wait advances existing world clock")
	_walk(game, "a:courier")
	t.check(game.deliver_job("deliver-provisions", "a:player", "work.provisions").ok, "deliver prepared goods to scheduled recipient")
	t.check(game.deliver_job("deliver-grain", "a:player", "work.grain").ok, "deliver ordinary goods through same ledger")
	t.check(game.wallet("a:player") == 28 and _money(game) == 90, "held rewards settle once with money conservation")
	t.check(_count(game, "a:courier", "item.provisions") == 2 and _count(game, "a:courier", "item.grain") == 4, "recipient has sole custody of delivered goods")
	var before := game.session.snapshot()
	t.check(game.deliver_job("deliver-provisions", "a:player", "work.provisions").ok and game.session.snapshot() == before, "retry same completion intent does not repay")
	t.check(not game.deliver_job("second_payment", "a:player", "work.provisions").ok, "new intent cannot claim completed work")
	t.check(not _accept(game, "work.provisions").ok, "one-shot offer cannot be farmed by accepting again")
	t.check(game.wait_minutes("next_day", "a:player", 1440).ok and game.wallet("a:player") == 28, "cancelled expiry descriptors never undo completion or repay")

func _test_reservations_and_active_craft(t) -> void:
	var game := _make()
	_take(game, "item.grain", 4)
	_take(game, "item.dates", 2)
	t.check(_start(game).ok, "craft reserves ingredients")
	var available := game.inventory.available_contents(game.session.snapshot(), "a:player")
	t.check(available["item.grain"] == 2 and available["item.dates"] == 1, "reserved inputs excluded from available goods")
	t.check(game.inventory.slots_used(game.inventory.contents(game.session.snapshot(), "a:player")) == 2, "reserved inputs continue occupying bag capacity")
	_walk(game, "a:merchant")
	var before := game.session.snapshot()
	t.check(not game.act("sell_reserved", "a:player", "a:merchant", "item.grain", 3, "sell", 1).ok and game.session.snapshot() == before, "trade cannot spend reserved inputs")
	t.check(not game.progress_craft("remote_work", "a:player", 1).ok, "leaving the station prevents active progress")
	t.check(game.wait_minutes("days_away", "a:player", 7200).ok, "five-day skip while a craft exists")
	var job := game.crafting.active_job(game.session.snapshot(), "a:player")
	t.check(job.elapsed == 0 and job.status == "working", "world-time skip never supplies active-play duration")
	_walk(game, "a:workbench")
	t.check(game.progress_craft("part", "a:player", 1.25).ok, "fractional active progress")
	var encoded := SessionCodec.encode(game.session)
	var restored := SessionCodec.decode(encoded, game.session)
	t.check(restored != null and restored.snapshot() == game.session.snapshot(), "in-progress craft, reservations and elapsed duration roundtrip")
	game.adopt(restored)
	t.check(game.progress_craft("rest", "a:player", 1.75).ok, "restored craft resumes remaining work")
	t.check(_count(game, "a:player", "item.provisions") == 2 and game.session.snapshot().domains.inventory.reservations.is_empty(), "completion releases reservation and creates output once")
	t.check(not game.progress_craft("again", "a:player", 3).ok and _count(game, "a:player", "item.provisions") == 2, "completed craft cannot rerun")
	for invalid in [0, -1, true, "3", INF, NAN]:
		t.check(not game.progress_craft("bad:%d" % t._checks, "a:player", invalid).ok, "invalid active duration rejected")

func _test_ready_and_cancellation(t) -> void:
	var game := _make()
	_take(game, "item.grain", 3)
	_take(game, "item.dates", 2)
	_take(game, "item.vessel", 1)
	_start(game)
	t.check(game.progress_craft("ready", "a:player", 3).ok, "full output capacity leaves completed preparation ready")
	var job := game.crafting.active_job(game.session.snapshot(), "a:player")
	t.check(job.status == "ready" and _count(game, "a:player", "item.provisions") == 0, "ready output is not a duplicate hidden inventory")
	t.check(_count(game, "a:player", "item.grain") == 3, "inputs remain physically held until successful transformation")
	var restored := SessionCodec.decode(SessionCodec.encode(game.session), game.session)
	t.check(restored != null and game.adopt(restored), "ready craft survives save/load")
	_walk(game, "a:chest")
	t.check(game.act("make_room", "a:player", "a:chest", "item.vessel", 1, "store").ok, "ordinary storage can make output space")
	_walk(game, "a:workbench")
	t.check(game.collect_craft("claim", "a:player").ok and _count(game, "a:player", "item.provisions") == 2, "collect ready output after freeing space")
	t.check(not game.collect_craft("reclaim", "a:player").ok, "output claim is single use")
	var cancel_game := _make()
	_take(cancel_game, "item.grain", 2)
	_take(cancel_game, "item.dates", 1)
	_start(cancel_game)
	_walk(cancel_game, "a:chest")
	t.check(cancel_game.cancel_craft("cancel", "a:player").ok, "player can cancel interrupted preparation")
	t.check(cancel_game.inventory.available_contents(cancel_game.session.snapshot(), "a:player") == {"item.grain": 2, "item.dates": 1}, "cancellation releases all ingredients without a capacity/refund hazard")
	t.check(_count(cancel_game, "a:player", "item.provisions") == 0, "cancelled craft grants no output")

func _test_routines_and_deadlines(t) -> void:
	var game := _make()
	t.check(game.session.now() == 480 and game.position_of("a:merchant") == Vector2(620, 160), "authored start time resolves morning routine")
	_accept(game, "work.provisions")
	t.check(game.cancel_job("abandon", "a:player", "work.provisions").ok and game.wallet("a:merchant") == 80, "job cancellation returns held payment")
	_accept(game, "work.grain")
	t.check(game.wait_minutes("expiry", "a:player", 180).ok, "deadline resolves at exact boundary")
	var expired := game.work.job_for(game.session.snapshot(), "a:player", "work.grain")
	t.check(expired.status == "expired" and expired.resolved_at == 660 and game.wallet("a:merchant") == 80, "expiry records timestamp and refunds reserved reward")
	t.check(game.wait_minutes("night", "a:player", 420).ok, "advance to evening boundary")
	t.check(game.position_of("a:merchant") == Vector2(700, 80) and not game.interactions.available("a:merchant", game.session.now()), "merchant moves and closes by schedule lookup")
	_walk(game, "a:merchant")
	t.check(not game.act("closed_shop", "a:player", "a:merchant", "item.dates", 1, "buy", 3).ok, "closed merchant cannot trade even at physical location")
	var data := _data.duplicate(true)
	data.work["work.grain"].deadline_minutes = 120
	data.work["work.provisions"].deadline_minutes = 120
	var simultaneous := _make(data)
	_accept(simultaneous, "work.provisions")
	_accept(simultaneous, "work.grain")
	t.check(simultaneous.wait_minutes("same_deadline", "a:player", 120).ok, "equal-deadline jobs resolve without transient validation deadlock")
	t.check(simultaneous.wallet("a:merchant") == 80 and simultaneous.session.snapshot().domains.commerce.holds.is_empty(), "all simultaneous refunds settle exactly once")
	for invalid in [0, -1, 0.5, true, "60", INF]:
		t.check(not game.wait_minutes("bad-wait:%d" % t._checks, "a:player", invalid).ok, "invalid time advancement rejected")

func _test_failed_advance_and_money_bounds(t) -> void:
	var game := _make()
	var expanded := GameSession.create(game.session.definition(), [game.inventory, game.commerce, game.interactions, game.crafting, game.work, InterruptedAdvance.new()], "world.connected-tests")
	game.session.close()
	game.session = expanded
	game.session.advance_to(480)
	_accept(game, "work.provisions")
	game.session.transact("interrupt", func(tx): return tx.schedule({"id":"interruption", "kind":"fixture.interrupt", "target_id":"a:player", "due":841}))
	var before := game.session.snapshot()
	var result := game.wait_minutes("failed_wait", "a:player", 361)
	t.check(not result.ok and result.code == "interrupted" and game.session.snapshot() == before, "failure after expiry rolls back clock, job outcome, refund and queue together")
	game.session.transact("repair", func(tx): return tx.cancel("interruption"))
	t.check(game.wait_minutes("retry_wait", "a:player", 361).ok and game.wallet("a:merchant") == 80, "explicit retry performs refund once")
	var data := _data.duplicate(true)
	data.economy.wallets["a:merchant"] = WorldData.MAX_COUNTER
	var rich := _make(data)
	_accept(rich, "work.provisions")
	before = rich.session.snapshot()
	t.check(not rich.act("overflow_income", "a:player", "a:merchant", "item.dates", 1, "buy", 3).ok and rich.session.snapshot() == before, "held refunds count toward payer's maximum balance")
	t.check(rich.wait_minutes("safe_refund", "a:player", 360).ok and rich.wallet("a:merchant") == WorldData.MAX_COUNTER, "expiry refund cannot overflow or block time")

func _test_restore_validation(t) -> void:
	var game := _make()
	_take(game, "item.grain", 2)
	_take(game, "item.dates", 1)
	_accept(game, "work.provisions")
	_start(game)
	var snapshot := game.session.snapshot()
	var work_id: String = snapshot.domains.work.jobs.keys()[0]
	var craft_id: String = snapshot.domains.crafting.jobs.keys()[0]
	var expiry := WorkRules.expiry_id(work_id)
	var mutations: Array[Callable] = [
		func(s): s.domains.inventory.reservations.erase(craft_id),
		func(s): s.domains.inventory.reservations[craft_id].goods["item.grain"] = 50,
		func(s): s.domains.commerce.holds.erase(work_id),
		func(s): s.domains.commerce.holds[work_id].amount = 1,
		func(s): s.domains.work.jobs[work_id].status = "completed",
		func(s): s.domains.work.jobs[work_id].deadline += 1,
		func(s): s.scheduler.events.erase(expiry),
		func(s): s.scheduler.events[expiry].status = "completed",
		func(s): s.scheduler.events[expiry].status = false,
		func(s): s.domains.commerce.holds[work_id].payer = false,
		func(s): s.domains.commerce.holds[work_id].owner_domain = null,
		func(s): s.domains.inventory.reservations[craft_id].owner_domain = false,
		func(s): s.domains.crafting.jobs[craft_id].elapsed = 30,
		func(s): s.domains.crafting.jobs[craft_id].status = "cancelled",
		func(s): s.domains.crafting.jobs[craft_id].recipe_id = "unknown",
	]
	for mutation in mutations:
		var bad := snapshot.duplicate(true)
		mutation.call(bad)
		t.check(game.session.restore_candidate(bad) == null, "inconsistent cross-domain save rejected")
	for domain in ["work", "crafting"]:
		var record_id: String = work_id if domain == "work" else craft_id
		for field in snapshot.domains[domain].jobs[record_id]:
			var bad := snapshot.duplicate(true)
			bad.domains[domain].jobs[record_id][field] = null
			t.check(game.session.restore_candidate(bad) == null, "invalid job field rejected without script errors")
	t.check(game.session.snapshot() == snapshot, "failed restores leave live reservations and work intact")
