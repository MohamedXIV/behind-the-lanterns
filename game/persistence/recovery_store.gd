class_name RecoveryStore
extends RefCounted
## Native technical recovery, NOT gameplay checkpoints. One writer per directory.
## Web needs an asynchronous persistent-filesystem acknowledgment adapter.

const SLOT_NAMES: Array[String] = ["slot_a.json", "slot_b.json"]
var _directory: String
var _web_ack: WebSaveAck
var last_error: String = ""

func _init(directory: String, web_ack: WebSaveAck = null) -> void:
	_directory = directory
	_web_ack = web_ack if web_ack != null else WebSaveAck.new()

func web_ack() -> WebSaveAck:
	return _web_ack

func save(session: GameSession) -> OperationResult:
	if _web_ack.is_web() and not _web_ack.is_persistent():
		last_error = "web_storage_unavailable"
		return OperationResult.failure("web_storage_unavailable")
	if session == null or not _directory.begins_with("user://"): return OperationResult.failure("invalid_storage_path")
	if DirAccess.make_dir_recursive_absolute(_directory) != OK: return OperationResult.failure("storage_directory_failed")
	var records := _read_slots(session)
	if _ambiguous(records): return OperationResult.failure("ambiguous_generation")
	var latest := _latest(records)
	var target: int = 0 if latest < 0 else 1 - latest
	if latest < 0:
		for name in SLOT_NAMES:
			if FileAccess.file_exists(_directory.path_join(name)): return OperationResult.failure("no_valid_recovery")
	var generation: int = 1 if latest < 0 else records[latest].generation + 1
	if generation > WorldData.MAX_COUNTER: return OperationResult.failure("generation_exhausted")
	var encoded := SessionCodec.encode(session, generation)
	if encoded.is_empty(): return OperationResult.failure("save_encoding_failed")
	var destination := _directory.path_join(SLOT_NAMES[target])
	var temporary := destination + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return OperationResult.failure("save_open_failed")
	file.store_string(encoded)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: return OperationResult.failure("save_write_failed")
	var verified := _read_record(temporary, session)
	if verified.is_empty() or verified.generation != generation or verified.session.snapshot() != session.snapshot():
		return OperationResult.failure("save_readback_failed")
	# The active slot is never removed. Native rename replaces only the inactive file.
	if DirAccess.rename_absolute(temporary, destination) != OK: return OperationResult.failure("save_publish_failed")
	if _web_ack.is_web():
		var sync_result := _web_ack.sync_and_verify(ProjectSettings.globalize_path(destination), encoded.to_utf8_buffer())
		if not sync_result.ok:
			DirAccess.remove_absolute(destination)
			last_error = sync_result.code
			return sync_result
	last_error = ""
	return OperationResult.success()

func load_candidate(composition: GameSession) -> GameSession:
	last_error = ""
	if _web_ack.is_web() and not _web_ack.is_persistent():
		last_error = "web_storage_unavailable"
		return null
	if composition == null or not _directory.begins_with("user://"):
		last_error = "invalid_storage_path"
		return null
	var records := _read_slots(composition)
	if _ambiguous(records):
		last_error = "ambiguous_generation"
		return null
	var latest := _latest(records)
	if latest < 0:
		last_error = "no_valid_recovery"
		return null
	return records[latest].session

func _read_slots(composition: GameSession) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for name in SLOT_NAMES: records.append(_read_record(_directory.path_join(name), composition))
	return records

func _read_record(path: String, composition: GameSession) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > SessionCodec.MAX_BYTES: return {}
	var text := file.get_as_text()
	file.close()
	return SessionCodec.inspect(text, composition)

func _latest(records: Array[Dictionary]) -> int:
	if records[0].is_empty(): return -1 if records[1].is_empty() else 1
	if records[1].is_empty(): return 0
	return 0 if records[0].generation >= records[1].generation else 1

func _ambiguous(records: Array[Dictionary]) -> bool:
	return not records[0].is_empty() and not records[1].is_empty() \
		and records[0].generation == records[1].generation and records[0].digest != records[1].digest
