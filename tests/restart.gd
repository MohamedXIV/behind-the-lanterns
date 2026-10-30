extends SceneTree
## Invoked in two separate Godot processes by tools/test-headless.sh.

const Fixture = preload("res://tests/fixtures/fixture_domain.gd")
var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr("FAIL: restart " + message)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0] in ["write", "read"]:
		expect(false, "expected write/read and an owned test directory")
		quit(1)
		return
	var definition := WorldDefinition.create({"regions": ["region.fixture"],
		"definitions": ["definition.fixture"], "claims": ["claim.fixture"],
		"facts": {"fact.fixture": true},
		"entities": {"a:fixture": {"definition_id": "definition.fixture", "region_id": "region.fixture"}}})
	var composition := GameSession.create(definition, [Fixture.new("growth"), Fixture.new("economy")], "world.restart")
	var store := RecoveryStore.new(args[1])
	if args[0] == "write":
		expect(composition.transact("setup", func(tx):
			tx.create_entity("definition.fixture", "region.fixture")
			tx.discover("claim.fixture", "confirmed")
			for data in [{"id": "first", "due": 10}, {"id": "later", "due": 20}]:
				data.kind = "fixture.note"
				data.target_id = "a:fixture"
				tx.schedule(data)
			return "").ok, "initial commit")
		expect(composition.advance_to(15).ok, "first event committed")
		expect(store.save(composition).ok, "disk save")
	else:
		var restored := store.load_candidate(composition)
		expect(restored != null, "fresh process loads candidate")
		if restored != null:
			expect(restored.now() == 15 and restored.snapshot().knowledge["claim.fixture"] == "confirmed", "clock and awareness restored")
			expect(restored.transact("setup", func(_tx): return "must_not_run").ok, "intent receipt survives process restart")
			expect(restored.transact("spawn_again", func(tx):
				return "" if tx.create_entity("definition.fixture", "region.fixture") == "r:2" else "allocator_reset").ok, "allocator survives process restart")
			expect(restored.advance_to(25).ok, "pending event executes after restart")
			expect(restored.snapshot().domains.economy.visits == [["first", 10], ["later", 20]], "completed event never replayed")
		for name in RecoveryStore.SLOT_NAMES:
			DirAccess.remove_absolute(args[1].path_join(name))
		DirAccess.remove_absolute(args[1])
	_gameplay_restart(args[0], args[1] + "-gameplay")
	_connected_restart(args[0], args[1] + "-connected")
	_region_restart(args[0], args[1] + "-regions")
	_narrative_restart(args[0], args[1] + "-narrative")
	_fishing_restart(args[0], args[1] + "-fishing")
	_farming_restart(args[0], args[1] + "-farming")
	_web_ack_restart(args[0], args[1] + "-web-ack")
	print("RESTART %s %s" % [args[0], "FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)

func _gameplay_restart(mode: String, directory: String) -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/first_gameplay.json"))
	var game := GameplayModel.create(content, "world.gameplay-restart")
	var store := RecoveryStore.new(directory)
	if mode == "write":
		expect(game.act("collect", "a:player", "a:supplies", "item.dates", 5, "take").ok, "collect before restart")
		expect(game.move_actor("chest_walk", "a:player", 360, 160).ok, "walk to chest")
		expect(game.act("store", "a:player", "a:chest", "item.dates", 2, "store").ok, "store before restart")
		expect(game.move_actor("shop_walk", "a:player", 620, 160).ok, "walk to merchant")
		expect(game.act("sell", "a:player", "a:merchant", "item.dates", 1, "sell", 2).ok, "trade before restart")
		expect(store.save(game.session).ok, "save actual gameplay state")
	else:
		expect(game.adopt(store.load_candidate(game.session)), "load gameplay in fresh process")
		var before := game.session.snapshot()
		expect(game.inventory.contents(before, "a:supplies")["item.dates"] == 7, "finite source depletion survives restart")
		expect(game.inventory.contents(before, "a:player")["item.dates"] == 2 and game.inventory.contents(before, "a:chest")["item.dates"] == 2, "custody survives restart")
		expect(game.wallet("a:player") == 12 and game.position_of("a:player") == Vector2(620, 160), "money and position survive restart")
		expect(game.act("sell", "a:player", "a:merchant", "item.dates", 1, "sell", 2).ok and game.session.snapshot() == before, "loaded sale intent cannot pay twice")
		for name in RecoveryStore.SLOT_NAMES: DirAccess.remove_absolute(directory.path_join(name))
		DirAccess.remove_absolute(directory)
	print("GAMEPLAY RESTART %s %s" % [mode, "FAIL" if _failed else "PASS"])

func _connected_restart(mode: String, directory: String) -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/connected_gameplay.json"))
	var game := GameplayModel.create(content, "world.connected-restart")
	var store := RecoveryStore.new(directory)
	if mode == "write":
		expect(game.act("grain", "a:player", "a:supplies", "item.grain", 2, "take").ok, "collect craft grain")
		expect(game.act("dates", "a:player", "a:supplies", "item.dates", 1, "take").ok, "collect craft dates")
		game.move_actor("giver", "a:player", 620, 160)
		expect(game.accept_job("job", "a:player", "work.provisions").ok, "reserve reward before restart")
		game.move_actor("bench", "a:player", 220, 320)
		expect(game.start_craft("craft", "a:player", "recipe.provisions", "a:workbench").ok, "reserve craft inputs before restart")
		expect(game.progress_craft("progress", "a:player", 1).ok and store.save(game.session).ok, "save incomplete preparation and accepted job together")
	else:
		expect(game.adopt(store.load_candidate(game.session)), "load connected state in a new process")
		expect(game.session.now() == 480 and game.crafting.active_job(game.session.snapshot(), "a:player").elapsed == 1, "no offline world/active time added")
		expect(game.wallet("a:merchant") == 68 and game.inventory.available_contents(game.session.snapshot(), "a:player").is_empty(), "reward and ingredient reservations survive restart")
		expect(game.progress_craft("finish", "a:player", 2).ok, "resume remaining active seconds after restart")
		game.wait_minutes("wait", "a:player", 60)
		game.move_actor("recipient", "a:player", 600, 320)
		expect(game.deliver_job("deliver", "a:player", "work.provisions").ok and game.wallet("a:player") == 22, "deliver and settle held reward after restart")
		expect(store.save(game.session).ok and game.adopt(store.load_candidate(game.session)), "completed connected result roundtrips")
		var before := game.session.snapshot()
		expect(game.deliver_job("deliver", "a:player", "work.provisions").ok and game.session.snapshot() == before, "persisted delivery receipt prevents duplicate payout")
		for name in RecoveryStore.SLOT_NAMES: DirAccess.remove_absolute(directory.path_join(name))
		DirAccess.remove_absolute(directory)
	print("CONNECTED RESTART %s %s" % [mode, "FAIL" if _failed else "PASS"])

func _region_restart(mode: String, directory: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))
	var game := GameplayModel.create(data, "world.region-restart")
	var store := RecoveryStore.new(directory)
	if mode == "write":
		expect(game.act("take", "a:player", "a:supplies", "item.dates", 2, "take").ok, "collect for interior")
		expect(game.move_actor("door", "a:player", 100, 300).ok and game.enter("enter", "a:player", "a:workshop-door").ok, "enter before restart")
		expect(game.move_actor("chest", "a:player", 140, 220).ok and game.act("store", "a:player", "a:indoor-chest", "item.dates", 1, "store").ok, "store inside before restart")
		expect(store.save(game.session).ok, "save interior")
	else:
		expect(game.adopt(store.load_candidate(game.session)), "restore interior process")
		expect(game.actor_region("a:player") == "region.workshop" and game.position_of("a:player") == Vector2(140, 220), "region and position survive restart")
		expect(game.inventory.contents(game.session.snapshot(), "a:indoor-chest").get("item.dates", 0) == 1, "interior goods survive restart")
		expect(game.move_actor("exit-walk", "a:player", 100, 300).ok and game.enter("exit", "a:player", "a:workshop-exit").ok, "exit after restart")
		for name in RecoveryStore.SLOT_NAMES: DirAccess.remove_absolute(directory.path_join(name))
		DirAccess.remove_absolute(directory)
	game.session.close()
	print("REGION RESTART " + mode + " checked")

func _narrative_restart(mode: String, directory: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))
	var m := GameplayModel.create(data, "world.narrative-restart")
	var store := RecoveryStore.new(directory)
	if mode == "write":
		expect(m.move_actor("shop", "a:player", 620, 160).ok and m.talk("open", "a:player", "a:merchant").ok and m.talk("rumor", "a:player", "a:merchant", 0, 1).ok, "rumor before process restart")
		var fixture: RefCounted = load("res://tests/test_narrative.gd").new()
		expect(fixture._discover(m, "restart-discover") and fixture._return(m, "restart-return"), "physical evidence before report save")
		expect(m.talk("restart-report-open", "a:player", "a:merchant").ok, "open report before save")
		expect(m.talk("restart-report", "a:player", "a:merchant", fixture._choice(m, "Report the dry"), 1).ok, "report evidence before restart")
		expect(m.accept_job("restart-commit", "a:player", "work.provisions").ok and m.cancel_job("restart-cancel", "a:player", "work.provisions").ok, "broken commitment before restart")
		expect(m.talk("restart-ack-open", "a:player", "a:merchant").ok and m.talk("restart-ack", "a:player", "a:merchant", fixture._choice(m, "Acknowledge"), 1).ok, "acknowledge before restart")
		expect(store.save(m.session).ok, "save pending Ink choice")
	else:
		expect(m.adopt(store.load_candidate(m.session)), "restore real Ink conversation process")
		expect(m.session.snapshot().knowledge.get("claim.water") == "heard", "rumor certainty survives restart")
		var record := m.narrative.conversation(m.session.snapshot(), "a:player")
		expect(m.session.snapshot().domains.narrative.acknowledgements["a:player"]["work.provisions"].has("a:merchant"), "acknowledgement survives fresh process")
		expect(record.turns.size() == 2 and record.frame.choices.size() == 1, "same pending choice after restart")
		expect(m.session.snapshot().domains.narrative.reports["a:player"].get("claim.dry_basin") == "a:merchant", "evidence report survives fresh process")
		expect(m.talk("finish", "a:player", "a:merchant", 0, 2).ok, "continue saved Ink cursor")
		expect(m.narrative.conversation(m.session.snapshot(), "a:player").frame.ended, "conversation ends normally")
		for name in RecoveryStore.SLOT_NAMES: DirAccess.remove_absolute(directory.path_join(name))
		DirAccess.remove_absolute(directory)
	m.session.close()
	print("NARRATIVE RESTART " + mode + " checked")

