class_name TravelPanel
extends VBoxContainer

const ACTION_HEIGHT: float = 52.0

var _model: GameplayModel
var _actor: String
var _prepare: Callable
var _sync_view: Callable
var _labels: Dictionary
var _region_labels: Dictionary
var _carrier_id: String = ""
var _route_ids: Array[String] = []
var _route: OptionButton
var _status: Label
var _feedback: Label
var _history: Label
var _board: Button

func configure(model: GameplayModel, actor: String, prepare: Callable, sync_view: Callable, labels: Dictionary, region_labels: Dictionary) -> void:
	_model = model
	_actor = actor
	_prepare = prepare
	_sync_view = sync_view
	_labels = labels
	_region_labels = region_labels
	add_theme_constant_override("separation", 9)
	_status = _label("Public routes", 16)
	_status.name = "TravelStatus"
	_route = OptionButton.new()
	_route.name = "TravelRoute"
	_route.custom_minimum_size.y = 48
	_route.item_selected.connect(func(_index: int): refresh())
	add_child(_route)
	_board = Button.new()
	_board.name = "ConfirmTravel"
	_board.custom_minimum_size = Vector2(300, ACTION_HEIGHT)
	_board.pressed.connect(_confirm_travel)
	add_child(_board)
	_feedback = _label("Ordinary journeys use public carriers. No private vessel is required.", 15)
	_feedback.name = "TravelFeedback"
	_history = _label("Travel log\nNo journeys yet.", 15)
	_history.name = "TravelHistory"
	_rebuild_routes()
	refresh()

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 300
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e4e5d8"))
	add_child(label)
	return label

func open(carrier_id: String) -> void:
	_carrier_id = carrier_id
	_rebuild_routes()
	refresh()

func reset_after_load() -> void:
	_carrier_id = ""
	_feedback.text = "Journey state restored from the saved world."
	_rebuild_routes()
	refresh()

func _route_id() -> String:
	return _route.get_item_metadata(_route.selected) if _route != null and _route.selected >= 0 else ""

func _rebuild_routes() -> void:
	if _route == null: return
	var previous := _route_id()
	_route.clear()
	_route_ids = _model.travel.route_ids(_model.session.snapshot(), _actor, _carrier_id)
	for route_id in _route_ids:
		var definition := _model.travel.route(route_id)
		var destination: String = _region_labels.get(definition.destination_region, definition.destination_region)
		_route.add_item("%s · %s" % [definition.label, destination])
		_route.set_item_metadata(_route.item_count - 1, route_id)
		if route_id == previous: _route.select(_route.item_count - 1)

func refresh() -> void:
	if _model == null or _model.travel == null or _route == null: return
	var current_ids := _model.travel.route_ids(_model.session.snapshot(), _actor, _carrier_id)
	if current_ids != _route_ids: _rebuild_routes()
	_refresh_history()
	var route_id := _route_id()
	if route_id.is_empty():
		_status.text = "No public routes depart this region. Explore or return by another carrier."
		_board.text = "No route available"
		_board.disabled = true
		return
	var definition := _model.travel.route(route_id)
	var origin: String = _region_labels.get(definition.origin_region, definition.origin_region)
	var destination: String = _region_labels.get(definition.destination_region, definition.destination_region)
	var carrier: String = _labels.get(definition.carrier_id, definition.carrier_id)
	var available := _model.interactions.available(definition.carrier_id, _model.session.now())
	var hazard_note := "\nNotice: Hazardous destination — public carrier refuses direct landing" if definition.has("hazard_refusal") else ""
	_status.text = "%s · %s\n%s → %s\nCarrier: %s · %s\nFare: %d coins · Journey: %d world min%s" % [definition.label, definition.mode.capitalize(), origin, destination, carrier, "accepting passengers" if available else "unavailable now", definition.fare, definition.duration_minutes, hazard_note]
	_board.text = "Travel · %d coins" % definition.fare
	_board.disabled = false

func _refresh_history() -> void:
	var records := _model.travel.journeys_for(_model.session.snapshot(), _actor)
	if records.is_empty():
		_history.text = "Travel log\nNo journeys yet."
		return
	var lines: PackedStringArray = ["Travel log"]
	for record in records.slice(0, mini(5, records.size())):
		var definition := _model.travel.route(record.route_id)
		var destination: String = _region_labels.get(definition.destination_region, definition.destination_region)
		lines.append("Day %d · %s\n%s" % [int(record.arrival_minute / WorldClock.MINUTES_PER_DAY) + 1, destination, definition.log])
	_history.text = "\n\n".join(lines)

func _confirm_travel() -> void:
	var prepared: OperationResult = _prepare.call()
	if not prepared.ok:
		_feedback.text = _message(prepared.code)
		return
	var route_id := _route_id()
	if route_id.is_empty(): return
	var definition := _model.travel.route(route_id)
	var result := _model.take_route("travel:%d" % _model.session.snapshot().revision, _actor, route_id)
	if result.ok:
		if _sync_view.is_valid(): _sync_view.call()
		_carrier_id = ""
		_rebuild_routes()
		var destination: String = _region_labels.get(definition.destination_region, definition.destination_region)
		_feedback.text = definition.log + "\nArrived at " + destination + "."
	elif result.code == "carrier_refuses_hazard" and definition.has("hazard_refusal"):
		_feedback.text = str(definition.hazard_refusal)
	else:
		_feedback.text = _message(result.code)
	refresh()

func _message(code: String) -> String:
	return {
		"out_of_reach": "Walk closer to this route's public carrier.",
		"different_region": "This route departs from another region.",
		"person_unavailable": "The carrier is not accepting passengers now. Wait for their next duty period.",
		"insufficient_funds": "You do not have enough coins for this fare.",
		"carrier_refuses_pursuit": "Public carriers refuse passage while the watch is pursuing you.",
		"carrier_refuses_hazard": "Public carriers refuse direct passage into hazardous or uncharted waters; approach from a safe landing on foot.",
		"actor_detained": "You cannot book public travel while detained.",
	}.get(code, code.replace("_", " "))
