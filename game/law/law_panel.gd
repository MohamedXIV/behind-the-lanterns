class_name LawPanel
extends VBoxContainer
## Player-facing Watch & Legal Status panel: displays current legal standing,
## pursuit cooldown or watchhouse sentence, and contextual evasion, persuasion,
## fine settlement, or sentence-serving controls.

const ACTION_HEIGHT: float = 48.0

var _model: GameplayModel
var _actor: String
var _prepare: Callable
var _sync_view: Callable
var _status_label: Label
var _feedback_label: Label
var _tamper_btn: Button
var _evade_btn: Button
var _persuade_btn: Button
var _pay_fine_btn: Button
var _surrender_btn: Button
var _serve_btn: Button
var _confront_btn: Button
var _selected_target: String = ""

func configure(model: GameplayModel, actor: String, prepare: Callable, sync_view: Callable = Callable()) -> void:
	_model = model
	_actor = actor
	_prepare = prepare
	_sync_view = sync_view
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label = _add_label("Legal standing: Clear", 16)
	_status_label.name = "LawStatus"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)

	_tamper_btn = _add_button(grid, "TamperRestricted", "Tamper", _on_tamper)
	_evade_btn = _add_button(grid, "EvadePursuit", "Hide / Evade", _on_evade)
	_persuade_btn = _add_button(grid, "PersuadeGuard", "Persuade", _on_persuade)
	_pay_fine_btn = _add_button(grid, "PayFine", "Pay Fine", _on_pay_fine)
	_surrender_btn = _add_button(grid, "SurrenderGuard", "Surrender", _on_surrender)
	_serve_btn = _add_button(grid, "ServeSentence", "Serve Time", _on_serve_sentence)
	_confront_btn = _add_button(grid, "ConfrontGuard", "Strike Guard", _on_confront_guard)

	_feedback_label = _add_label("Guards are never ordinary combat targets. Attacking a guard triggers scripted arrest.", 15)
	_feedback_label.name = "LawFeedback"
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refresh()

func open(target_id: String) -> void:
	_selected_target = target_id
	refresh()

func refresh() -> void:
	if _model == null or _model.law == null or _status_label == null: return
	var snapshot := _model.session.snapshot()
	var record := _model.law.status_of(snapshot, _actor)
	var remaining: int = maxi(0, record.until_minute - snapshot.minute) if record.status != "clear" else 0
	if record.status == "clear":
		_status_label.text = "Standing: CLEAR · Prior offenses: %d\nGuards keep watch during duty hours." % record.offense_count
	elif record.status == "pursued":
		_status_label.text = "Standing: PURSUED (%s) · Cooldown: %d min\nFine: %d coins · Prior offenses: %d\nReach a concealing refuge to hide, wait out cooldown, or speak to a guard." % [record.offense, remaining, record.fine, record.offense_count]
	else:
		_status_label.text = "Standing: DETAINED in Watchhouse (%s)\nSentence remaining: %d min · Fine: %d coins · Offenses: %d\nYou can walk around, talk to detainees, pay your fine, or serve the remaining time." % [record.offense, remaining, record.fine, record.offense_count]

	var is_pursued: bool = record.status == "pursued"
	var is_detained: bool = record.status == "detained"
	_tamper_btn.disabled = is_detained or not _model.law.restricted_targets().has(_selected_target)
	_evade_btn.disabled = not is_pursued or not _model.law.refuges().has(_selected_target)
	_persuade_btn.disabled = not is_pursued or not _model.law.is_guard(_selected_target)
	_pay_fine_btn.disabled = not (is_pursued or is_detained) or not _model.law.is_guard(_selected_target)
	_surrender_btn.disabled = not is_pursued or not _model.law.is_guard(_selected_target)
	_serve_btn.disabled = not is_detained
	_confront_btn.disabled = not _model.law.is_guard(_selected_target)

func _intent(prefix: String) -> String:
	return "%s:%d" % [prefix, _model.session.snapshot().revision]

func _on_tamper() -> void:
	if not _prepare_ok(): return
	var res := _model.tamper_restricted(_intent("law-tamper"), _actor, _selected_target)
	if res.ok:
		var status: String = _model.law.status_of(_model.session.snapshot(), _actor).status
		if status == "detained" and _sync_view.is_valid(): _sync_view.call()
		_feedback_label.text = "Second witnessed offense escalated to immediate arrest!" if status == "detained" else "Witnessed tampering! You are now pursued by the watch."
	else:
		_feedback_label.text = _message(res.code)
	refresh()

func _on_evade() -> void:
	if not _prepare_ok(): return
	var res := _model.evade_pursuit(_intent("law-evade"), _actor, _selected_target)
	_feedback_label.text = "Concealed in refuge until pursuit cooled down." if res.ok else _message(res.code)
	refresh()

func _on_persuade() -> void:
	if not _prepare_ok(): return
	var res := _model.persuade_guard(_intent("law-persuade"), _actor, _selected_target)
	_feedback_label.text = "Your local reputation vouched for you; the watchman cleared the pursuit." if res.ok else _message(res.code)
	refresh()

func _on_pay_fine() -> void:
	if not _prepare_ok(): return
	var res := _model.pay_fine(_intent("law-fine"), _actor, _selected_target)
	if res.ok and _sync_view.is_valid(): _sync_view.call()
	_feedback_label.text = "Paid fine to the watch; legal standing is now clear." if res.ok else _message(res.code)
	refresh()

func _on_surrender() -> void:
	if not _prepare_ok(): return
	var res := _model.surrender_to_guard(_intent("law-surrender"), _actor, _selected_target)
	if res.ok and _sync_view.is_valid(): _sync_view.call()
	_feedback_label.text = "Surrendered to the watchman and escorted to the watchhouse." if res.ok else _message(res.code)
	refresh()

func _on_serve_sentence() -> void:
	if not _prepare_ok(): return
	var res := _model.serve_sentence(_intent("law-serve"), _actor)
	if res.ok and _sync_view.is_valid(): _sync_view.call()
	_feedback_label.text = "Served watchhouse sentence and returned to the courtyard." if res.ok else _message(res.code)
	refresh()

func _on_confront_guard() -> void:
	if not _prepare_ok(): return
	var res := _model.confront_guard(_intent("law-confront"), _actor, _selected_target)
	if res.ok and _sync_view.is_valid(): _sync_view.call()
	_feedback_label.text = "Guards are never combat targets: scripted arrest and transfer to the watchhouse." if res.ok else _message(res.code)
	refresh()

func _prepare_ok() -> bool:
	if not _prepare.is_valid(): return true
	var res: OperationResult = _prepare.call()
	if not res.ok:
		_feedback_label.text = _message(res.code)
		return false
	return true

func _message(code: String) -> String:
	return {
		"out_of_reach": "Move closer to the selected person or refuge.",
		"different_region": "That person or object is in another area.",
		"person_unavailable": "That watchman is currently off duty.",
		"restricted_unwitnessed": "The private lock holds firm (no watchman witnessed the attempt).",
		"guard_too_close": "A watchman is right beside you — move away before hiding.",
		"voucher_required": "You need a completed local work commitment for someone to vouch for you.",
		"persuasion_refused": "The watch will not waive repeat offenses or guard assault.",
		"insufficient_funds": "You do not have enough coins to pay the fine.",
		"non_hostile_target": "Only guards trigger scripted arrest on confrontation.",
	}.get(code, code)

func _add_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e4e5d8"))
	add_child(label)
	return label

func _add_button(parent: Node, node_name: String, label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.text = label
	btn.custom_minimum_size = Vector2(120, ACTION_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn
