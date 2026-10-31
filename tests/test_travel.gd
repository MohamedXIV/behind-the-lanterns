extends RefCounted

func data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))

func model(world_id: String = "world.travel-test") -> GameplayModel:
	return GameplayModel.create(data(), world_id)

func run(t) -> void:
	_test_ship_deadline_inventory_and_return(t)
	_test_caravan_and_offscreen_growth(t)
	_test_refusals_are_atomic(t)
	_test_law_refusals(t)
	_test_event_failure_rolls_back_journey(t)
	_test_clock_limit_receipt(t)
	_test_validation(t)

func _test_ship_deadline_inventory_and_return(t) -> void:
	var m := model()
	t.check(m != null and m.travel != null and m.travel.route_ids(m.session.snapshot(), "a:player").size() == 2, "travel domain composes two public departure modes")
	if m == null: return
	t.check(m.act("dates", "a:player", "a:supplies", "item.dates", 2, "take").ok, "goods collected before public voyage")
	t.check(m.move_actor("merchant", "a:player", 620, 160).ok and m.accept_job("deadline-job", "a:player", "work.grain").ok, "deadline commitment accepted before departure")
	t.check(m.move_actor("boatman", "a:player", 640, 80).ok, "public boatman approached")
	var result := m.take_route("ship-out", "a:player", "route.ship_estuary")
	t.check(result.ok, "paid ship route commits")
	t.check(m.session.now() == 720 and m.actor_region("a:player") == "region.estuary" and m.position_of("a:player") == Vector2(300, 200), "ship advances world time and arrives at authored regional destination")
	t.check(m.wallet("a:player") == 6 and m.wallet("a:boatman") == 4, "fare transfers exactly once to finite carrier wallet")
	t.check(m.inventory.contents(m.session.snapshot(), "a:player").get("item.dates", 0) == 2, "inventory custody travels with actor")
	var job := m.work.job_for(m.session.snapshot(), "a:player", "work.grain")
	t.check(job.status == "expired" and job.resolved_at == 660, "intervening work deadline resolves chronologically before arrival")
	var journeys := m.travel.journeys_for(m.session.snapshot(), "a:player")
	t.check(journeys.size() == 1 and journeys[0].route_id == "route.ship_estuary" and journeys[0].departed_at == 480 and journeys[0].arrival_minute == 720, "persistent concise journey record stores route and world-time anchors")
	var event_id := TravelRules.arrival_event_id(journeys[0].id)
	t.check(m.session.snapshot().scheduler.events[event_id].status == "completed", "stable arrival occurrence completes once")
	var settled := m.session.snapshot()
	t.check(m.take_route("ship-out", "a:player", "route.ship_estuary").ok and m.session.snapshot() == settled, "reused journey intent cannot charge or arrive twice")
	var decoded := SessionCodec.decode(SessionCodec.encode(m.session), m.session)
	t.check(decoded != null and decoded.snapshot() == settled, "travel log, arrival receipt and remote region roundtrip through codec")
	if decoded != null: decoded.close()
	t.check(m.move_actor("return-boatman", "a:player", 360, 200).ok and m.take_route("ship-back", "a:player", "route.ship_return").ok, "scheduled return carrier supports bidirectional public travel")
	t.check(m.session.now() == 960 and m.actor_region("a:player") == "region.playground" and m.wallet("a:player") == 2 and m.wallet("a:estuary-boatman") == 4, "return voyage pays its own carrier and restores origin region")
	t.check(m.travel.journeys_for(m.session.snapshot(), "a:player")[0].route_id == "route.ship_return", "travel log presents newest journey first")
	m.session.close()

func _test_caravan_and_offscreen_growth(t) -> void:
	var m := model("world.travel-caravan")
	t.check(m.act("grain", "a:player", "a:supplies", "item.grain", 2, "take").ok, "seed gathered before caravan journey")
	t.check(m.move_actor("garden", "a:player", 240, 60).ok and m.plant_crop("plant", "a:player", "a:garden-plot", "crop.grain").ok and m.water_crop("water", "a:player", "a:garden-plot").ok, "crop planted and watered before leaving region")
	t.check(m.move_actor("leader", "a:player", 620, 300).ok and m.take_route("caravan-out", "a:player", "route.caravan_waystation").ok, "paid caravan route commits")
	t.check(m.session.now() == 780 and m.actor_region("a:player") == "region.remote" and m.wallet("a:caravan-leader") == 3, "caravan reaches land route destination and pays leader")
	var away_projection := m.farming.projection(m.session.snapshot(), "a:garden-plot")
	t.check(away_projection.elapsed_minutes == 300 and away_projection.stage == "needs_water" and not away_projection.ripe, "offscreen crop derives growth from journey time without scene ticks")
	t.check(m.move_actor("return-leader", "a:player", 360, 220).ok and m.take_route("caravan-back", "a:player", "route.caravan_return").ok, "return caravan commits")
	t.check(m.session.now() == 1080 and m.actor_region("a:player") == "region.playground" and m.wallet("a:player") == 4, "round-trip caravan advances time and fares once per direction")
	t.check(m.move_actor("garden-return", "a:player", 240, 60).ok and m.water_crop("water-return", "a:player", "a:garden-plot").ok and m.farming.projection(m.session.snapshot(), "a:garden-plot").ripe, "returning player can complete crop care after offscreen travel time")
	m.session.close()

