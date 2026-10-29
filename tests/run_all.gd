extends SceneTree
## Run: godot --headless --path . --script res://tests/run_all.gd
## No city, NPC or production farming system is created by these tests.

const CropFixture = preload("res://tests/fixtures/crop_projection.gd")
var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _test_static_truth_independent_of_knowledge()
    _test_chronological_events_and_same_minute_order()
    _test_delayed_crop_without_ticks()
    _test_save_restore_no_duplicate_event()
    _test_reject_invalid_timeline()
    _test_session_isolation()
    if _failures == 0:
        print("FOUNDATION PASS: %d assertions" % _checks)
    else:
        printerr("FOUNDATION FAIL: %d of %d assertions" % [_failures, _checks])
    quit(0 if _failures == 0 else 1)

func _expect(condition: bool, description: String) -> void:
    _checks += 1
    if not condition:
        _failures += 1
        printerr("FAIL: " + description)

func _test_static_truth_independent_of_knowledge() -> void:
    var session := GameSession.new()
    _expect(session.world.set_fact("secret_entrance", true), "static fact exists")
    _expect(session.world.has_fact("secret_entrance"), "world contains secret before rumor")
    _expect(not session.knowledge.knows("secret_entrance"), "player knows nothing yet")
    _expect(session.advance_to(7200), "five-day time skip")
    _expect(session.world.has_fact("secret_entrance"), "time does not spawn or despawn static secret")
    session.knowledge.discover("secret_entrance")
    _expect(session.world.has_fact("secret_entrance"), "discovery does not change existence")

func _test_chronological_events_and_same_minute_order() -> void:
    var session := GameSession.new()
    var observed: Array[String] = []
    var handler := func(event: Dictionary) -> bool:
        observed.append("%d:%s" % [session.clock.current_minute(), event["id"]])
        return true
    _expect(session.register_event_handler("notice", handler), "register named event handler")
    _expect(session.schedule_event({"id":"b", "kind":"notice", "due_minute":600}), "schedule b")
    _expect(session.schedule_event({"id":"a", "kind":"notice", "due_minute":600}), "schedule a")
    _expect(session.schedule_event({"id":"earlier", "kind":"notice", "due_minute":200}), "schedule first event")
    _expect(session.advance_to(1200), "advance through multiple due events")
    _expect(observed == ["200:earlier", "600:a", "600:b"], "stable due-time and id ordering")
    _expect(session.clock.current_minute() == 1200, "clock ends at requested time")
    _expect(session.advance_to(1300) and observed.size() == 3, "completed events do not refire")

func _test_delayed_crop_without_ticks() -> void:
    var field := {
        "soil_compatible": true, "planted_at": 0, "growth_minutes": 4320,
        "required_waterings": 2, "watered_at": [1440, 2880]
    }
    _expect(not CropFixture.is_mature(field, 2880), "crop is unripe on day two")
    _expect(CropFixture.is_mature(field, 7200), "crop mature after five days without ticks")
    _expect(CropFixture.is_mature(field, 7200), "repeated projection does not change result")
    var incompatible := field.duplicate(true)
    incompatible["soil_compatible"] = false
    _expect(not CropFixture.is_mature(incompatible, 7200), "hard soil requirement preserved")

func _test_save_restore_no_duplicate_event() -> void:
    var original := GameSession.new()
    original.world.set_fact("secret_entrance", true)
    original.knowledge.discover("old_harbor_rumor")
    var first_hits := [0]
    var first_handler := func(_event: Dictionary) -> bool:
        first_hits[0] += 1
        return true
    original.register_event_handler("payment", first_handler)
    _expect(original.schedule_event({"id":"paid", "kind":"payment", "due_minute":100}), "schedule payment")
    _expect(original.schedule_event({"id":"later", "kind":"payment", "due_minute":200}), "schedule later payment")
    _expect(original.advance_to(150), "execute first payment")
    _expect(first_hits[0] == 1, "first payment exactly once")
    var encoded := SessionCodec.encode(original)
    _expect(not encoded.is_empty(), "snapshot JSON encoded")
    var restored := SessionCodec.decode(encoded)
    _expect(restored != null, "restore candidate session from JSON")
    if restored == null:
        return
    _expect(restored.world.has_fact("secret_entrance"), "world truth roundtrip")
    _expect(restored.knowledge.knows("old_harbor_rumor"), "knowledge roundtrip")
    var later_hits := [0]
    var second_handler := func(_event: Dictionary) -> bool:
        later_hits[0] += 1
        return true
    restored.register_event_handler("payment", second_handler)
    _expect(restored.advance_to(300), "advance restored session")
    _expect(later_hits[0] == 1, "only pending payment executes on restore")
    _expect(restored.scheduler.status("paid") == "completed", "prior event stays completed")
    _expect(restored.scheduler.status("later") == "completed", "later event becomes completed")

func _test_reject_invalid_timeline() -> void:
    var session := GameSession.new()
    _expect(not session.advance_to(-1), "reject negative world time")
    var faulty := SessionCodec.decode("{\"version\":999}")
    _expect(faulty == null, "reject unknown save version")
    _expect(session.schedule_event({"id":"bad_event","kind":"missing","due_minute":10}), "store unknown handler event")
    _expect(not session.advance_to(20), "no silent skip across missing domain handler")
    _expect(SessionCodec.encode(session).is_empty(), "cannot save after failed advance")

func _test_session_isolation() -> void:
    var one := GameSession.new()
    var two := GameSession.new()
    one.world.set_fact("other_region", true)
    _expect(not two.world.has_fact("other_region"), "sessions never share world state")
