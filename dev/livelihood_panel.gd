class_name LivelihoodPanel
extends VBoxContainer
## Disposable job journal and active craft UI; rules remain in their domains.

signal message(text: String)

const PROGRESS_STEP: float = 0.25
const BUTTON_HEIGHT: float = 48.0
var _model: GameplayModel
var _actor: String
var _labels: Dictionary
var _prepare: Callable
var _visual_position: Callable
var _offers: OptionButton
var _recipes: OptionButton
var _job_text: Label
var _craft_text: Label
var _progress: ProgressBar
var _notice: Label
var _accept: Button
var _deliver: Button
var _abandon: Button
var _start: Button
var _cancel: Button
var _collect: Button
var _pending_seconds: float = 0.0
var _pending_job: String = ""
var _suspended: bool = false

func configure(model: GameplayModel, actor: String, labels: Dictionary, prepare: Callable, visual_position: Callable) -> void:
	_model = model
	_actor = actor
	_labels = labels.duplicate()
	_prepare = prepare
	_visual_position = visual_position
	add_theme_constant_override("separation", 10)
	_label("Optional deliveries", 20)
	_offers = OptionButton.new()
	_offers.name = "JobOffer"
	_offers.custom_minimum_size.y = BUTTON_HEIGHT
	add_child(_offers)
	var offers := model.work.definitions()
	var ids := offers.keys()
	ids.sort()
	for id in ids:
		_offers.add_item(offers[id].label)
		_offers.set_item_metadata(_offers.item_count - 1, id)
	_offers.item_selected.connect(_selection_changed)
	_job_text = _label("", 16)
	_job_text.name = "JobSummary"
	_accept = _button("AcceptJob", "Accept near giver", _accept_job)
	_deliver = _button("DeliverJob", "Deliver near recipient", _deliver_job)
	_abandon = _button("CancelJob", "Abandon job / release reward", _cancel_job)
	_label("Active preparation", 20)
	_recipes = OptionButton.new()
	_recipes.name = "Recipe"
	_recipes.custom_minimum_size.y = BUTTON_HEIGHT
	add_child(_recipes)
	var definitions := model.crafting.recipes()
	ids = definitions.keys()
	ids.sort()
	for id in ids:
		_recipes.add_item(definitions[id].label)
		_recipes.set_item_metadata(_recipes.item_count - 1, id)
	_recipes.item_selected.connect(_selection_changed)
	_craft_text = _label("", 16)
	_craft_text.name = "CraftSummary"
	_progress = ProgressBar.new()
	_progress.name = "CraftProgress"
	_progress.custom_minimum_size.y = 24
	add_child(_progress)
	_start = _button("StartCraft", "Start at preparation bench", _start_craft)
	_collect = _button("CollectCraft", "Collect ready output", _collect_craft)
	_cancel = _button("CancelCraft", "Cancel / release ingredients", _cancel_craft)
	_notice = _label("Jobs are optional. Their rewards are reserved when accepted.", 16)
	_notice.name = "WorkNotice"
	refresh()

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 300
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label