func _fishing_restart(mode: String, directory: String) -> void:
	var fixture: RefCounted = load("res://tests/test_fishing.gd").new()
	var m: GameplayModel = fixture.model()
	var store := RecoveryStore.new(directory)
	if mode == "write":
		expect(m.act("bait", "a:player", "a:supplies", "item.grain", 2, "take").ok and fixture.river(m) and m.cast_line("cast", "a:player", "a:reed-bank", "item.grain").ok and m.progress_fishing("partial", "a:player", 1000).ok, "fishing opportunity before restart")
		expect(store.save(m.session).ok, "save active fishing")
	else:
		expect(m.adopt(store.load_candidate(m.session)), "restore fishing process")
		var fish: String = m.fishing.attempt(m.session.snapshot(), "a:player").fish
		expect(m.fishing.attempt(m.session.snapshot(), "a:player").elapsed_ms == 1000, "active timing survives restart")
		expect(m.progress_fishing("bite", "a:player", 1000).ok and m.reel_line("catch", "a:player").ok and m.inventory.contents(m.session.snapshot(), "a:player").get(fish, 0) == 1, "same saved species caught after restart")
		for name in RecoveryStore.SLOT_NAMES: DirAccess.remove_absolute(directory.path_join(name))
		DirAccess.remove_absolute(directory)
	m.session.close()
	print("FISHING RESTART " + mode + " checked")

