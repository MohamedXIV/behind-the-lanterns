extends Control
## Persistent composition root. No shipping content is invented for this shell.

var _session: GameSession
var _status: Label

func _ready() -> void:
	_status = Label.new()
	_status.position = Vector2(24, 24)
	add_child(_status)
	_refresh(0)
	var play := Button.new()
	play.name = "OpenPlayground"
	play.text = "Open gameplay playground"
	play.position = Vector2(24, 100)
	play.custom_minimum_size = Vector2(300, 56)
	play.pressed.connect(open_playground)
	add_child(play)

func open_playground(directory: String = "user://connected-gameplay-playground") -> void:
	if get_node_or_null("GameplayPlayground") != null: return
	var playground: Control = load("res://dev/gameplay_playground.gd").new()
	if not playground.initialize(directory):
		_status.text = "Unable to load gameplay fixture."
		playground.free()
		return
	playground.name = "GameplayPlayground"
	playground.session_changed.connect(replace_session)
	add_child(playground)

func replace_session(candidate: GameSession) -> bool:
	if candidate == null or candidate.is_closed(): return false
	if candidate == _session: return true
	if _session != null:
		if not _session.close(): return false
		_session.committed.disconnect(_refresh)
	_session = candidate
	_session.committed.connect(_refresh)
	_refresh(0)
	return true

func _refresh(_revision: int) -> void:
	if _status == null: return
	_status.text = "Behind the Lanterns\nCollect, store and trade in the disposable gameplay playground."
	if _session != null:
		_status.text = "Behind the Lanterns — foundation shell\nWorld minute: %d" % _session.now()

func _exit_tree() -> void:
	if _session != null:
		_session.committed.disconnect(_refresh)
		_session.close()
