class_name FarmingPanel
extends VBoxContainer
## Touch-sized cultivation controls; growth is reconciled from WorldClock time.

const BUTTON_HEIGHT: float = 52.0
var _model: GameplayModel
var _actor: String
var _prepare: Callable
var _plot: OptionButton
var _crop: OptionButton
var _status: Label
var _plant: Button
var _water: Button
var _harvest: Button
var _clear: Button

func configure(model: GameplayModel, actor: String, prepare: Callable) -> void:
	_model = model
	_actor = actor
	_prepare = prepare
	add_theme_constant_override("separation", 10)
	_status = Label.new()
	_status.name = "FarmingStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 300
	add_child(_status)
	_plot = OptionButton.new()
	_plot.name = "FarmingPlot"
	_plot.custom_minimum_size.y = 48
	var plot_ids := model.farming.plots().keys()
	plot_ids.sort()
	for id in plot_ids:
		_plot.add_item(model.farming.plots()[id].label)
		_plot.set_item_metadata(_plot.item_count - 1, id)
	_plot.item_selected.connect(_on_changed)
	add_child(_plot)
	_crop = OptionButton.new()
	_crop.name = "FarmingCrop"
	_crop.custom_minimum_size.y = 48
	var crop_ids := model.farming.crops().keys()
	crop_ids.sort()
	for id in crop_ids:
		_crop.add_item(model.farming.crops()[id].label)
		_crop.set_item_metadata(_crop.item_count - 1, id)
	_crop.item_selected.connect(_on_changed)
	add_child(_crop)
	_plant = _button("PlantCrop", "Plant · spend one seed", _plant_crop)
	_water = _button("WaterCrop", "Water plot", _water_crop)
	_harvest = _button("HarvestCrop", "Harvest / collect produce", _harvest_crop)
	_clear = _button("ClearPlot", "Clear / uproot plot", _clear_plot)
	refresh()

func _button(id: String, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = label
	button.custom_minimum_size = Vector2(300, BUTTON_HEIGHT)
	button.pressed.connect(callback)
	add_child(button)
	return button

func open(plot_id: String) -> void:
	for index in _plot.item_count:
		if _plot.get_item_metadata(index) == plot_id:
			_plot.select(index)
			break
	refresh()

func _on_changed(_index: int) -> void:
	refresh()

func _plot_id() -> String:
	return _plot.get_item_metadata(_plot.selected) if _plot != null and _plot.item_count > 0 else ""

func _crop_id() -> String:
	return _crop.get_item_metadata(_crop.selected) if _crop != null and _crop.item_count > 0 else ""

func _intent(prefix: String) -> String:
	return "%s:%d" % [prefix, _model.session.snapshot().revision]

func _ready_action() -> bool:
	var result: OperationResult = _prepare.call()
	if not result.ok: _status.text = result.code.replace("_", " ")
	return result.ok

func _plant_crop() -> void:
	if not _ready_action(): return
	var result := _model.plant_crop(_intent("plant"), _actor, _plot_id(), _crop_id())
	refresh()
	if not result.ok: _status.text = _explain(result.code)

func _water_crop() -> void:
	if not _ready_action(): return
	var result := _model.water_crop(_intent("water"), _actor, _plot_id())
	refresh()
	if not result.ok: _status.text = _explain(result.code)

func _harvest_crop() -> void:
	if not _ready_action(): return
	var result := _model.harvest_crop(_intent("harvest"), _actor, _plot_id())
	refresh()
	if not result.ok: _status.text = _explain(result.code)

func _clear_plot() -> void:
	if not _ready_action(): return
	var result := _model.clear_plot(_intent("clear"), _actor, _plot_id())
	refresh()
	if not result.ok: _status.text = _explain(result.code)

func _explain(code: String) -> String:
	return {
		"incompatible_environment": "Cannot grow here: this seed requires a different environment. Your seed stays in your bag.",
		"unsuitable_soil": "Cannot grow here: this soil is unsuitable for the selected crop. Your seed stays in your bag.",
		"skill_required_for_soil": "This suboptimal soil requires more cultivation experience before planting.",
		"access_denied": "You do not have permission to cultivate this plot.",
		"out_of_reach": "Walk closer to the selected plot.",
		"different_region": "Travel to the region where this plot is located.",
		"already_watered_recently": "Soil is still moist; wait before watering again.",
		"watering_complete": "This crop has already received enough water.",
		"watering_required": "Growth time has passed, but the crop still needs watering care.",
		"crop_not_ripe": "The crop is still growing in world time.",
		"insufficient_available_goods": "You need an unreserved seed in your bag to plant."
	}.get(code, code.replace("_", " "))

func refresh() -> void:
	if _status == null or _plot.item_count == 0: return
	var snapshot := _model.session.snapshot()
	var plot_id := _plot_id()
	var plot: Dictionary = _model.farming.plots()[plot_id]
	var actor_skill := _model.farming.skill(snapshot, _actor)
	var projected := _model.farming.projection(snapshot, plot_id)
	var permitted := _model.farming.can_access(_actor, plot_id)
	if projected.is_empty():
		var crop_id := _crop_id()
		var crop: Dictionary = _model.farming.crops()[crop_id]
		var effective := _model.farming.effective_rules(crop_id, actor_skill)
		var compat := _model.farming.compatibility_error(plot_id, crop_id, actor_skill)
		var seed_label: String = _model.inventory.item_definition(crop.seed).label
		var fit := "Compatible plot" if compat.is_empty() else _explain(compat)
		_status.text = "%s (%s · %s soil)\nCultivation skill: %d / %d\n%s · Seed: %s · %d waterings · %d world min\n%s" % [
			plot.label, plot.environment, plot.soil, actor_skill, _model.farming.max_skill(),
			crop.label, seed_label, effective.required_waterings, effective.growth_minutes,
			fit if permitted else "Private plot (no permission)"
		]
		_plant.disabled = not permitted
		_water.disabled = true
		_harvest.disabled = true
		_clear.disabled = true
		return
	var stage_text: String = {
		"growing": "Growing · next water in %d world min" % projected.next_water_in if projected.waterings_done < projected.waterings_needed else "Growing · %d world min remaining" % projected.remaining_minutes,
		"needs_water": "NEEDS WATER · ready for care (%d / %d)" % [projected.waterings_done, projected.waterings_needed],
		"parched": "PARCHED · time elapsed, needs water (%d / %d)" % [projected.waterings_done, projected.waterings_needed],
		"ripe": "RIPE TO HARVEST",
		"ready": "HARVEST HELD · make room in bag, then collect here"
	}[projected.stage]
	_status.text = "%s (%s · %s soil)\nCultivation skill: %d / %d\n%s · %s\nElapsed: %d / %d world min · Water: %d / %d" % [
		plot.label, plot.environment, plot.soil, actor_skill, _model.farming.max_skill(),
		projected.label, stage_text, projected.elapsed_minutes, projected.growth_minutes,
		projected.waterings_done, projected.waterings_needed
	]
	_plant.disabled = true
	_water.disabled = not permitted or not projected.can_water
	_harvest.disabled = not permitted or not projected.ripe
	_clear.disabled = not permitted
