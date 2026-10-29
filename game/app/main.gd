extends Control
## Persistent composition root. No shipping content is invented for this shell.

var _session: GameSession
var _status: Label

func _ready() -> void:
	_status = Label.new()
	_status.position = Vector2(24, 24)
	add_child(_status)
	_refresh(0)

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
	_status.text = "Behind the Lanterns — foundation shell\nNo production world content loaded."
	if _session != null:
		_status.text = "Behind the Lanterns — foundation shell\nWorld minute: %d" % _session.now()

func _exit_tree() -> void:
	if _session != null:
		_session.committed.disconnect(_refresh)
		_session.close()
