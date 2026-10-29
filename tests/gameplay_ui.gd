extends SceneTree
## Real Godot nodes, input events and button signals; no mocked rule services.

var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: gameplay UI " + label)

func frames(count: int) -> void:
	for _frame in count: await process_frame

func tap(map, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = map.global_position + map.world_to_local(point)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func touch(map, point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.position = map.global_position + map.world_to_local(point)
	event.index = 0
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func _run() -> void:
	if not ResourceLoader.exists("res://dev/gameplay_playground.gd"):
		check(false, "playable presentation implementation required")
		_finish()
		return
	root.size = Vector2i(1120, 720)
	var app = load("res://game/app/main.gd").new()
	root.add_child(app)
	var directory := "user://gameplay-ui-%d" % OS.get_process_id()
	app.open_playground(directory)
	await frames(3)
	var view = app.get_node("GameplayPlayground")
	var m: GameplayModel = view.model()
	var map = view.find_child("WorldMap", true, false)
	check(m != null and map.size.x > 0, "app opens composed playground")
	check(view.find_child("Take", true, false).custom_minimum_size.y >= 48, "actions have touch-sized minimum height")
	await tap(map, m.position_of("a:supplies"))
	await frames(50)
	check(m.position_of("a:player").distance_to(m.position_of("a:supplies")) < 1, "pointer input walks and commits position")
	view.find_child("Quantity", true, false).value = 4
	view.find_child("Take", true, false).pressed.emit()
	check(m.inventory.contents(m.session.snapshot(), "a:player").get("item.dates", 0) == 4, "Take button changes persistent custody")
	await tap(map, m.position_of("a:chest"))
	await frames(90)
	view.find_child("Quantity", true, false).value = 1
	view.find_child("Store", true, false).pressed.emit()
	check(m.inventory.contents(m.session.snapshot(), "a:chest").get("item.dates", 0) == 1, "Store button moves to owned chest")
	view.find_child("Save", true, false).pressed.emit()
	check(FileAccess.file_exists(directory.path_join("slot_a.json")), "Save button publishes native recovery")
	view.find_child("Take", true, false).pressed.emit()
	var previous: GameSession = m.session
	view.find_child("Load", true, false).pressed.emit()
	check(previous.is_closed(), "Load retires previous session")
	check(m.inventory.contents(m.session.snapshot(), "a:player").get("item.dates", 0) == 3, "Load restores bag rather than duplicating unsaved take")
	check(m.position_of("a:player").distance_to(m.position_of("a:chest")) < 1, "Load restores actor position")
	map.grab_focus()
	var revision: int = m.session.snapshot().revision
	var key := InputEventKey.new()
	key.keycode = KEY_D
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await frames(45)
	check(m.session.snapshot().revision == revision, "walking does not commit every frame")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await frames(3)
	check(m.position_of("a:player").x > 450, "keyboard movement commits when stopped")
	await touch(map, m.position_of("a:merchant"))
	await frames(60)
	check(m.position_of("a:player").distance_to(m.position_of("a:merchant")) < 1, "screen-touch event walks to merchant")
	view.find_child("Buy", true, false).pressed.emit()
	check(m.wallet("a:player") == 7, "Buy button pays quoted merchant price")
	view.find_child("Sell", true, false).pressed.emit()
	check(m.wallet("a:player") == 9, "Sell button receives quoted payment")
	check(view.find_child("BagSummary", true, false).text.contains("Dates: 3"), "visible inventory refreshes from committed state")
	app.free()
	for name in RecoveryStore.SLOT_NAMES: DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	_finish()

func _finish() -> void:
	print("GAMEPLAY UI %s: %d assertions, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)
