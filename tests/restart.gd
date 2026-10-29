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
	print("RESTART %s %s" % [args[0], "FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)
