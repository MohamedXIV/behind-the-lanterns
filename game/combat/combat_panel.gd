class_name CombatPanel
extends VBoxContainer
## Touch-sized non-guard combat and retreat panel: displays enemy attack telegraphs,
## weak-spot windows, actor/threat health, and primary strike, dodge, block,
## retreat, and recovery actions.

const ACTION_HEIGHT: float = 48.0

var _model: GameplayModel
var _actor: String
var _prepare: Callable
var _visual: Callable
var _sync_view: Callable
var _selected_target: String = ""
var _status_label: Label
var _telegraph_label: Label
var _bar: ProgressBar
var _engage_btn: Button
var _strike_btn: Button
var _dodge_btn: Button
var _block_btn: Button
var _retreat_btn: Button
var _recover_btn: Button
var _feedback_label: Label
var _pending: float = 0.0
var _suspended: bool = false

func configure(model: GameplayModel, actor: String, prepare: Callable, visual: Callable, sync_view: Callable = Callable()) -> void:
	_model = model
	_actor = actor
	_prepare = prepare
	_visual = visual
	_sync_view = sync_view
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_status_label = _add_label("Combat: No active encounter", 16)
	_status_label.name = "CombatStatus"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_telegraph_label = _add_label("Approach a hostile creature to read its stance. Guards are never combat targets.", 15)
	_telegraph_label.name = "CombatTelegraph"
	_telegraph_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_bar = ProgressBar.new()
	_bar.name = "CombatTiming"
	_bar.custom_minimum_size.y = 28
	add_child(_bar)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)

	_engage_btn = _add_button(grid, "EngageThreat", "Engage Threat", _on_engage)
	_strike_btn = _add_button(grid, "StrikeThreat", "Strike (R)", _on_strike)
	_dodge_btn = _add_button(grid, "DodgeThreat", "Evade / Dodge (Q)", _on_dodge)
	_block_btn = _add_button(grid, "BlockThreat", "Guard / Block (F)", _on_block)
	_retreat_btn = _add_button(grid, "RetreatCombat", "Retreat / Escape", _on_retreat)
	_recover_btn = _add_button(grid, "RecoverStance", "Catch Breath", _on_recover)

	_feedback_label = _add_label("Read enemy telegraphs: Guard or Evade light lunges, Evade heavy sweeps, then strike the exposed weak spot — or retreat safely.", 14)
	_feedback_label.name = "CombatFeedback"
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refresh()

func open(target_id: String) -> void:
	_selected_target = target_id
	refresh()

func reset_after_load() -> void:
	_pending = 0.0
	if _feedback_label != null:
		_feedback_label.text = "Encounter state restored from save."
	refresh()

func _process(delta: float) -> void:
	if _model == null or _model.combat == null or _model.session.is_closed() or _suspended: return
	var record := _model.combat.encounter(_model.session.snapshot(), _actor)
	if record.get("status", "") != "engaged": return
	_pending += minf(delta, 0.1)
	if _pending >= 0.1:
		flush_progress()

func flush_progress() -> void:
	if _model == null or _model.combat == null or _suspended or _pending < 0.001: return
	var record := _model.combat.encounter(_model.session.snapshot(), _actor)
	if record.get("status", "") != "engaged":
		_pending = 0.0
		return
	var milliseconds := mini(int(_pending * 1000.0), 10000)
	_pending = 0.0
	var before_pos := _model.position_of(_actor)
	var res := _model.progress_combat(_intent("combat-tick"), _actor, milliseconds)
	if res.ok:
		if _model.position_of(_actor) != before_pos and _sync_view.is_valid():
			_sync_view.call()
		var after := _model.combat.encounter(_model.session.snapshot(), _actor)
		_feedback_label.text = _event_description(after)
	refresh()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		flush_progress()
		_suspended = true
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_suspended = false