func _farming_restart(mode: String, directory: String) -> void:
	var fixture: RefCounted = load("res://tests/test_farming.gd").new()
	var m: GameplayModel = fixture.model()
	var store := RecoveryStore.new(directory)
	if mode == "write":
		expect(m.act("lotus-seed", "a:player", "a:supplies", "item.lotus_seed", 1, "take").ok and fixture.river_bed(m) and m.plant_crop("plant", "a:player", "a:river-bed", "crop.lotus").ok and m.water_crop("water", "a:player", "a:river-bed").ok and fixture.leave_river(m), "plant and water river lotus before restart")
		expect(store.save(m.session).ok, "save planted offscreen crop")
	else:
		expect(m.adopt(store.load_candidate(m.session)), "restore farming process")
		expect(m.session.now() == 480 and m.farming.projection(m.session.snapshot(), "a:river-bed").elapsed_minutes == 0, "restart adds no real-world offline crop time")
		expect(m.wait_minutes("five-days", "a:player", 7200).ok and fixture.river_bed(m, "return"), "advance five world days after restart and return")
		expect(m.farming.projection(m.session.snapshot(), "a:river-bed").ripe and m.harvest_crop("harvest", "a:player", "a:river-bed").ok and m.inventory.contents(m.session.snapshot(), "a:player").get("item.river_lotus", 0) == 2, "offscreen crop reconciles and harvests once after restart")
		for name in RecoveryStore.SLOT_NAMES: DirAccess.remove_absolute(directory.path_join(name))
		DirAccess.remove_absolute(directory)
	m.session.close()
	print("FARMING RESTART " + mode + " checked")

func _web_ack_restart(mode: String, directory: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))
	var m := GameplayModel.create(data, "world.web-ack-restart")
	var web_ack := WebSaveAck.new()
	web_ack.configure_simulated_web(true)
	var store := RecoveryStore.new(directory, web_ack)
	if mode == "write":
		expect(m.act("take-dates", "a:player", "a:supplies", "item.dates", 3, "take").ok and m.move_actor("walk-east", "a:player", 360, 160).ok, "gameplay mutation before Web-acknowledged save")
		expect(store.save(m.session).ok and web_ack.last_state() == "confirmed", "Web-acknowledged save commits generation 1")
	else:
		expect(m.adopt(store.load_candidate(m.session)), "fresh process restores Web-acknowledged save")
		expect(m.inventory.contents(m.session.snapshot(), "a:player").get("item.dates", 0) == 3 and m.position_of("a:player") == Vector2(360, 160), "custody and position restored across simulated browser reload")
		for name in RecoveryStore.SLOT_NAMES: DirAccess.remove_absolute(directory.path_join(name))
		DirAccess.remove_absolute(directory)
	m.session.close()
	print("WEB ACK RESTART " + mode + " checked")
