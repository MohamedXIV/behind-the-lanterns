class_name TouchControls
extends HBoxContainer
## Landscape on-screen touch controls: directional cluster, run toggle, and
## context/evasion action buttons. Supports visibility toggles and left/right
## handedness swapping for small landscape screens.

signal use_pressed()
signal talk_pressed()
signal combat_action_pressed(action: String)

var _input: PlayerInput
var _dpad_cluster: HBoxContainer
var _action_cluster: HBoxContainer
var _spacer: Control
var _run_button: Button
var _direction_buttons: Dictionary = {}

func configure(input: PlayerInput) -> void:
	_input = input
	name = "TouchControls"
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()
	refresh()

func _build() -> void:
	for child in get_children():
		child.free()
	_dpad_cluster = HBoxContainer.new()
	_dpad_cluster.name = "DpadCluster"
	_dpad_cluster.add_theme_constant_override("separation", 6)
	var dpad_specs := [
		{"dir": "left", "name": "TouchLeft", "label": "◀ Left"},
		{"dir": "up", "name": "TouchUp", "label": "▲ Up"},
		{"dir": "down", "name": "TouchDown", "label": "▼ Down"},
		{"dir": "right", "name": "TouchRight", "label": "▶ Right"},
	]
	for spec in dpad_specs:
		var btn := Button.new()
		btn.name = spec.name
		btn.text = spec.label
		btn.custom_minimum_size = Vector2(72, PlayerInput.MIN_TOUCH_TARGET)
		btn.button_down.connect(_on_direction.bind(spec.dir, true))
		btn.button_up.connect(_on_direction.bind(spec.dir, false))
		_dpad_cluster.add_child(btn)
		_direction_buttons[spec.dir] = btn

	_spacer = Control.new()
	_spacer.name = "ClusterSpacer"
	_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_action_cluster = HBoxContainer.new()
	_action_cluster.name = "ActionCluster"
	_action_cluster.add_theme_constant_override("separation", 6)

	_run_button = Button.new()
	_run_button.name = "TouchRun"
	_run_button.toggle_mode = true
	_run_button.custom_minimum_size = Vector2(92, PlayerInput.MIN_TOUCH_TARGET)
	_run_button.toggled.connect(_on_run_toggled)
	_action_cluster.add_child(_run_button)

	var use_btn := Button.new()
	use_btn.name = "TouchUse"
	use_btn.text = "Use"
	use_btn.custom_minimum_size = Vector2(72, PlayerInput.MIN_TOUCH_TARGET)
	use_btn.pressed.connect(func():
		if _input != null: _input.trigger_action(PlayerInput.INTERACT)
		use_pressed.emit())
	_action_cluster.add_child(use_btn)

	var talk_btn := Button.new()
	talk_btn.name = "TouchTalk"
	talk_btn.text = "Talk"
	talk_btn.custom_minimum_size = Vector2(72, PlayerInput.MIN_TOUCH_TARGET)
	talk_btn.pressed.connect(func():
		if _input != null: _input.trigger_action(PlayerInput.TALK)
		talk_pressed.emit())
	_action_cluster.add_child(talk_btn)

	var evade_btn := Button.new()
	evade_btn.name = "TouchEvade"
	evade_btn.text = "Evade"
	evade_btn.custom_minimum_size = Vector2(64, PlayerInput.MIN_TOUCH_TARGET)
	evade_btn.pressed.connect(func():
		if _input != null: _input.trigger_action(PlayerInput.DODGE)
		combat_action_pressed.emit(PlayerInput.DODGE))
	_action_cluster.add_child(evade_btn)

	var guard_btn := Button.new()
	guard_btn.name = "TouchGuard"
	guard_btn.text = "Guard"
	guard_btn.custom_minimum_size = Vector2(64, PlayerInput.MIN_TOUCH_TARGET)
	guard_btn.pressed.connect(func():
		if _input != null: _input.trigger_action(PlayerInput.BLOCK)
		combat_action_pressed.emit(PlayerInput.BLOCK))
	_action_cluster.add_child(guard_btn)

	var strike_btn := Button.new()
	strike_btn.name = "TouchStrike"
	strike_btn.text = "Strike"
	strike_btn.custom_minimum_size = Vector2(64, PlayerInput.MIN_TOUCH_TARGET)
	strike_btn.pressed.connect(func():
		if _input != null: _input.trigger_action(PlayerInput.PRIMARY_ACTION)
		combat_action_pressed.emit(PlayerInput.PRIMARY_ACTION))
	_action_cluster.add_child(strike_btn)

	add_child(_dpad_cluster)
	add_child(_spacer)
	add_child(_action_cluster)

func refresh() -> void:
	if _input == null: return
	visible = _input.is_touch_visible()
	_run_button.set_pressed_no_signal(_input.is_run_latched())
	_run_button.text = "Run: On" if _input.is_run_latched() else "Run: Off"
	if _input.handedness() == PlayerInput.HANDEDNESS_SWAPPED:
		move_child(_action_cluster, 0)
		move_child(_spacer, 1)
		move_child(_dpad_cluster, 2)
	else:
		move_child(_dpad_cluster, 0)
		move_child(_spacer, 1)
		move_child(_action_cluster, 2)

func cluster_order() -> Array[String]:
	var names: Array[String] = []
	for child in get_children():
		names.append(child.name)
	return names

func _on_direction(direction_name: String, pressed: bool) -> void:
	if _input == null: return
	_input.set_touch_button(direction_name, pressed)

func _on_run_toggled(enabled: bool) -> void:
	if _input == null: return
	_input.set_run_latched(enabled)
	refresh()