func handle_combat_action(action: String, candidate_target: String = "") -> String:
	if _model == null or _model.combat == null: return ""
	var snapshot := _model.session.snapshot()
	var record := _model.combat.encounter(snapshot, _actor)
	if record.get("status", "") == "engaged":
		match action:
			PlayerInput.PRIMARY_ACTION:
				_on_strike()
				return _feedback_label.text
			PlayerInput.DODGE:
				_on_dodge()
				return _feedback_label.text
			PlayerInput.BLOCK:
				_on_block()
				return _feedback_label.text
		return ""
	var threat_id := candidate_target if _model.combat.is_threat(candidate_target) else _active_or_nearby_threat(snapshot)
	if threat_id.is_empty(): return ""
	var threat: Dictionary = _model.combat.threats()[threat_id]
	var origin: Vector2 = _visual.call() if _visual.is_valid() else _model.position_of(_actor)
	if origin.distance_to(_model.position_of(threat_id)) > float(threat.engage_range):
		return ""
	_selected_target = threat_id
	if record.get("status", "") == "winded":
		_feedback_label.text = _message("actor_winded")
		refresh()
		return _feedback_label.text
	_on_engage()
	return _feedback_label.text

func refresh() -> void:
	if _model == null or _model.combat == null or _status_label == null: return
	var snapshot := _model.session.snapshot()
	var record := _model.combat.encounter(snapshot, _actor)
	var max_hp := _model.combat.actor_max_health()
	var current_hp := int(record.get("actor_health", max_hp))
	var target_id := _resolved_threat_id(snapshot, record)

	if record.is_empty():
		_status_label.text = "Stance: READY · Stamina/Health: %d/%d" % [current_hp, max_hp]
		if not target_id.is_empty():
			var tdef: Dictionary = _model.combat.threats()[target_id]
			_telegraph_label.text = "Nearby threat: %s (HP %d/%d · Weak spot: %s)\nEngage to read its attacks or pass outside its range." % [tdef.label, int(tdef.max_health), int(tdef.max_health), tdef.weak_spot_label]
		else:
			_telegraph_label.text = "No hostile creature engaged. Guards are never combat targets."
		_bar.max_value = 100
		_bar.value = 0
	else:
		var tdef: Dictionary = _model.combat.threats()[record.threat_id]
		var status_upper := str(record.status).to_upper()
		_status_label.text = "Encounter: %s vs %s\nYour Health: %d/%d · %s Health: %d/%d" % [
			status_upper,
			tdef.label,
			current_hp,
			max_hp,
			tdef.label,
			int(record.threat_health),
			int(tdef.max_health),
		]
		if record.status == "engaged":
			var duration := _model.combat.phase_duration(record.threat_id, record.phase)
			_bar.max_value = maxi(1, duration)
			_bar.value = int(record.elapsed_ms)
			_telegraph_label.text = _phase_description(record, tdef)
		else:
			_bar.max_value = 100
			_bar.value = 0
			_telegraph_label.text = _outcome_description(record, tdef)

	var is_engaged: bool = record.get("status", "") == "engaged"
	var is_winded: bool = record.get("status", "") == "winded"
	_engage_btn.disabled = is_engaged or is_winded or target_id.is_empty()
	_strike_btn.disabled = not is_engaged
	_dodge_btn.disabled = not is_engaged
	_block_btn.disabled = not is_engaged
	_retreat_btn.disabled = not is_engaged
	_recover_btn.disabled = is_engaged or (current_hp >= max_hp and not is_winded)

func _resolved_threat_id(snapshot: Dictionary, record: Dictionary) -> String:
	if record.get("status", "") == "engaged":
		return record.get("threat_id", "")
	if _model.combat.is_threat(_selected_target):
		return _selected_target
	return _active_or_nearby_threat(snapshot)

func _active_or_nearby_threat(snapshot: Dictionary) -> String:
	var origin: Vector2 = _visual.call() if _visual.is_valid() else _model.position_of(_actor)
	return _model.combat.nearby_threat(snapshot, _actor, origin)

func _intent(prefix: String) -> String:
	return "%s:%d" % [prefix, _model.session.snapshot().revision]

func _prepare_ok() -> bool:
	if not _prepare.is_valid(): return true
	var res: OperationResult = _prepare.call()
	if not res.ok:
		_feedback_label.text = _message(res.code)
		return false
	return true