func _test_refusals_are_atomic(t) -> void:
	var m := model("world.travel-refusals")
	var before := m.session.snapshot()
	t.check(m.take_route("missing", "a:player", "route.missing").code == "unknown_route" and m.session.snapshot() == before, "unknown route rejected without mutation")
	t.check(m.take_route("far", "a:player", "route.ship_estuary").code == "out_of_reach" and m.session.snapshot() == before, "remote boarding rejected without fare or time")
	t.check(m.move_actor("boatman", "a:player", 640, 80).ok and m.wait_minutes("until-moored", "a:player", 540).ok, "wait until packet carrier is off duty")
	before = m.session.snapshot()
	t.check(m.take_route("unavailable", "a:player", "route.ship_estuary").code == "person_unavailable" and m.session.snapshot() == before, "scheduled carrier refusal preserves time, wallet and region")
	m.session.close()
	var poor_data := data()
	poor_data.economy.wallets["a:player"] = 0
	var poor := GameplayModel.create(poor_data, "world.travel-poor")
	t.check(poor.move_actor("boatman", "a:player", 640, 80).ok, "penniless passenger approaches carrier")
	before = poor.session.snapshot()
	t.check(poor.take_route("fare", "a:player", "route.ship_estuary").code == "insufficient_funds" and poor.session.snapshot() == before, "insufficient fare leaves full snapshot unchanged")
	poor.session.close()

func _test_law_refusals(t) -> void:
	var m := model("world.travel-law")
	t.check(m.move_actor("private", "a:player", 360, 310).ok and m.tamper_restricted("tamper", "a:player", "a:private").ok, "witnessed pursuit starts before boarding")
	t.check(m.move_actor("boatman", "a:player", 640, 80).ok, "pursued actor approaches packet")
	var before := m.session.snapshot()
	t.check(m.take_route("pursued", "a:player", "route.ship_estuary").code == "carrier_refuses_pursuit" and m.session.snapshot() == before, "public carrier refuses active pursuit without changing local evasion rules")
	m.session.close()
	m = model("world.travel-detained")
	t.check(m.move_actor("guard", "a:player", 480, 340).ok and m.confront_guard("arrest", "a:player", "a:gate-guard").ok, "scripted arrest before travel attempt")
	before = m.session.snapshot()
	t.check(m.take_route("detained", "a:player", "route.ship_estuary").code == "actor_detained" and m.session.snapshot() == before, "detained actor cannot bypass watchhouse through public arrival command")
	m.session.close()

func _test_event_failure_rolls_back_journey(t) -> void:
	var m := model("world.travel-budget")
	var domains: Array = [m.inventory, m.commerce, m.interactions, m.crafting, m.work, m.narrative, m.fishing, m.farming, m.law, m.travel, m.housing]
	var limited := GameSession.create(m.session.definition(), domains, "world.travel-budget", 1)
	t.check(limited != null and limited.advance_to(480).ok and m.adopt(limited), "one-event budget session composed for rollback proof")
	t.check(m.move_actor("merchant", "a:player", 620, 160).ok and m.accept_job("job", "a:player", "work.grain").ok and m.move_actor("boatman", "a:player", 640, 80).ok, "deadline and boarding prepared for bounded event failure")
	var before := m.session.snapshot()
	var result := m.take_route("budget-ship", "a:player", "route.ship_estuary")
	t.check(not result.ok and result.code == "event_budget_exceeded" and result.event_id == TravelRules.arrival_event_id(TravelRules.journey_id("budget-ship")), "arrival event exhaustion identifies blocking occurrence")
	t.check(m.session.snapshot() == before, "failed arrival rolls back fare, deadline processing, clock, log and region together")
	m.session.close()

func _test_clock_limit_receipt(t) -> void:
	var limit_data := data()
	limit_data.start_minute = WorldData.MAX_COUNTER - 240
	limit_data.npcs.erase("a:boatman")
	var m := GameplayModel.create(limit_data, "world.travel-clock-limit")
	t.check(m.move_actor("boatman", "a:player", 640, 80).ok and m.take_route("last-voyage", "a:player", "route.ship_estuary").ok, "journey can arrive exactly at world-clock limit")
	var before := m.session.snapshot()
	var replay := m.take_route("last-voyage", "a:player", "route.ship_estuary")
	t.check(m.session.now() == WorldData.MAX_COUNTER and replay.ok and replay.code == "already_applied" and m.session.snapshot() == before, "clock-limit receipt replay remains idempotent instead of overflowing")
	m.session.close()

func _test_validation(t) -> void:
	var m := model("world.travel-validation")
	t.check(m.move_actor("boatman", "a:player", 640, 80).ok and m.take_route("ship", "a:player", "route.ship_estuary").ok, "completed journey prepared for restore validation")
	var valid := m.session.snapshot()
	var record: Dictionary = m.travel.journeys_for(valid, "a:player")[0]
	var mutations: Array = [
		func(s): s.domains.travel.journeys[record.id].route_id = "route.missing",
		func(s): s.domains.travel.journeys[record.id].arrival_minute += 1,
		func(s): s.domains.travel.journeys[record.id].event_id = "travel.missing",
		func(s): s.scheduler.events.erase(record.event_id),
		func(s): s.domains.travel.active["a:player"] = s.domains.travel.journeys[record.id].duplicate(true),
		func(s): s.domains.travel.journeys.erase(record.id),
		func(s): s.domains.travel.journeys[record.id] = 1,
	]
	for mutation in mutations:
		var bad := valid.duplicate(true)
		mutation.call(bad)
		t.check(m.session.restore_candidate(bad) == null, "malformed travel state or arrival receipt rejected")
	var bad_config := data()
	bad_config.travel.routes["route.ship_estuary"].destination_region = "region.missing"
	t.check(GameplayModel.create(bad_config, "world.bad-travel") == null, "route definitions require authored destination regions")
	m.session.close()
