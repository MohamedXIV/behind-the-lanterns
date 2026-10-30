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

	var web_ack := WebSaveAck.new()
	web_ack.configure_simulated_web(true)
	var store := RecoveryStore.new(directory, web_ack)
	t.check(store.save(s).ok and web_ack.last_state() == "confirmed" and not web_ack.is_dirty(), "confirmed Web save flushes to simulated IndexedDB /userfs and clears dirty guard")
	var slot_a_global := ProjectSettings.globalize_path(directory.path_join("slot_a.json"))
	t.check(not web_ack.simulated_idb_bytes(slot_a_global).is_empty(), "IndexedDB FILE_DATA record written for slot_a.json")
	s.advance_to(10)
	t.check(store.save(s).ok and store.load_candidate(s).now() == 10, "second Web generation commits to slot_b.json and loads newest generation")

	# Simulate an IndexedDB sync failure on generation 3: slot_a.json (gen 1) or slot_b.json (gen 2) must remain recoverable!
	var failing_ack := WebSaveAck.new()
	failing_ack.configure_simulated_web(true, func(_path, _bytes, _idb): return false)
	var failing_store := RecoveryStore.new(directory, failing_ack)
	s.advance_to(20)
	var failed_save := failing_store.save(s)
	t.check(not failed_save.ok and failed_save.code == "web_sync_failed", "unacknowledged IndexedDB flush fails closed")
	var recovered := store.load_candidate(s)
	t.check(recovered != null and recovered.now() == 10, "failed Web sync rolls back unconfirmed slot and preserves previous generation")

	for name in ["slot_a.json", "slot_b.json", "slot_a.json.tmp", "slot_b.json.tmp"]:
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
