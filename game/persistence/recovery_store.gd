class_name RecoveryStore
extends RefCounted
## Native and Web technical recovery, NOT gameplay checkpoints. One writer per directory.
## On Web, a slot write is only considered committed after WebSaveAck confirms that
## Emscripten's /userfs IndexedDB FILE_DATA store holds the exact written bytes.

const SLOT_NAMES: Array[String] = ["slot_a.json", "slot_b.json"]
const DEFAULT_WEB_TIMEOUT_MS: int = 5000

var _directory: String
var _web_ack: WebSaveAck
var _pending_destination: String = ""
var _pending_elapsed_ms: int = 0
var _web_timeout_ms: int = DEFAULT_WEB_TIMEOUT_MS
var last_error: String = ""

func _init(directory: String, web_ack: WebSaveAck = null, web_timeout_ms: int = DEFAULT_WEB_TIMEOUT_MS) -> void:
	_directory = directory
	_web_ack = web_ack if web_ack != null else WebSaveAck.new()
	_web_timeout_ms = maxi(1, web_timeout_ms)

func web_ack() -> WebSaveAck:
	return _web_ack

func is_save_pending() -> bool:
	return not _pending_destination.is_empty()

func begin_save(session: GameSession) -> OperationResult:
	if is_save_pending() or _web_ack.is_dirty():
		last_error = "web_save_in_flight"
		return OperationResult.failure("web_save_in_flight")
	if _web_ack.is_web() and not _web_ack.is_persistent():
		last_error = "web_storage_unavailable"
		return OperationResult.failure("web_storage_unavailable")
	if session == null or not _directory.begins_with("user://"):
		last_error = "invalid_storage_path"
		return OperationResult.failure("invalid_storage_path")
	if DirAccess.make_dir_recursive_absolute(_directory) != OK:
		last_error = "storage_directory_failed"
		return OperationResult.failure("storage_directory_failed")
	if _web_ack.is_web():
		_cleanup_unconfirmed_web_files()
	var records := _read_slots(session)
	if _ambiguous(records):
		last_error = "ambiguous_generation"
		return OperationResult.failure("ambiguous_generation")
	var latest := _latest(records)
	var target: int = 0 if latest < 0 else 1 - latest
	if latest < 0:
		for name in SLOT_NAMES:
			if FileAccess.file_exists(_directory.path_join(name)):
				last_error = "no_valid_recovery"
				return OperationResult.failure("no_valid_recovery")
	var generation: int = 1 if latest < 0 else records[latest].generation + 1
	if generation > WorldData.MAX_COUNTER:
		last_error = "generation_exhausted"
		return OperationResult.failure("generation_exhausted")
	var encoded := SessionCodec.encode(session, generation)
	if encoded.is_empty():
		last_error = "save_encoding_failed"
		return OperationResult.failure("save_encoding_failed")
	var destination := _directory.path_join(SLOT_NAMES[target])
	var temporary := destination + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "save_open_failed"
		return OperationResult.failure("save_open_failed")
	file.store_string(encoded)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "save_write_failed"
		return OperationResult.failure("save_write_failed")
	var verified := _read_record_raw(temporary, session)
	if verified.is_empty() or verified.generation != generation or verified.session.snapshot() != session.snapshot():
		last_error = "save_readback_failed"
		return OperationResult.failure("save_readback_failed")
	# The active slot is never removed. Rename replaces only the inactive file.
	if DirAccess.rename_absolute(temporary, destination) != OK:
		last_error = "save_publish_failed"
		return OperationResult.failure("save_publish_failed")
	if _web_ack.is_web():
		_pending_destination = destination
		_pending_elapsed_ms = 0
		var sync_result := _web_ack.begin_sync(ProjectSettings.globalize_path(destination), encoded.to_utf8_buffer())
		if sync_result.ok:
			_pending_destination = ""
			last_error = ""
			return OperationResult.success()
		if sync_result.code == "web_sync_pending":
			last_error = "web_sync_pending"
			return sync_result
		_rollback_pending(sync_result.code)
		return sync_result
	last_error = ""
	return OperationResult.success()

func poll_save(step_ms: int = 0) -> OperationResult:
	if not is_save_pending():
		if _web_ack.last_state() == "confirmed" and last_error.is_empty():
			return OperationResult.success()
		var code := last_error if not last_error.is_empty() else "no_save_in_flight"
		return OperationResult.failure(code)
	var state := _web_ack.poll_state()
	if state == "confirmed":
		_pending_destination = ""
		_pending_elapsed_ms = 0
		last_error = ""
		return OperationResult.success()
	if state == "failed":
		_rollback_pending("web_sync_failed")
		return OperationResult.failure("web_sync_failed")
	_pending_elapsed_ms += maxi(0, step_ms)
	if _pending_elapsed_ms >= _web_timeout_ms:
		_rollback_pending("web_sync_timeout")
		return OperationResult.failure("web_sync_timeout")
	last_error = "web_sync_pending"
	return OperationResult.failure("web_sync_pending")

func cancel_pending_save(reason: String = "web_sync_cancelled") -> void:
	if is_save_pending():
		_rollback_pending(reason)

func save(session: GameSession) -> OperationResult:
	var result := begin_save(session)
	if result.ok:
		return result
	if result.code == "web_sync_pending":
		# Synchronous save() cannot wait across browser frames and must never claim
		# completion while IndexedDB verification is still pending.
		_rollback_pending("web_sync_pending")
		return OperationResult.failure("web_sync_pending")
	return result

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

func _rollback_pending(error_code: String) -> void:
	var path := _pending_destination
	_pending_destination = ""
	_pending_elapsed_ms = 0
	if not path.is_empty():
		var global_path := ProjectSettings.globalize_path(path)
		var idb_file := global_path + ".idb"
		if _web_ack.is_web() and FileAccess.file_exists(idb_file):
			var prior := FileAccess.get_file_as_bytes(idb_file)
			var restore := FileAccess.open(path, FileAccess.WRITE)
			if restore != null:
				restore.store_buffer(prior)
				restore.flush()
				restore.close()
		else:
			DirAccess.remove_absolute(path)
		_web_ack.abort_pending(global_path)
	else:
		_web_ack.abort_pending()
	last_error = error_code

func _cleanup_unconfirmed_web_files() -> void:
	for name in SLOT_NAMES:
		var path := _directory.path_join(name)
		if not FileAccess.file_exists(path): continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null: continue
		var text := file.get_as_text()
		file.close()
		var global_path := ProjectSettings.globalize_path(path)
		if not _web_ack.is_slot_confirmed(global_path, text.to_utf8_buffer()):
			var idb_file := global_path + ".idb"
			if FileAccess.file_exists(idb_file):
				var prior := FileAccess.get_file_as_bytes(idb_file)
				var restore := FileAccess.open(path, FileAccess.WRITE)
				if restore != null:
					restore.store_buffer(prior)
					restore.flush()
					restore.close()
			else:
				DirAccess.remove_absolute(path)

func _read_slots(composition: GameSession) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for name in SLOT_NAMES: records.append(_read_record(_directory.path_join(name), composition))
	return records

func _read_record(path: String, composition: GameSession) -> Dictionary:
	if path == _pending_destination: return {}
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > SessionCodec.MAX_BYTES: return {}
	var text := file.get_as_text()
	file.close()
	if _web_ack.is_web() and not _web_ack.is_slot_confirmed(ProjectSettings.globalize_path(path), text.to_utf8_buffer()):
		return {}
	return SessionCodec.inspect(text, composition)

func _read_record_raw(path: String, composition: GameSession) -> Dictionary:
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
