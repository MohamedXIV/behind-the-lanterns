class_name FishingPanel
extends VBoxContainer
## Touch-sized local timing presentation; only committed active time is saved.
var _model: GameplayModel
var _actor: String
var _prepare: Callable
var _visual: Callable
var _spot: String = ""
var _bait: OptionButton
var _status: Label
var _bar: ProgressBar
var _pending: float = 0.0
var _suspended: bool = false

func configure(model: GameplayModel, actor: String, prepare: Callable, visual: Callable) -> void:
	_model = model
	_actor = actor
	_prepare = prepare
	_visual = visual
	_status = Label.new()
	_status.name = "FishingStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 300
	add_child(_status)
	_bait = OptionButton.new()
	_bait.name = "FishingBait"
	_bait.custom_minimum_size.y = 48
	for bait in model.fishing.baits():
		_bait.add_item(model.inventory.item_definition(bait).label)
		_bait.set_item_metadata(_bait.item_count - 1, bait)
	add_child(_bait)
	_bar = ProgressBar.new()
	_bar.name = "FishingTiming"
	_bar.custom_minimum_size.y = 32
	add_child(_bar)
	for record in [["CastLine", "Cast · spend one bait", _cast], ["ReelLine", "Reel / collect catch", _reel], ["CancelFishing", "Put the line away", _cancel]]:
		var button := Button.new()
		button.name = record[0]
		button.text = record[1]
		button.custom_minimum_size = Vector2(300, 56)
		button.pressed.connect(record[2])
		add_child(button)
	refresh()

func open(spot: String) -> void:
	_spot = spot
	refresh()

func _intent() -> String:
	return "fishing:%d" % _model.session.snapshot().revision

func _ready_action() -> bool:
	var result: OperationResult = _prepare.call()
	if not result.ok: _status.text = result.code.replace("_", " ")
	return result.ok

func _cast() -> void:
	if not _ready_action(): return
	_pending = 0
	var result := _model.cast_line(_intent(), _actor, _spot, _bait.get_item_metadata(_bait.selected))
	refresh()
	if not result.ok: _status.text = result.code.replace("_", " ")

func _reel() -> void:
	if not _ready_action(): return
	var result := _model.reel_line(_intent(), _actor)
	refresh()
	if not result.ok: _status.text = result.code.replace("_", " ")

func _cancel() -> void:
	if not _ready_action(): return
	var result := _model.cancel_fishing(_intent(), _actor)
	_pending = 0
	refresh()
	if not result.ok: _status.text = result.code.replace("_", " ")

func _near(record: Dictionary) -> bool:
	if record.is_empty(): return false
	var snapshot := _model.session.snapshot()
	if snapshot.entities[_actor].region_id != snapshot.entities[record.spot_id].region_id: return false
	var visual: Vector2 = _visual.call()
	var at := _model.position_of(record.spot_id)
	return visual.distance_to(at) <= _model.interactions.reach() and _model.interactions.geometry_for(_model.actor_region(_actor)).clear_segment(visual, at)

func _process(delta: float) -> void:
	if _model == null or _model.session.is_closed() or _suspended: return
	var record := _model.fishing.attempt(_model.session.snapshot(), _actor)
	if record.get("status", "") != "waiting" or not _near(record): return
	_pending += minf(delta, 0.1)
	if _pending >= 0.1: flush_progress()

func flush_progress() -> void:
	if _model == null or _suspended or _pending < 0.001: return
	var record := _model.fishing.attempt(_model.session.snapshot(), _actor)
	if record.get("status", "") != "waiting" or not _near(record):
		_pending = 0
		return
	var milliseconds := mini(int(_pending * 1000), 10000)
	_pending = 0
	_model.progress_fishing(_intent(), _actor, milliseconds)
	refresh()

func reset_after_load() -> void:
	_pending = 0
	refresh()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		flush_progress()
		_suspended = true
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]: _suspended = false

func refresh() -> void:
	if _status == null: return
	var record := _model.fishing.attempt(_model.session.snapshot(), _actor)
	if record.is_empty():
		_status.text = str(_model.fishing.spots().get(_spot, {}).get("label", "Fishing")) + "\nApproach a fishing spot and Use nearby. Choose bait, cast, then reel when the float bites. Bait is spent even on a miss."
		return
	var spot: Dictionary = _model.fishing.spots()[record.spot_id]
	_bar.max_value = spot.bite_ms + spot.window_ms
	_bar.value = record.elapsed_ms
	var instruction: String = {"waiting": "REEL NOW" if record.elapsed_ms >= spot.bite_ms else "Watch the float…", "ready": "Catch held: make room, then collect here.", "caught": "Caught " + _model.inventory.item_definition(record.fish).label, "missed": "The fish escaped. Try again with another bait.", "cancelled": "Line put away; bait was spent."}[record.status]
	_status.text = spot.label + "\n" + instruction