func _button(id: String, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.custom_minimum_size.y = BUTTON_HEIGHT
	button.pressed.connect(callback)
	add_child(button)
	return button

func _intent(prefix: String) -> String:
	return "%s:%d" % [prefix, _model.session.snapshot().revision]

func _selection_changed(_index: int) -> void:
	refresh()

func _offer_id() -> String:
	return _offers.get_item_metadata(_offers.selected)

func _report(result: OperationResult, success: String) -> void:
	_notice.text = success if result.ok else result.code.replace("_", " ")
	message.emit(_notice.text)
	refresh()

func _ready_action() -> bool:
	var result: OperationResult = _prepare.call()
	if result.ok: return true
	_report(result, "")
	return false

func _accept_job() -> void:
	if _ready_action(): _report(_model.accept_job(_intent("accept"), _actor, _offer_id()), "Job accepted; payment reserved.")

func _deliver_job() -> void:
	if _ready_action(): _report(_model.deliver_job(_intent("deliver"), _actor, _offer_id()), "Goods delivered and payment received.")

func _cancel_job() -> void:
	if _ready_action(): _report(_model.cancel_job(_intent("abandon"), _actor, _offer_id()), "Job abandoned; reward returned to its giver.")

func _start_craft() -> void:
	if not _ready_action(): return
	var nearest: String = ""
	var distance: float = INF
	for station in _model.crafting.station_ids():
		if _model.session.snapshot().entities[station].region_id != _model.actor_region(_actor): continue
		var separation := _model.position_of(_actor).distance_to(_model.position_of(station))
		if separation < distance:
			nearest = station
			distance = separation
	_report(_model.start_craft(_intent("craft"), _actor, _recipes.get_item_metadata(_recipes.selected), nearest), "Preparation started; ingredients reserved.")

func _collect_craft() -> void:
	if _ready_action(): _report(_model.collect_craft(_intent("collect-craft"), _actor), "Finished goods collected.")

func _cancel_craft() -> void:
	if _ready_action(): _report(_model.cancel_craft(_intent("cancel-craft"), _actor), "Preparation cancelled; ingredients available again.")

func _can_work(job: Dictionary) -> bool:
	if job.is_empty() or job.status != "working": return false
	var snapshot := _model.session.snapshot()
	if snapshot.entities[_actor].region_id != snapshot.entities[job.station_id].region_id: return false
	var at := _model.position_of(job.station_id)
	var visual: Vector2 = _visual_position.call()
	return _model.interactions.geometry_for(_model.actor_region(_actor)).clear_segment(visual, at) and at.distance_to(visual) <= _model.interactions.reach() and at.distance_to(_model.position_of(_actor)) <= _model.interactions.reach()

func _process(delta: float) -> void:
	if _model == null or _model.session.is_closed() or _suspended: return
	var job := _model.crafting.active_job(_model.session.snapshot(), _actor)
	if job.is_empty() or job.id != _pending_job:
		_pending_seconds = 0
		_pending_job = job.get("id", "")
	if not _can_work(job):
		flush_progress()
		return
	_pending_seconds += delta
	if _pending_seconds >= PROGRESS_STEP: flush_progress()
	elif _progress != null: _progress.value = float(job.elapsed) + _pending_seconds

func flush_progress() -> void:
	if _model == null or _model.session.is_closed() or _pending_seconds <= 0: return
	var seconds: float = _pending_seconds
	_pending_seconds = 0
	var current := _model.crafting.active_job(_model.session.snapshot(), _actor)
	if current.is_empty() or current.id != _pending_job or current.status != "working": return
	var result := _model.progress_craft(_intent("craft-progress"), _actor, seconds)
	if not result.ok:
		_notice.text = "Preparation paused: " + result.code.replace("_", " ")
		return
	if _model.crafting.active_job(_model.session.snapshot(), _actor).is_empty():
		_notice.text = "Preparation finished; goods added to your bag."

func reset_after_load() -> void:
	_pending_seconds = 0
	_pending_job = ""
	refresh()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		flush_progress()
		_suspended = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		_suspended = false

func refresh() -> void:
	if _job_text == null: return
	var snapshot := _model.session.snapshot()
	if _offers.item_count > 0:
		var definition: Dictionary = _model.work.definitions()[_offer_id()]
		var job := _model.work.job_for(snapshot, _actor, _offer_id())
		var status: String = job.get("status", "offered")
		_job_text.text = "%s → %s\n%s\nReward: %d coins · %s" % [_labels.get(definition.giver_id, definition.giver_id), _labels.get(definition.recipient_id, definition.recipient_id), _goods(definition.requirements), definition.reward, status]
		if status == "accepted": _job_text.text += "\nDue in %d world minutes" % (job.deadline - snapshot.minute)
		_accept.disabled = not job.is_empty()
		_deliver.disabled = status != "accepted"
		_abandon.disabled = status != "accepted"
	else:
		_job_text.text = "No job offers in this content."
		_accept.disabled = true
		_deliver.disabled = true
		_abandon.disabled = true
	var active := _model.crafting.active_job(snapshot, _actor)
	_start.disabled = _recipes.item_count == 0 or not active.is_empty()
	_cancel.disabled = active.is_empty()
	_collect.disabled = active.is_empty() or active.get("status") != "ready"
	if not active.is_empty():
		var recipe: Dictionary = _model.crafting.recipes()[active.recipe_id]
		_progress.max_value = recipe.duration_seconds
		_progress.value = active.elapsed
		_craft_text.text = "%s · %.1f / %.1f active seconds\n%s" % [active.status, active.elapsed, recipe.duration_seconds, "Stay near the bench to work." if active.status == "working" else "Make room, then collect, or cancel."]
	elif _recipes.item_count > 0:
		var recipe: Dictionary = _model.crafting.recipes()[_recipes.get_item_metadata(_recipes.selected)]
		_craft_text.text = "%s → %s\n%.1f active seconds; leaving pauses work." % [_goods(recipe.ingredients), _goods(recipe.outputs), recipe.duration_seconds]
		_progress.value = 0
	else:
		_craft_text.text = "No preparation recipes in this content."

func _goods(goods: Dictionary) -> String:
	var parts: PackedStringArray = []
	for item in goods: parts.append("%d %s" % [goods[item], _model.inventory.item_definition(item).label])
	return ", ".join(parts)
