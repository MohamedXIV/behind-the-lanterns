extends SceneTree

var _checks: int = 0
var _failures: int = 0
var _Definition: Script
var _Session: Script
var _Fixture: Script

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# RED stays a real failed assertion when the implementation is absent.
	if not ResourceLoader.exists("res://game/foundation/game_session.gd"):
		check(false, "transactional session implementation required")
		_finish()
		return
	_Definition = load("res://game/foundation/world_definition.gd")
	_Session = load("res://game/foundation/game_session.gd")
	_Fixture = load("res://tests/fixtures/fixture_domain.gd")
	_test_identity_and_static_truth()
	_test_order_and_causality()
	_test_lazy_dependencies_at_due_time()
	_test_failed_request_is_atomic()
	_test_validation_and_idempotence()
	_test_event_budget()
	_test_isolation_and_reentrancy()
	_test_ignored_failure_cannot_publish()
	_test_session_lifetime()
	var persistence_tests: RefCounted = load("res://tests/test_persistence.gd").new()
	persistence_tests.run(self)
	var gameplay_tests: RefCounted = load("res://tests/test_gameplay.gd").new()
	gameplay_tests.run(self)
	var livelihood_tests: RefCounted = load("res://tests/test_livelihood.gd").new()
	livelihood_tests.run(self)
	load("res://tests/test_world_geometry.gd").new().run(self)
	load("res://tests/test_regions.gd").new().run(self)
	load("res://tests/test_narrative.gd").new().run(self)
	load("res://tests/test_living_world.gd").new().run(self)
	load("res://tests/test_fishing.gd").new().run(self)
	load("res://tests/test_farming.gd").new().run(self)
	load("res://tests/test_mobile_input.gd").new().run(self)
	load("res://tests/test_law.gd").new().run(self)
	load("res://tests/test_travel.gd").new().run(self)
	_finish()

func _finish() -> void:
	print("FOUNDATION %s: %d assertions, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)

func check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)

func content(suffix: String = "one") -> Dictionary:
	return {"regions": ["region." + suffix, "region.remote"],
		"definitions": ["definition.fixture"],
		"entities": {"a:fixture": {"definition_id": "definition.fixture", "region_id": "region." + suffix}},
		"facts": {"fact.passage": true}, "claims": ["claim.passage", "claim.false_rumor"]}

func session(suffix: String = "one", budget: int = 512):
	return _Session.create(_Definition.create(content(suffix)), [_Fixture.new("growth"), _Fixture.new("economy")], "world.test", budget)

func event(id: String, due: int, kind: String = "fixture.note") -> Dictionary:
	return {"id": id, "kind": kind, "target_id": "a:fixture", "due": due}

func enqueue(s, records: Array, command_id: String = "enqueue"):
	var outcome = s.transact(command_id, func(tx):
		for record in records:
			var error: String = tx.schedule(record)
			if not error.is_empty():
				return error
		return "")
	return outcome

func _test_identity_and_static_truth() -> void:
	var s = session()
	check(s != null, "valid composition creates a session")
	if s == null: return
	check(s.definition().fact("fact.passage"), "static fact exists without knowledge")
	check(s.snapshot().knowledge.is_empty(), "awareness starts independent")
	check(s.advance_to(7200).ok, "five-day skip")
	check(s.definition().fact("fact.passage"), "static fact needs no tick")
	check(s.transact("hear", func(tx): return tx.discover("claim.false_rumor", "heard")).ok, "false rumor can be heard")
	check(not s.definition().fact("claim.false_rumor"), "knowledge never creates objective truth")
	var created: Array[String] = []
	check(s.transact("spawn", func(tx):
		created.append(tx.create_entity("definition.fixture", "region.remote"))
		return "" if not created[0].is_empty() else "spawn_failed").ok, "runtime identity allocated")
	check(created == ["r:1"], "runtime sequence identity")
	check(s.transact("move", func(tx): return tx.move_entity("r:1", "region.one")).ok, "move preserves identity")
	check(s.snapshot().entities["r:1"].region_id == "region.one", "location is persistent data")
	check(not s.transact("invalid", func(tx): return tx.move_entity("r:1", "missing")).ok, "unknown region rejected")
	check(session("two") != null, "second authored fixture needs no runtime changes")
	var bad := content()
	bad.entities["r:1"] = bad.entities["a:fixture"]
	check(_Definition.create(bad) == null, "authored IDs cannot claim runtime namespace")

