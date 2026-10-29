class_name GameplayPlayground
extends Control
## Disposable player-facing adapter. All gameplay mutations go through the model.

signal session_changed(candidate: GameSession)

const FIXTURE: String = "res://dev/fixtures/linked_world.json"
const RECOVERY: String = "user://connected-gameplay-playground"
const ACTION_HEIGHT: float = 48.0
var _model: GameplayModel
var _data: Dictionary
var _actor: String
var _store: RecoveryStore
var _bound: GameSession
var _map: PlaygroundMap
var _targets: OptionButton
var _items: OptionButton
var _quantity: SpinBox
var _status: Label
var _bag: Label
var _stock: Label
var _prices: Label
var _buttons: Dictionary = {}
var _livelihood: LivelihoodPanel
var _clock: Label
var _tabs: TabContainer

func initialize(directory: String = RECOVERY) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not parsed is Dictionary: return false
	_data = parsed
	_model = GameplayModel.create(_data, "world.playground")
	if _model == null: return false
	_actor = _data.presentation.player_id
	_store = RecoveryStore.new(directory)
	return true

func model() -> GameplayModel:
	return _model

func _ready() -> void:
	if _model == null and not initialize():
		push_error("Invalid disposable gameplay fixture")
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("101e22")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_label(column, "Behind the Lanterns  /  working world prototype", 23)
	_label(column, "Walk or tap the map. Collect supplies, accept a job, prepare goods, then find the recipient.", 16)
	var time_row := HBoxContainer.new()
	column.add_child(time_row)
	_clock = _label(time_row, "", 18)
	_clock.name = "WorldTime"
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(time_row, "Wait1h", _wait.bind(60))
	_button(time_row, "Wait6h", _wait.bind(360))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	_map = PlaygroundMap.new()
	_map.name = "WorldMap"
	_map.custom_minimum_size = Vector2(540, 370)
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_map)
	_map.configure(_model, _actor, _data.presentation.labels, _data.presentation.walk_speed)
	_map.target_selected.connect(_select_target)
	_map.stopped.connect(_on_stopped)
	_map.use_requested.connect(_use_target)
	_map.feedback.connect(_show_message)
	var use_button := _button(time_row, "Use nearby", _use_nearby)
	use_button.tooltip_text = "E or tap: use the closest unobstructed object"
	var tabs := TabContainer.new()
	_tabs = tabs
	tabs.name = "SidebarTabs"
	tabs.custom_minimum_size.x = 350
	row.add_child(tabs)
	var side_scroll := ScrollContainer.new()
	side_scroll.name = "Goods"
	side_scroll.size_flags_horizontal = Control.SIZE_FILL
	tabs.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	side_scroll.add_child(side)
	_label(side, "Nearby holder", 18)
	_targets = OptionButton.new()
	_targets.name = "Target"
	_targets.custom_minimum_size.y = ACTION_HEIGHT
	side.add_child(_targets)
	var ids := _model.interactions.target_ids()
	ids.sort()
	for id in ids:
		if id == _actor: continue
		_targets.add_item(_data.presentation.labels.get(id, id))
		_targets.set_item_metadata(_targets.item_count - 1, id)
	_targets.item_selected.connect(_on_selection_changed)
	_stock = _label(side, "", 16)
	_stock.name = "StockSummary"
	_items = OptionButton.new()
	_items.name = "Item"
	_items.custom_minimum_size.y = ACTION_HEIGHT
	for id in _model.inventory.item_ids():
		_items.add_item(_model.inventory.item_definition(id).label)
		_items.set_item_metadata(_items.item_count - 1, id)
	side.add_child(_items)
	_items.item_selected.connect(_on_selection_changed)
	_quantity = SpinBox.new()
	_quantity.name = "Quantity"
	_quantity.min_value = 1
	_quantity.max_value = WorldData.MAX_COUNTER
	_quantity.step = 1
	_quantity.value = 1
	_quantity.custom_minimum_size.y = ACTION_HEIGHT
	side.add_child(_quantity)
	_prices = _label(side, "", 16)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	side.add_child(grid)
	for verb in ["take", "store", "buy", "sell"]:
		var button := _button(grid, verb.capitalize(), _act.bind(verb))
		_buttons[verb] = button
	_bag = _label(side, "", 17)
	_bag.name = "BagSummary"
	var saves := HBoxContainer.new()
	side.add_child(saves)
	_button(saves, "Save", _save)
	_button(saves, "Load", _load)
	_status = _label(side, "Walk near an object to use it. Native saves only in this increment.", 16)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 300
	var work_scroll := ScrollContainer.new()
	work_scroll.name = "Work and craft"
	tabs.add_child(work_scroll)
	_livelihood = LivelihoodPanel.new()
	_livelihood.name = "Livelihood"
	_livelihood.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work_scroll.add_child(_livelihood)
	_livelihood.configure(_model, _actor, _data.presentation.labels, _prepare_action, _map.visual_position)
	_livelihood.message.connect(_show_message)
	_model.session_replaced.connect(_on_replaced)
	_bind(_model.session)
	_select_target("a:supplies") # Disposable fixture selection, never a rule assumption.
	_map.grab_focus()
	session_changed.emit(_model.session)

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e4e5d8"))
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = text
	button.text = text
	button.custom_minimum_size = Vector2(140, ACTION_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _target() -> String:
	return _targets.get_item_metadata(_targets.selected)

func _item() -> String:
	return _items.get_item_metadata(_items.selected)

func _select_target(id: String) -> void:
	for index in _targets.item_count:
		if _targets.get_item_metadata(index) == id: _targets.select(index)
	_on_selection_changed(0)

func _on_selection_changed(_index: int) -> void:
	_map.selected_target = _target()
	_refresh(0)

func _bind(candidate: GameSession) -> void:
	if _bound != null: _bound.committed.disconnect(_refresh)
	_bound = candidate
	_bound.committed.connect(_refresh)
	_refresh(0)

func _on_replaced(candidate: GameSession) -> void:
	_livelihood.reset_after_load()
	_bind(candidate)
	_map.sync_position()
	session_changed.emit(candidate)

func _intent(prefix: String) -> String:
	return "%s:%d" % [prefix, _model.session.snapshot().revision]

func _commit_position() -> OperationResult:
	_map.halt()
	var point := _map.visual_position()
	if point.is_equal_approx(_model.position_of(_actor)): return OperationResult.success()
	return _model.move_actor(_intent("walk"), _actor, point.x, point.y)

func _prepare_action() -> OperationResult:
	_livelihood.flush_progress()
	return _commit_position()

func _show_message(text: String) -> void:
	_status.text = text

func _wait(minutes: int) -> void:
	var position_result := _prepare_action()
	if not position_result.ok:
		_status.text = position_result.code
		return
	var result := _model.wait_minutes(_intent("wait"), _actor, minutes)
	_status.text = "Waited %d world minutes." % minutes if result.ok else _message(result.code)

func _on_stopped(_point: Vector2) -> void:
	var result := _prepare_action()
	if not result.ok: _status.text = result.code
	_refresh(0)

func _act(verb: String) -> void:
	var movement := _prepare_action()
	if not movement.ok:
		_status.text = movement.code
		return
	var price := _model.commerce.quote(_target(), _item(), verb == "buy")
	var outcome := _model.act(_intent(verb), _actor, _target(), _item(), int(_quantity.value), verb, price)
	_status.text = "%s: %d %s" % [verb.capitalize(), int(_quantity.value), _model.inventory.item_definition(_item()).label] if outcome.ok else _message(outcome.code)

func _save() -> void:
	var movement := _prepare_action()
	if not movement.ok:
		_status.text = movement.code
		return
	var result := _store.save(_model.session)
	_status.text = "Saved this world's goods, money and position." if result.ok else "Save failed: " + result.code

func _load() -> void:
	var candidate := _store.load_candidate(_model.session)
	if candidate == null or not _model.adopt(candidate):
		_status.text = "Load failed: " + _store.last_error
		return
	_status.text = "Loaded the last valid save."

func _refresh(_revision: int) -> void:
	if _targets == null or _targets.item_count == 0 or _bag == null: return
	var snapshot := _model.session.snapshot()
	var bag := _model.inventory.contents(snapshot, _actor)
	var available := _model.inventory.available_contents(snapshot, _actor)
	var target_goods := _model.inventory.contents(snapshot, _target())
	_bag.text = "Your bag  %d / %d slots\n%s\nCoins: %d" % [_model.inventory.slots_used(bag), _model.inventory.container_definition(_actor).slots, _goods_text(bag), _model.wallet(_actor)]
	if available != bag: _bag.text += "\nAvailable (others reserved):\n" + _goods_text(available)
	_stock.text = _goods_text(target_goods)
	var shop := _model.commerce.is_shop(_target())
	_prices.text = "Buy: %d / Sell: %d coins each\nMerchant coins: %d" % [_model.commerce.quote(_target(), _item(), true), _model.commerce.quote(_target(), _item(), false), _model.wallet(_target())] if shop else "Private storage" if not _model.inventory.can_access(_actor, _target()) else "Transfer goods (no payment)"
	if _target() in _model.crafting.station_ids():
		_stock.text = "Preparation bench\nUse the Work and craft tab."
		_prices.text = "Active preparation; no offline waiting."
	var npc := _model.npcs.projection(_target(), snapshot.minute)
	if not npc.is_empty(): _prices.text += "\n" + npc.activity + ("" if npc.available else " (unavailable)")
	for verb in _buttons:
		_buttons[verb].disabled = not shop or not _model.interactions.available(_target(), snapshot.minute) if verb in ["buy", "sell"] else not _model.inventory.can_access(_actor, _target())
	_clock.text = _region_label() + " · " + "Day %d · %02d:%02d" % [int(snapshot.minute / WorldClock.MINUTES_PER_DAY) + 1, int(snapshot.minute / 60) % 24, int(snapshot.minute) % 60]
	_livelihood.refresh()
	_map.queue_redraw()

func _goods_text(goods: Dictionary) -> String:
	var lines: PackedStringArray = []
	for id in _model.inventory.item_ids():
		if goods.has(id): lines.append("%s: %d" % [_model.inventory.item_definition(id).label, goods[id]])
	return "Empty" if lines.is_empty() else "\n".join(lines)

func _message(code: String) -> String:
	return {"out_of_reach": "Walk closer to the selected holder.", "access_denied": "You do not have permission to use this holder.", "container_full": "Not enough room in the destination.", "insufficient_available_goods": "Not enough unreserved goods.", "insufficient_funds": "The buyer does not have enough coins.", "person_unavailable": "They are not available at this time.", "quote_changed": "The price no longer matches."}.get(code, code)

func _exit_tree() -> void:
	if _bound != null: _bound.committed.disconnect(_refresh)
	if _model != null:
		_model.session_replaced.disconnect(_on_replaced)
		_model.session.close()

func _use_nearby() -> void:
	_map.use_nearby()

func _use_target(id: String) -> void:
	var result := _prepare_action()
	if not result.ok:
		_show_message(result.code)
		return
	if _model.interactions.is_portal(id):
		result = _model.enter(_intent("enter"), _actor, id)
		if result.ok:
			_map.sync_position()
			_show_message("Entered " + _region_label())
		else: _show_message(result.code)
		return
	_select_target(id)
	_tabs.current_tab = 1 if id in _model.crafting.station_ids() or not _model.npcs.projection(id, _model.session.now()).is_empty() else 0
	_show_message("Using " + str(_data.presentation.labels.get(id, id)) + ". Choose an action; goods and payments require confirmation.")

func _region_label() -> String:
	var region := _model.actor_region(_actor)
	return _data.presentation.get("region_labels", {}).get(region, region)
