class_name ConversationPanel
extends VBoxContainer
## Contextual UI; has no independent story cursor or gameplay state.
var _model: GameplayModel
var _actor: String
var _prepare: Callable
var _npc: String = ""
var _text: Label
var _choices: VBoxContainer
var _journal: Label
var _message: Label
var _speaker: Label
var _memory: Label

func configure(model: GameplayModel, actor: String, prepare: Callable) -> void:
	_model = model
	_actor = actor
	_prepare = prepare
	_speaker = Label.new()
	_speaker.name = "DialogueSpeaker"
	add_child(_speaker)
	var restart := Button.new()
	restart.name = "RestartConversation"
	restart.text = "Ask about something else"
	restart.custom_minimum_size.y = 48
	restart.pressed.connect(_restart)
	add_child(restart)
	_text = Label.new()
	_text.name = "DialogueText"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 300
	add_child(_text)
	_memory = Label.new()
	_memory.name = "SharedCommitments"
	_memory.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_memory)
	_choices = VBoxContainer.new()
	add_child(_choices)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	_journal = Label.new()
	_journal.name = "KnowledgeJournal"
	_journal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_journal)
	refresh()

func open(npc_id: String) -> void:
	_npc = npc_id
	var current := _model.narrative.conversation(_model.session.snapshot(), _actor)
	if current.is_empty() or current.npc_id != npc_id or current.frame.ended:
		_report(_model.talk(_intent(), _actor, npc_id))
	refresh()

func _intent() -> String:
	return "talk:%d" % _model.session.snapshot().revision

func _report(result: OperationResult) -> void:
	_message.text = "" if result.ok else result.code.replace("_", " ")

func _choose(index: int, expected_turns: int, npc_id: String, expected_cursor: String) -> void:
	var prepared: OperationResult = _prepare.call()
	if not prepared.ok:
		_report(prepared)
		return
	_report(_model.talk(_intent(), _actor, npc_id, index, expected_turns, expected_cursor))
	refresh()

func refresh() -> void:
	if _model == null or _journal == null: return
	_journal.text = "Rumors & discoveries\n" + _model.narrative.journal(_model.session.snapshot(), _actor)
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	var current := _model.narrative.conversation(_model.session.snapshot(), _actor)
	if current.is_empty():
		_text.text = "Approach a person and use Talk. Explore freely; rumors are not required to discover places."
		return
	_npc = current.npc_id
	_speaker.text = "Talking with " + _npc.trim_prefix("a:").capitalize()
	_memory.text = _model.work.memories(_model.session.snapshot(), _actor, _npc)
	_text.text = current.frame.text
	for index in current.frame.choices.size():
		var button := Button.new()
		button.name = "DialogueChoice%d" % index
		button.text = current.frame.choices[index]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(300, 52)
		button.pressed.connect(_choose.bind(index, current.turns.size(), current.npc_id, NarrativeRules.cursor(current)))
		_choices.add_child(button)

func _restart() -> void:
	if _npc.is_empty(): return
	var prepared: OperationResult = _prepare.call()
	if not prepared.ok:
		_report(prepared)
		return
	_report(_model.talk(_intent(), _actor, _npc))
	refresh()
