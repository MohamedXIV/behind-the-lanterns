class_name PlaygroundMap
extends Control
## Disposable movement/picking adapter; not the production actor/collision system.

signal target_selected(entity_id: String)
signal stopped(point: Vector2)

const PADDING: float = 28.0
const PICK_RADIUS: float = 28.0
const GRID_STEP: int = 80
var _model: GameplayModel
var _actor: String
var _labels: Dictionary
var _speed: float
var _visual: Vector2
var _goal: Vector2
var _pointer_walking: bool = false
var _keyboard_walking: bool = false
var selected_target: String = ""

func configure(model: GameplayModel, actor: String, labels: Dictionary, speed: float) -> void:
	_model = model
	_actor = actor
	_labels = labels.duplicate()
	_speed = speed
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	sync_position()

func sync_position() -> void:
	_visual = _model.position_of(_actor)
	_goal = _visual
	_pointer_walking = false
	_keyboard_walking = false
	queue_redraw()

func visual_position() -> Vector2:
	return _visual

func halt() -> void:
	_goal = _visual
	_pointer_walking = false
	_keyboard_walking = false

func _scale_factor() -> float:
	var available := (size - Vector2.ONE * PADDING * 2).max(Vector2.ONE)
	return minf(available.x / _model.interactions.bounds().x, available.y / _model.interactions.bounds().y)

func _offset() -> Vector2:
	return (size - _model.interactions.bounds() * _scale_factor()) * 0.5

func world_to_local(point: Vector2) -> Vector2:
	return _offset() + point * _scale_factor()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_tap(event.position)

func _tap(point: Vector2) -> void:
	grab_focus()
	_goal = ((point - _offset()) / _scale_factor()).clamp(Vector2.ZERO, _model.interactions.bounds())
	var closest: String = ""
	var distance: float = PICK_RADIUS
	var snapshot := _model.session.snapshot()
	for id in _model.interactions.target_ids():
		if id == _actor or snapshot.entities[id].region_id != snapshot.entities[_actor].region_id: continue
		var separation := _model.position_of(id).distance_to(_goal)
		if separation < distance:
			closest = id
			distance = separation
	if not closest.is_empty():
		selected_target = closest
		target_selected.emit(closest)
	_pointer_walking = true
	queue_redraw()

func _process(delta: float) -> void:
	if _model == null or _model.session.is_closed(): return
	var direction := Vector2.ZERO
	if has_focus():
		direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		direction.x += float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		direction.y += float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	if not direction.is_zero_approx():
		_visual = (_visual + direction.normalized() * _speed * delta).clamp(Vector2.ZERO, _model.interactions.bounds())
		_goal = _visual
		_pointer_walking = false
		_keyboard_walking = true
		queue_redraw()
	elif _keyboard_walking:
		_keyboard_walking = false
		stopped.emit(_visual)
	elif _pointer_walking:
		_visual = _visual.move_toward(_goal, _speed * delta)
		queue_redraw()
		if _visual.is_equal_approx(_goal):
			_pointer_walking = false
			stopped.emit(_visual)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("17282b"))
	if _model == null: return
	var extent := _model.interactions.bounds()
	for x in range(0, int(extent.x) + 1, GRID_STEP):
		draw_line(world_to_local(Vector2(x, 0)), world_to_local(Vector2(x, extent.y)), Color("263b3b"))
	for y in range(0, int(extent.y) + 1, GRID_STEP):
		draw_line(world_to_local(Vector2(0, y)), world_to_local(Vector2(extent.x, y)), Color("263b3b"))
	var snapshot := _model.session.snapshot()
	var font := get_theme_default_font()
	for id in _model.interactions.target_ids():
		if id == _actor or snapshot.entities[id].region_id != snapshot.entities[_actor].region_id: continue
		var at := world_to_local(_model.position_of(id))
		var color := Color("d8b777") if _model.inventory.can_access(_actor, id) else Color("a67d88")
		if _model.commerce.is_shop(id): color = Color("9bbf91")
		if id in _model.crafting.station_ids(): color = Color("d49b61")
		var npc := _model.npcs.projection(id, snapshot.minute)
		if not npc.is_empty() and not npc.available: color = Color("6e8582")
		draw_rect(Rect2(at - Vector2(16, 16), Vector2(32, 32)), color)
		if id == selected_target: draw_arc(at, 24, 0, TAU, 32, Color("ffe3a1"), 2)
		draw_string(font, at + Vector2(-80, -28), _labels.get(id, id), HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color("e8e4d5"))
		var detail: String = npc.activity if not npc.is_empty() else "Preparation" if id in _model.crafting.station_ids() else "%d goods" % _quantity(snapshot, id)
		draw_string(font, at + Vector2(-80, 42), detail, HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color("b4c7c3"))
	var actor_at := world_to_local(_visual)
	draw_arc(actor_at, _model.interactions.reach() * _scale_factor(), 0, TAU, 48, Color(0.55, 0.85, 0.85, 0.22), 1)
	draw_circle(actor_at, 10, Color("8bd0d1"))
	draw_string(font, actor_at + Vector2(-24, 30), "You", HORIZONTAL_ALIGNMENT_CENTER, 48, 16, Color("c4f4ef"))

func _quantity(snapshot: Dictionary, holder: String) -> int:
	var amount: int = 0
	for value in _model.inventory.contents(snapshot, holder).values(): amount += int(value)
	return amount