func _on_engage() -> void:
	if not _prepare_ok(): return
	var snapshot := _model.session.snapshot()
	var record := _model.combat.encounter(snapshot, _actor)
	var target_id := _resolved_threat_id(snapshot, record)
	if target_id.is_empty():
		_feedback_label.text = _message("unknown_threat")
		return
	_pending = 0.0
	var res := _model.engage_combat(_intent("combat-engage"), _actor, target_id)
	if res.ok:
		_selected_target = target_id
		var updated := _model.combat.encounter(_model.session.snapshot(), _actor)
		_feedback_label.text = _event_description(updated)
	else:
		_feedback_label.text = _message(res.code)
	if _sync_view.is_valid(): _sync_view.call()
	refresh()

func _on_strike() -> void:
	if not _prepare_ok(): return
	var res := _model.strike_combat(_intent("combat-strike"), _actor)
	if res.ok:
		var updated := _model.combat.encounter(_model.session.snapshot(), _actor)
		_feedback_label.text = _event_description(updated)
	else:
		_feedback_label.text = _message(res.code)
	if _sync_view.is_valid(): _sync_view.call()
	refresh()

func _on_dodge() -> void:
	if not _prepare_ok(): return
	var res := _model.dodge_combat(_intent("combat-dodge"), _actor)
	if res.ok:
		var updated := _model.combat.encounter(_model.session.snapshot(), _actor)
		_feedback_label.text = _event_description(updated)
	else:
		_feedback_label.text = _message(res.code)
	if _sync_view.is_valid(): _sync_view.call()
	refresh()

func _on_block() -> void:
	if not _prepare_ok(): return
	var res := _model.block_combat(_intent("combat-block"), _actor)
	if res.ok:
		var updated := _model.combat.encounter(_model.session.snapshot(), _actor)
		_feedback_label.text = _event_description(updated)
	else:
		_feedback_label.text = _message(res.code)
	if _sync_view.is_valid(): _sync_view.call()
	refresh()

func _on_retreat() -> void:
	if not _prepare_ok(): return
	_pending = 0.0
	var res := _model.retreat_combat(_intent("combat-retreat"), _actor)
	if res.ok:
		if _sync_view.is_valid(): _sync_view.call()
		var updated := _model.combat.encounter(_model.session.snapshot(), _actor)
		_feedback_label.text = _event_description(updated)
	else:
		_feedback_label.text = _message(res.code)
	refresh()

func _on_recover() -> void:
	if not _prepare_ok(): return
	_pending = 0.0
	var res := _model.recover_combat(_intent("combat-recover"), _actor)
	if res.ok:
		var updated := _model.combat.encounter(_model.session.snapshot(), _actor)
		_feedback_label.text = _event_description(updated)
	else:
		_feedback_label.text = _message(res.code)
	if _sync_view.is_valid(): _sync_view.call()
	refresh()

func _phase_description(record: Dictionary, tdef: Dictionary) -> String:
	var defense_note := ""
	if record.defense == "dodge":
		defense_note = " · Stance: EVADING"
	elif record.defense == "block":
		defense_note = " · Stance: GUARDING"
	match record.phase:
		"poised":
			return "Telegraph: %s is circling (%s)%s.\nStrike for %d chip damage or wait to counter its telegraph." % [
				tdef.label,
				"POISED",
				defense_note,
				_model.combat.base_strike_damage(),
			]
		"light_windup":
			return "Telegraph: LIGHT LUNGE WINDUP%s!\nPress Guard/Block (F) or Evade/Dodge (Q) to counter and expose %s." % [
				defense_note,
				tdef.weak_spot_label,
			]
		"heavy_windup":
			return "Telegraph: HEAVY SWEEP WINDUP%s!\nPress Evade/Dodge (Q) or step back to expose %s (Block only reduces damage)." % [
				defense_note,
				tdef.weak_spot_label,
			]
		"vulnerable":
			return "WEAK SPOT OPEN: %s EXPOSED!\nStrike (R) now for %d weak-spot damage!" % [
				tdef.weak_spot_label.to_upper(),
				_model.combat.weak_spot_damage(),
			]
	return ""

func _outcome_description(record: Dictionary, tdef: Dictionary) -> String:
	match record.status:
		"victory":
			return "Outcome: VICTORY — %s was driven off after exploiting its %s." % [tdef.label, tdef.weak_spot_label]
		"retreated":
			return "Outcome: RETREATED — You broke off the encounter with %s safely. Escape is always a valid outcome." % tdef.label
		"winded":
			return "Outcome: WINDED (Provisional D-016 recovery) — Knocked back to safety by %s without save deletion. Press Catch Breath to recover." % tdef.label
	return ""

func _event_description(record: Dictionary) -> String:
	if record.is_empty(): return "Ready."
	var tdef: Dictionary = _model.combat.threats().get(record.get("threat_id", ""), {})
	var label: String = tdef.get("label", "Threat")
	var weak: String = tdef.get("weak_spot_label", "weak spot")
	match record.get("last_event", ""):
		"engaged":
			return "Engaged %s — watch its telegraph before committing." % label
		"telegraph_light":
			return "%s coils for a fast LIGHT LUNGE — Guard (F) or Evade (Q)!" % label
		"telegraph_heavy":
			return "%s rears back for a HEAVY SWEEP — Evade (Q) or step out of range!" % label
		"dodge_ready":
			return "Evade committed against %s's incoming attack." % label
		"dodge_early":
			return "Dodged before %s committed to an attack." % label
		"block_ready":
			return "Guard raised against %s's incoming attack." % label
		"block_early":
			return "Raised guard early while %s was not winding up." % label
		"dodged_counter":
			return "Evaded %s's attack! %s is EXPOSED — Strike now!" % [label, weak]
		"blocked_counter":
			return "Parried %s's light lunge! %s is EXPOSED — Strike now!" % [label, weak]
		"outspaced_counter":
			return "Outspaced %s's attack! %s is EXPOSED — step in and Strike!" % [label, weak]
		"heavy_crushed_block":
			return "%s's heavy sweep crushed through your guard for chip damage — Evade heavy telegraphs!" % label
		"threat_hit_light":
			return "%s's light lunge hit you! Watch the telegraph and Guard or Evade." % label
		"threat_hit_heavy":
			return "%s's heavy sweep struck you hard! Evade heavy telegraphs." % label
		"weak_spot_closed":
			return "%s recovered its footing and closed its %s." % [label, weak]
		"struck_weak_spot":
			return "Direct hit on %s's %s for %d damage!" % [label, weak, _model.combat.weak_spot_damage()]
		"struck_poised":
			return "Glancing strike on %s (%d damage) — watch its counter-telegraph!" % [label, _model.combat.base_strike_damage()]
		"struck_guarded_windup":
			return "Strike deflected! %s is coiled mid-windup — Guard or Evade to open its %s." % [label, weak]
		"victory":
			return "Defeated %s by exploiting its %s!" % [label, weak]
		"retreated":
			return "Retreated safely from %s." % label
		"spatial_retreat":
			return "Moved beyond %s's pursuit range and escaped safely." % label
		"winded":
			return "Winded and knocked back to safety (D-016 provisional non-destructive recovery). Catch your breath to recover."
		"recovered":
			return "Caught your breath and restored full stamina/health (%d/%d)." % [_model.combat.actor_max_health(), _model.combat.actor_max_health()]
	return "Combat updated."

func _message(code: String) -> String:
	return {
		"guard_not_combat_target": "Guards are never combat targets. Attacking a guard triggers scripted arrest.",
		"unknown_threat": "Approach a hostile creature first.",
		"out_of_engage_range": "Move closer to the creature to engage or strike.",
		"different_region": "That creature is in another area.",
		"combat_obstructed": "An obstacle blocks a clear line to the creature.",
		"combat_in_progress": "You are already engaged in combat.",
		"combat_not_engaged": "Engage a hostile creature first.",
		"actor_winded": "You are winded — press Catch Breath before re-engaging.",
		"already_recovered": "Your health and stance are already fully recovered.",
	}.get(code, code.replace("_", " "))

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
