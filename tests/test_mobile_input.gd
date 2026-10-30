extends RefCounted
## Acceptance tests for Issue #6 (Mobile-First Player Interaction) and Issue #2 (Web persistence sync/ack).

func run(t) -> void:
	_test_semantic_actions_and_remapping(t)
	_test_touch_movement_and_running(t)
	_test_ergonomics_and_safe_area(t)
	_test_web_persistence_ack(t)

func _test_semantic_actions_and_remapping(t) -> void:
	var input := PlayerInput.new()
	for action in PlayerInput.ALL_ACTIONS:
		t.check(InputMap.has_action(action), "InputMap registers semantic action " + action)
	t.check(input.bound_keys(PlayerInput.INTERACT) == [KEY_E, KEY_SPACE], "default interact key bindings")
	t.check(input.bound_keys(PlayerInput.DODGE) == [KEY_Q], "default evade/dodge action binding")
	var e_event := InputEventKey.new()
	e_event.pressed = true
	e_event.physical_keycode = KEY_E
	t.check(input.matches_event(PlayerInput.INTERACT, e_event), "matches default E interact event")
	t.check(not input.remap_key("unknown.action", KEY_J).ok, "unknown action rejected on remap")
	t.check(not input.remap_key(PlayerInput.INTERACT, 0).ok, "invalid keycode rejected on remap")
	t.check(input.remap_key(PlayerInput.INTERACT, KEY_J).ok, "remap interact to J succeeds")
	t.check(input.bound_keys(PlayerInput.INTERACT) == [KEY_J], "bound_keys reflects remapped key")
	t.check(not input.matches_event(PlayerInput.INTERACT, e_event), "old E key no longer matches remapped interact")
	var j_event := InputEventKey.new()
	j_event.pressed = true
	j_event.physical_keycode = KEY_J
	t.check(input.matches_event(PlayerInput.INTERACT, j_event), "remapped J key matches interact")
	input.reset_default_bindings()
	t.check(input.matches_event(PlayerInput.INTERACT, e_event), "reset_default_bindings restores default E key")

func _test_touch_movement_and_running(t) -> void:
	var input := PlayerInput.new()
	t.check(input.movement_vector(false) == Vector2.ZERO, "idle touch movement is zero")
	t.check(not input.set_touch_button("diagonal", true).ok, "unknown touch direction rejected")
	t.check(input.set_touch_button("right", true).ok and input.movement_vector(false) == Vector2.RIGHT, "touch right button produces unit right vector")
	t.check(input.set_touch_button("down", true).ok and is_equal_approx(input.movement_vector(false).length(), 1.0), "diagonal touch buttons normalize to unit vector")
	t.check(input.speed_multiplier(false) == PlayerInput.WALK_SPEED_MULTIPLIER, "default pace is walk speed")
	input.set_run_latched(true)
	t.check(input.is_running(false) and input.speed_multiplier(false) == PlayerInput.RUN_SPEED_MULTIPLIER, "latched run increases speed multiplier")
	input.set_touch_vector(Vector2(-3.0, 0.0))
	input.set_touch_button("right", false)
	input.set_touch_button("down", false)
	t.check(input.movement_vector(false) == Vector2.LEFT, "analog touch vector clamps to unit length")
	t.check(not input.trigger_action("invalid.intent").ok, "unknown action trigger rejected")
	for action in [PlayerInput.INTERACT, PlayerInput.TALK, PlayerInput.DODGE, PlayerInput.BLOCK, PlayerInput.PRIMARY_ACTION]:
		t.check(input.trigger_action(action).ok, "trigger semantic action " + action)
		t.check(input.consume_action(action) and not input.consume_action(action), "action intent consumed exactly once: " + action)
	input.set_touch_button("left", true)
	input.trigger_action(PlayerInput.INTERACT)
	input.release_all()
	t.check(input.movement_vector(false) == Vector2.ZERO and not input.consume_action(PlayerInput.INTERACT), "release_all clears held touch directions and pending intents")

func _test_ergonomics_and_safe_area(t) -> void:
	var input := PlayerInput.new()
	t.check(input.is_touch_visible() and input.touch_visibility() == PlayerInput.VISIBILITY_AUTO, "touch controls visible by default")
	t.check(not input.set_touch_visibility("invalid").ok, "invalid visibility mode rejected")
	t.check(input.set_touch_visibility(PlayerInput.VISIBILITY_HIDDEN).ok and not input.is_touch_visible(), "hidden visibility mode hides touch controls")
	t.check(input.set_touch_visibility(PlayerInput.VISIBILITY_SHOWN).ok and input.is_touch_visible(), "shown visibility mode restores touch controls")
	t.check(input.handedness() == PlayerInput.HANDEDNESS_STANDARD, "standard handedness by default")
	t.check(not input.set_handedness("upside_down").ok, "invalid handedness rejected")
	t.check(input.set_handedness(PlayerInput.HANDEDNESS_SWAPPED).ok and input.handedness() == PlayerInput.HANDEDNESS_SWAPPED, "swapped handedness updates layout preference")
	var desktop_margins := PlayerInput.compute_safe_margins(Vector2i(1120, 720), Rect2i(), 16)
	t.check(desktop_margins.left == 16 and desktop_margins.right == 16 and desktop_margins.top == 16 and desktop_margins.bottom == 16 and not desktop_margins.compact, "standard 1120x720 landscape uses base margins")
	var notched_margins := PlayerInput.compute_safe_margins(Vector2i(844, 390), Rect2i(44, 0, 756, 369), 16)
	t.check(notched_margins.left == 44 and notched_margins.right == 44 and notched_margins.bottom == 21 and notched_margins.top == 8 and notched_margins.compact, "compact notched landscape 844x390 respects safe-area cutouts and compact mode")
	var out_of_bounds := PlayerInput.compute_safe_margins(Vector2i(800, 480), Rect2i(-10, 0, 900, 500), 16)
	t.check(out_of_bounds.left == 8 and out_of_bounds.compact, "invalid safe_rect falls back cleanly to compact base margins")

