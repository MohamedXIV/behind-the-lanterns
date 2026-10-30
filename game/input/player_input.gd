class_name PlayerInput
extends RefCounted
## Mobile-first input and ergonomics abstraction.
## Decouples movement, running, context interaction and future combat/evasion
## intents from specific physical keys or on-screen buttons.

const MOVE_LEFT: String = "btl_move_left"
const MOVE_RIGHT: String = "btl_move_right"
const MOVE_UP: String = "btl_move_up"
const MOVE_DOWN: String = "btl_move_down"
const RUN: String = "btl_run"
const INTERACT: String = "btl_interact"
const TALK: String = "btl_talk"
const DODGE: String = "btl_dodge"
const BLOCK: String = "btl_block"
const PRIMARY_ACTION: String = "btl_primary_action"

const ALL_ACTIONS: Array[String] = [
	MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN,
	RUN, INTERACT, TALK,
	DODGE, BLOCK, PRIMARY_ACTION,
]
const COMBAT_ACTIONS: Array[String] = [DODGE, BLOCK, PRIMARY_ACTION]
const DIRECTION_NAMES: Array[String] = ["left", "right", "up", "down"]

const VISIBILITY_AUTO: String = "auto"
const VISIBILITY_SHOWN: String = "shown"
const VISIBILITY_HIDDEN: String = "hidden"
const VALID_VISIBILITY: Array[String] = [VISIBILITY_AUTO, VISIBILITY_SHOWN, VISIBILITY_HIDDEN]

const HANDEDNESS_STANDARD: String = "standard"
const HANDEDNESS_SWAPPED: String = "swapped"
const VALID_HANDEDNESS: Array[String] = [HANDEDNESS_STANDARD, HANDEDNESS_SWAPPED]

const MIN_TOUCH_TARGET: float = 48.0
const PRIMARY_TOUCH_TARGET: float = 52.0
const WALK_SPEED_MULTIPLIER: float = 1.0
const RUN_SPEED_MULTIPLIER: float = 1.65

var _bindings: Dictionary = {}
var _touch_buttons: Dictionary = {"left": false, "right": false, "up": false, "down": false}
var _touch_vector: Vector2 = Vector2.ZERO
var _run_latched: bool = false
var _pending_actions: Dictionary = {}
var _visibility_mode: String = VISIBILITY_AUTO
var _handedness: String = HANDEDNESS_STANDARD

func _init() -> void:
	reset_default_bindings()

func reset_default_bindings() -> void:
	_bindings = {
		MOVE_LEFT: [KEY_A, KEY_LEFT],
		MOVE_RIGHT: [KEY_D, KEY_RIGHT],
		MOVE_UP: [KEY_W, KEY_UP],
		MOVE_DOWN: [KEY_S, KEY_DOWN],
		RUN: [KEY_SHIFT],
		INTERACT: [KEY_E, KEY_SPACE],
		TALK: [KEY_T],
		DODGE: [KEY_Q],
		BLOCK: [KEY_F],
		PRIMARY_ACTION: [KEY_R],
	}
	_sync_input_map()

func remap_key(action: String, keycode: int) -> OperationResult:
	if not action in ALL_ACTIONS:
		return OperationResult.failure("unknown_input_action")
	if keycode <= 0:
		return OperationResult.failure("invalid_keycode")
	_bindings[action] = [keycode]
	_sync_action(action)
	return OperationResult.success()

func bound_keys(action: String) -> Array[int]:
	var result: Array[int] = []
	for code in _bindings.get(action, []):
		result.append(int(code))
	return result

func matches_event(action: String, event: InputEvent) -> bool:
	if not action in ALL_ACTIONS: return false
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return code in _bindings.get(action, [])
	return false

func set_touch_button(direction_name: String, pressed: bool) -> OperationResult:
	if not direction_name in DIRECTION_NAMES:
		return OperationResult.failure("unknown_direction")
	_touch_buttons[direction_name] = pressed
	return OperationResult.success()

func set_touch_vector(vector: Vector2) -> void:
	_touch_vector = vector.limit_length(1.0)

func set_run_latched(enabled: bool) -> void:
	_run_latched = enabled

func is_run_latched() -> bool:
	return _run_latched