func _test_order_and_causality() -> void:
	var s = session()
	check(enqueue(s, [event("z", 10), event("a", 10), event("early", 2)]).ok, "enqueue out-of-order timestamps")
	check(s.advance_to(10).ok, "inclusive target boundary")
	check(s.snapshot().domains.economy.visits == [["early", 2], ["z", 10], ["a", 10]], "due then persisted FIFO, not dictionary/key order")
	var unchanged: Dictionary = s.snapshot()
	check(s.advance_to(10).ok and s.snapshot().domains == unchanged.domains, "same target never replays effects")
	check(not s.advance_to(9).ok, "clock cannot move backwards")
	check(not s.advance_to(2147483648).ok, "clock upper bound")
	var chain := event("chain", 12, "fixture.chain")
	chain.payload = {"remaining": 2}
	check(enqueue(s, [chain, event("peer", 12)], "more").ok, "same-time causal chain enqueue")
	check(s.advance_to(12).ok, "new same-time events drain")
	var events: Dictionary = s.snapshot().scheduler.events
	check(events["peer"].sequence < events["chain.next"].sequence, "child follows preexisting peer")
	check(events["chain.next.next"].status == "completed", "all causal children completed")
	check(s.snapshot().domains.economy.visits.slice(3) == [["chain", 12], ["peer", 12], ["chain.next", 12], ["chain.next.next", 12]], "observable causal order follows existing peers")

func _test_lazy_dependencies_at_due_time() -> void:
	var s = session()
	check(enqueue(s, [event("early_sale", 2880, "fixture.sell"), event("ripe_sale", 4320, "fixture.sell")]).ok, "schedule unloaded-region consequences")
	check(s.advance_to(3000).ok, "advance before maturity")
	check(s.snapshot().domains.economy.coins == 0, "earlier sale cannot see skip-end maturity")
	check(s.advance_to(7200).ok, "five days with no offscreen frames")
	check(s.snapshot().domains.economy.coins == 7 and s.snapshot().domains.growth.harvested, "lazy maturity and scheduled payout commit together")
	check(s.snapshot().minute == 7200, "clock reaches skip end after effects")
	check(s.advance_to(8000).ok and s.snapshot().domains.economy.coins == 7, "payout exactly once logically")

func _test_failed_request_is_atomic() -> void:
	var s = session()
	check(enqueue(s, [event("first", 10), event("fail", 20, "fixture.fail")]).ok, "failure fixture queued")
	var before: Dictionary = s.snapshot()
	var result = s.advance_to(30)
	check(not result.ok and result.event_id == "fail", "failure identifies blocking event")
	check(s.snapshot() == before, "clock, earlier event, domains, child event ALL roll back")
	check(s.transact("cancel", func(tx): return tx.cancel("fail")).ok, "explicit cancellation permits recovery")
	check(s.advance_to(30).ok, "retry after explicit repair")
	check(s.snapshot().domains.economy.visits == [["first", 10]], "rolled-back event commits once on retry")
	var before_travel: Dictionary = s.snapshot()
	check(not s.transact("travel", func(tx):
		var money: Dictionary = tx.read_domain("economy")
		money.coins = -1
		tx.write_domain("economy", money)
		return "", 100).ok, "domain validator rejects cross-system invalid transaction")
	check(s.snapshot() == before_travel, "invalid paid travel leaves time/payment unchanged")