func _test_web_persistence_ack(t) -> void:
	var directory := "user://web-persistence-tests-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var unavailable_ack := WebSaveAck.new()
	unavailable_ack.configure_simulated_web(false)
	var unavailable_store := RecoveryStore.new(directory, unavailable_ack)
	var s = t.session()
	t.check(not unavailable_store.save(s).ok and unavailable_store.last_error == "web_storage_unavailable", "non-persistent Web userfs rejects save")
	t.check(unavailable_store.load_candidate(s) == null and unavailable_store.last_error == "web_storage_unavailable", "non-persistent Web userfs rejects load")

	# Synchronous save() must NEVER report success when IndexedDB remains pending.
	var always_pending_ack := WebSaveAck.new()
	always_pending_ack.configure_simulated_web(
		true,
		func(_path, _bytes, _idb): return "pending",
		func(_path, _bytes, _idb): return "pending"
	)
	var sync_pending_store := RecoveryStore.new(directory, always_pending_ack)
	var sync_res := sync_pending_store.save(s)
	t.check(not sync_res.ok and sync_res.code == "web_sync_pending", "synchronous save() rejects unconfirmed pending IndexedDB state")
	t.check(not sync_pending_store.is_save_pending() and not always_pending_ack.is_dirty(), "rejected synchronous pending save rolls back and clears dirty guard")
	t.check(sync_pending_store.load_candidate(s) == null, "unconfirmed synchronous save leaves no loadable candidate")

	# Immediate confirmed Web save (generation 1 -> slot_a.json).
	var web_ack := WebSaveAck.new()
	web_ack.configure_simulated_web(true)
	var store := RecoveryStore.new(directory, web_ack)
	t.check(store.save(s).ok and web_ack.last_state() == "confirmed" and not web_ack.is_dirty(), "confirmed Web save flushes to simulated IndexedDB /userfs and clears dirty guard")
	var slot_a_global := ProjectSettings.globalize_path(directory.path_join("slot_a.json"))
	t.check(not web_ack.simulated_idb_bytes(slot_a_global).is_empty(), "IndexedDB FILE_DATA record written for slot_a.json")

	# Delayed multi-poll IndexedDB confirmation (generation 2 -> slot_b.json).
	s.advance_to(10)
	var polls: Array[int] = [0]
	var delayed_ack := WebSaveAck.new()
	delayed_ack.configure_simulated_web(
		true,
		func(_path, _bytes, _idb): return "pending",
		func(path, bytes, idb):
			polls[0] += 1
			if polls[0] < 2:
				return "pending"
			idb[path] = bytes.duplicate()
			return "confirmed"
	)
	var delayed_store := RecoveryStore.new(directory, delayed_ack, 1000)
	var begin_res := delayed_store.begin_save(s)
	t.check(not begin_res.ok and begin_res.code == "web_sync_pending" and delayed_store.is_save_pending() and delayed_ack.is_dirty(), "begin_save reports pending while IndexedDB transaction is in flight")
	t.check(not delayed_store.save(s).ok and delayed_store.last_error == "web_save_in_flight", "concurrent save() rejected while Web save is in flight")
	t.check(not delayed_store.begin_save(s).ok and delayed_store.last_error == "web_save_in_flight", "concurrent begin_save() rejected while Web save is in flight")
	var during_pending := delayed_store.load_candidate(s)
	t.check(during_pending != null and during_pending.now() == 0, "load_candidate ignores unconfirmed in-flight slot_b and returns confirmed slot_a")
	var poll_1 := delayed_store.poll_save(200)
	t.check(not poll_1.ok and poll_1.code == "web_sync_pending" and delayed_store.is_save_pending(), "first poll remains pending before IndexedDB commit")
	var poll_2 := delayed_store.poll_save(200)
	t.check(poll_2.ok and not delayed_store.is_save_pending() and not delayed_ack.is_dirty(), "second poll confirms IndexedDB commit and clears in-flight state")
	t.check(delayed_store.load_candidate(s).now() == 10, "confirmed delayed Web save loads generation 2 from slot_b")

	# Timeout on generation 3 (overwriting slot_a.json in MEMFS) restores slot_a.json's confirmed gen 1 and preserves gen 2 in slot_b.json.
	s.advance_to(20)
	var timeout_ack := WebSaveAck.new()
	timeout_ack.configure_simulated_web(
		true,
		func(_path, _bytes, _idb): return "pending",
		func(_path, _bytes, _idb): return "pending"
	)
	var timeout_store := RecoveryStore.new(directory, timeout_ack, 500)
	t.check(timeout_store.begin_save(s).code == "web_sync_pending", "generation 3 starts pending")
	var timeout_poll := timeout_store.poll_save(600)
	t.check(not timeout_poll.ok and timeout_poll.code == "web_sync_timeout" and not timeout_store.is_save_pending(), "poll_save fails closed with web_sync_timeout when IndexedDB exceeds timeout")
	t.check(store.load_candidate(s).now() == 10, "timed-out generation 3 rolls back slot_a to confirmed gen 1 and preserves gen 2 in slot_b")

	# Delayed failure on generation 3 also rolls back cleanly.
	var fail_ack := WebSaveAck.new()
	fail_ack.configure_simulated_web(
		true,
		func(_path, _bytes, _idb): return "pending",
		func(_path, _bytes, _idb): return "failed"
	)
	var fail_store := RecoveryStore.new(directory, fail_ack, 1000)
	t.check(fail_store.begin_save(s).code == "web_sync_pending", "generation 3 retry starts pending")
	var fail_poll := fail_store.poll_save(100)
	t.check(not fail_poll.ok and fail_poll.code == "web_sync_failed" and not fail_store.is_save_pending(), "delayed IndexedDB error fails closed with web_sync_failed")
	t.check(store.load_candidate(s).now() == 10, "failed generation 3 preserves confirmed generation 2")

	for name in ["slot_a.json", "slot_b.json", "slot_a.json.tmp", "slot_b.json.tmp", "slot_a.json.idb", "slot_b.json.idb"]:
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
