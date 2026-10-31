class_name HousingPanel
extends VBoxContainer
## Tap furnishing, tap an authored space, preview, then confirm. No drag precision.
signal preview_changed(property_id: String, cell_id: String, valid: bool)
var _model: GameplayModel
var _actor: String
var _prepare: Callable
var _sync: Callable
var _property: OptionButton
var _furnishing: OptionButton
var _cell: OptionButton
var _status: Label
var _preview: Label
var _feedback: Label
var _acquire: Button
var _place: Button
var _pack: Button

func configure(model: GameplayModel, actor: String, prepare: Callable, sync: Callable) -> void:
	_model = model
	_actor = actor
	_prepare = prepare
	_sync = sync
	add_theme_constant_override("separation", 8)
	_status = _label("Housing & belongings")
	_property = _option("HousingProperty")
	for id in _model.housing.properties():
		_property.add_item(_model.housing.properties()[id].label)
		_property.set_item_metadata(_property.item_count - 1, id)
	_property.item_selected.connect(func(_index): _rebuild_cells(); refresh())
	_acquire = _button("AcquireHousing", "", _get_access)
	_label("Start in the stable workshop. Approach the merchant to arrange optional access; use each room's courtyard door.")
	_furnishing = _option("HousingFurnishing")
	for id in _model.housing.furnishings():
		if _model.housing.furnishings()[id].owner_id != actor: continue
		_furnishing.add_item(_model.housing.furnishings()[id].label)
		_furnishing.set_item_metadata(_furnishing.item_count - 1, id)
	_furnishing.item_selected.connect(func(_index): refresh())
	_cell = _option("HousingCell")
	_cell.item_selected.connect(func(_index): refresh())
	_preview = _label("")
	_preview.name = "HousingPreview"
	_place = _button("ConfirmPlacement", "Confirm placement", _confirm)
	_pack = _button("PackFurnishing", "Pack selected furnishing", _pack_selected)
	_feedback = _label("Packed furniture keeps its identity and chest contents. It cannot be used until placed. Approach placed furniture before packing or moving it.")
	_feedback.name = "HousingFeedback"
	_rebuild_cells()
	refresh()

func _option(id: String) -> OptionButton:
	var option := OptionButton.new()
	option.name = id
	option.custom_minimum_size = Vector2(300, 48)
	add_child(option)
	return option

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 300
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label

func _button(id: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.custom_minimum_size = Vector2(300, 52)
	button.pressed.connect(action)
	add_child(button)
	return button

func _selected(option: OptionButton) -> String:
	return option.get_item_metadata(option.selected) if option.selected >= 0 else ""

func _rebuild_cells() -> void:
	if _cell == null: return
	_cell.clear()
	var property: Dictionary = _model.housing.properties()[_selected(_property)]
	var index := 1
	for id in property.cells:
		var cell: Dictionary = property.cells[id]
		_cell.add_item("Space %d · (%d, %d)" % [index, cell.x, cell.y])
		_cell.set_item_metadata(_cell.item_count - 1, id)
		index += 1

func refresh() -> void:
	if _cell == null: return
	var snapshot := _model.session.snapshot()
	var property_id := _selected(_property)
	var property: Dictionary = _model.housing.properties()[property_id]
	var owned := _model.housing.can_access(snapshot, _actor, property_id)
	_status.text = "%s\n%s · %d coins in purse" % [property.label, "Access granted" if owned else "Access not arranged", _model.wallet(_actor)]
	_acquire.text = "Arrange access · %d coins" % property.price
	_acquire.disabled = snapshot.domains.housing.residents[property_id] != ""
	var id := _selected(_furnishing)
	var placement: Dictionary = snapshot.domains.housing.placements[id]
	var location: String = "packed" if placement.property_id == "" else _model.housing.properties()[placement.property_id].label + " / " + placement.cell_id
	var error := _model.housing.placement_error(snapshot, _actor, id, property_id, _selected(_cell))
	_preview.text = "Selected: %s\nCurrently: %s\nPreview: %s" % [_model.housing.furnishings()[id].label, location, "Space available — confirm to place" if error == "" else error.replace("_", " ")]
	_place.disabled = error != ""
	_pack.disabled = not _model.housing.usable(snapshot, _actor, id)
	preview_changed.emit(property_id, _selected(_cell), error == "")

func _intent() -> String:
	return "housing:%d" % _model.session.snapshot().revision

func _finish(result: OperationResult) -> void:
	_feedback.text = "Done. Furniture identity and contents preserved." if result.ok else result.code.replace("_", " ")
	if result.ok: _sync.call()
	refresh()

func _get_access() -> void:
	var prepared: OperationResult = _prepare.call()
	if not prepared.ok: _finish(prepared); return
	_finish(_model.acquire_housing(_intent(), _actor, _selected(_property)))

func _confirm() -> void:
	var prepared: OperationResult = _prepare.call()
	if not prepared.ok: _finish(prepared); return
	_finish(_model.place_furnishing(_intent(), _actor, _selected(_furnishing), _selected(_property), _selected(_cell)))

func _pack_selected() -> void:
	var prepared: OperationResult = _prepare.call()
	if not prepared.ok: _finish(prepared); return
	_finish(_model.pack_furnishing(_intent(), _actor, _selected(_furnishing)))