func is_running(include_keyboard: bool = true) -> bool:
	if _run_latched: return true
	if not include_keyboard: return false
	if InputMap.has_action(RUN) and Input.is_action_pressed(RUN): return true
	for code in _bindings.get(RUN, []):
		if Input.is_physical_key_pressed(int(code)): return true
	return false

func speed_multiplier(include_keyboard: bool = true) -> float:
	return RUN_SPEED_MULTIPLIER if is_running(include_keyboard) else WALK_SPEED_MULTIPLIER

func movement_vector(include_keyboard: bool = true) -> Vector2:
	var dir := _touch_vector
	dir.x += float(bool(_touch_buttons.get("right", false))) - float(bool(_touch_buttons.get("left", false)))
	dir.y += float(bool(_touch_buttons.get("down", false))) - float(bool(_touch_buttons.get("up", false)))
	if include_keyboard:
		if InputMap.has_action(MOVE_LEFT) and InputMap.has_action(MOVE_RIGHT) and InputMap.has_action(MOVE_UP) and InputMap.has_action(MOVE_DOWN):
			dir += Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN)
		dir += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		for code in _bindings.get(MOVE_RIGHT, []):
			if Input.is_physical_key_pressed(int(code)): dir.x += 1.0
		for code in _bindings.get(MOVE_LEFT, []):
			if Input.is_physical_key_pressed(int(code)): dir.x -= 1.0
		for code in _bindings.get(MOVE_DOWN, []):
			if Input.is_physical_key_pressed(int(code)): dir.y += 1.0
		for code in _bindings.get(MOVE_UP, []):
			if Input.is_physical_key_pressed(int(code)): dir.y -= 1.0
	return Vector2.ZERO if dir.is_zero_approx() else dir.normalized()

func trigger_action(action: String) -> OperationResult:
	if not action in ALL_ACTIONS:
		return OperationResult.failure("unknown_input_action")
	_pending_actions[action] = true
	return OperationResult.success()

func consume_action(action: String) -> bool:
	if not _pending_actions.get(action, false): return false
	_pending_actions.erase(action)
	return true

func release_all() -> void:
	for direction_name in DIRECTION_NAMES:
		_touch_buttons[direction_name] = false
	_touch_vector = Vector2.ZERO
	_pending_actions.clear()
	for action in [MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN, RUN]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)

func set_touch_visibility(mode: String) -> OperationResult:
	if not mode in VALID_VISIBILITY:
		return OperationResult.failure("invalid_visibility_mode")
	_visibility_mode = mode
	return OperationResult.success()

func touch_visibility() -> String:
	return _visibility_mode

func is_touch_visible(_has_touchscreen: bool = true) -> bool:
	if _visibility_mode == VISIBILITY_HIDDEN: return false
	return true

func set_handedness(mode: String) -> OperationResult:
	if not mode in VALID_HANDEDNESS:
		return OperationResult.failure("invalid_handedness")
	_handedness = mode
	return OperationResult.success()

func handedness() -> String:
	return _handedness

static func compute_safe_margins(viewport_size: Vector2i, safe_rect: Rect2i, base_margin: int = 16) -> Dictionary:
	var compact: bool = viewport_size.x > 0 and (viewport_size.x < 960 or viewport_size.y < 540)
	var fallback: int = mini(base_margin, 8) if compact else base_margin
	var left: int = fallback
	var top: int = fallback
	var right: int = fallback
	var bottom: int = fallback
	if viewport_size.x > 0 and viewport_size.y > 0 and safe_rect.size.x > 0 and safe_rect.size.y > 0:
		if safe_rect.position.x >= 0 and safe_rect.position.y >= 0 and safe_rect.end.x <= viewport_size.x and safe_rect.end.y <= viewport_size.y:
			left = maxi(fallback, safe_rect.position.x)
			top = maxi(fallback, safe_rect.position.y)
			right = maxi(fallback, viewport_size.x - safe_rect.end.x)
			bottom = maxi(fallback, viewport_size.y - safe_rect.end.y)
	return {
		"left": left,
		"top": top,
		"right": right,
		"bottom": bottom,
		"compact": compact,
	}

func _sync_input_map() -> void:
	for action in ALL_ACTIONS:
		_sync_action(action)

func _sync_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for code in _bindings.get(action, []):
		var event := InputEventKey.new()
		event.keycode = int(code) as Key
		event.physical_keycode = int(code) as Key
		InputMap.action_add_event(action, event)