func _test_validation_and_idempotence() -> void:
	var s = session()
	check(s.transact("pay", func(tx):
		var money: Dictionary = tx.read_domain("economy")
		money.coins += 3
		tx.write_domain("economy", money)
		return "").ok, "valid command")
	check(s.transact("pay", func(_tx): return "must_not_run").ok, "same committed intent is idempotent")
	check(s.snapshot().domains.economy.coins == 3, "intent receipt prevents duplicate balance")
	for malformed in [event("unknown", 5, "missing"), {"id":"no_target","kind":"fixture.note","due":5}, event("fraction", 5), event("past", -1)]:
		if malformed.id == "fraction": malformed.due = 0.5
		check(not enqueue(s, [malformed], "bad:" + malformed.id).ok, "invalid event rejected: " + malformed.id)
	var object_event := event("object", 5)
	object_event.payload = {"object": RefCounted.new()}
	check(not enqueue(s, [object_event], "object").ok, "runtime object cannot enter durable payload")
	check(enqueue(s, [event("unique", 5)], "unique").ok, "valid occurrence")
	check(s.advance_to(5).ok, "finish occurrence")
	check(not enqueue(s, [event("unique", 10)], "duplicate").ok, "terminal event identity cannot be reused")
	check(not s.transact("bad_result", func(_tx): return true).ok, "handler protocol fails closed on non-string return")

func _test_event_budget() -> void:
	var s = session("one", 3)
	var chain := event("storm", 1, "fixture.chain")
	chain.payload = {"remaining": 5}
	check(enqueue(s, [chain]).ok, "event storm fixture queued")
	var before: Dictionary = s.snapshot()
	check(s.advance_to(2).code == "event_budget_exceeded", "event storm bounded")
	check(s.snapshot() == before, "budget exhaustion rolls back all candidate events")

func _test_isolation_and_reentrancy() -> void:
	var one = session()
	var two = session()
	var retained: Array = []
	check(one.transact("retain", func(tx):
		retained.append(tx)
		check(not one.advance_to(1).ok, "reentrant advancement rejected")
		return "").ok, "outer isolated command can commit")
	var before: Dictionary = one.snapshot()
	retained[0].discover("claim.passage", "confirmed")
	check(one.snapshot() == before, "retained transaction cannot mutate published state")
	var copy: Dictionary = one.snapshot()
	copy.domains.economy.coins = 999
	check(one.snapshot() == before, "snapshot queries return copies")
	check(two.snapshot().revision == 0 and two.snapshot().knowledge.is_empty(), "sessions isolated")
	var nested: Array = []
	var callback := func(_revision): nested.append(one.advance_to(5).ok)
	one.committed.connect(callback)
	check(one.advance_to(1).ok and nested == [false], "notification cannot reenter session mutation")
	one.committed.disconnect(callback)

func _test_ignored_failure_cannot_publish() -> void:
	var s = session()
	var before: Dictionary = s.snapshot()
	var outcome = s.transact("ignored_failure", func(tx):
		var money: Dictionary = tx.read_domain("economy")
		money.coins = 25
		tx.write_domain("economy", money)
		tx.schedule(event("wrong", 5, "unknown")) # Deliberately ignored result.
		return "")
	check(not outcome.ok and s.snapshot() == before, "failed sub-operation poisons candidate even when caller ignores return")
	check(not s.transact("invalid_target_type", func(_tx): return "", "5").ok, "wrong target type rejected without script exception")
	check(s.transact("travel", func(tx):
		var money: Dictionary = tx.read_domain("economy")
		money.coins = 2
		tx.write_domain("economy", money)
		return tx.schedule(event("arrival", 100)), 100).ok, "command and scheduled arrival share one atomic time advance")
	check(s.snapshot().minute == 100 and s.snapshot().domains.economy.visits == [["arrival", 100]], "arrival committed at destination time")

func _test_session_lifetime() -> void:
	var s = session()
	if not s.has_method("close"):
		check(false, "closed sessions must reject stale-scene commands")
		return
	check(s.close(), "session closes outside transaction")
	check(not s.advance_to(1).ok, "old session cannot advance after disposal")
	check(not s.transact("stale", func(_tx): return "").ok, "old UI references cannot mutate closed session")
	if not ResourceLoader.exists("res://game/app/main.gd"):
		check(false, "composition root implementation required")
		return
	var app = load("res://game/app/main.gd").new()
	get_root().add_child(app)
	var first = session()
	var second = session()
	check(app.replace_session(first), "composition root accepts new session")
	check(not app.replace_session(null) and not first.is_closed(), "invalid replacement preserves current session")
	check(app.replace_session(second) and first.is_closed(), "replacement retires old session")
	app.free()
	check(second.is_closed(), "app teardown closes active session")
