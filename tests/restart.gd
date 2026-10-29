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
