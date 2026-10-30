class_name WebSaveAck
extends RefCounted
## Browser IndexedDB (/userfs) persistence sync and acknowledgment adapter.
## Keeps a beforeunload guard active while a Web save flush is in flight and
## confirms completion only when Emscripten's /userfs FILE_DATA store matches
## the exact written bytes.

var _installed: bool = false
var _simulated_web: bool = false
var _simulated_persistent: bool = true
var _simulated_sync: Callable = Callable()
var _simulated_poll: Callable = Callable()
var _idb_files: Dictionary = {}
var _dirty: bool = false
var _last_state: String = "idle"
var _write_id: int = 0
var _pending_path: String = ""
var _pending_disk_path: String = ""
var _pending_expected: PackedByteArray = PackedByteArray()

func configure_simulated_web(persistent: bool = true, sync_fn: Callable = Callable(), poll_fn: Callable = Callable()) -> void:
	_simulated_web = true
	_simulated_persistent = persistent
	_simulated_sync = sync_fn
	_simulated_poll = poll_fn
	_idb_files.clear()
	_dirty = false
	_last_state = "idle"
	_write_id = 0
	_pending_path = ""
	_pending_disk_path = ""
	_pending_expected = PackedByteArray()

func is_web() -> bool:
	return _simulated_web or OS.has_feature("web")

func is_persistent() -> bool:
	if _simulated_web: return _simulated_persistent
	if OS.has_feature("web"): return OS.is_userfs_persistent()
	return true

func is_dirty() -> bool:
	return _dirty

func last_state() -> String:
	return _last_state

func write_id() -> int:
	return _write_id

func simulated_idb_bytes(global_path: String) -> PackedByteArray:
	var web_path := _normalize_web_path(global_path)
	if _idb_files.has(web_path):
		return _idb_files[web_path]
	var idb_file := global_path + ".idb"
	if FileAccess.file_exists(idb_file):
		return FileAccess.get_file_as_bytes(idb_file)
	return PackedByteArray()

func begin_sync(global_path: String, expected_bytes: PackedByteArray) -> OperationResult:
	if not is_web():
		_last_state = "confirmed"
		_dirty = false
		return OperationResult.success()
	if not is_persistent():
		_last_state = "unavailable"
		_dirty = false
		return OperationResult.failure("web_storage_unavailable")
	if _dirty or _last_state == "pending":
		return OperationResult.failure("web_save_in_flight")
	var web_path := _normalize_web_path(global_path)
	if web_path.is_empty():
		_last_state = "failed"
		_dirty = false
		return OperationResult.failure("invalid_web_path")
	_write_id += 1
	_dirty = true
	_last_state = "pending"
	_pending_path = web_path
	_pending_disk_path = global_path
	_pending_expected = expected_bytes.duplicate()
	if _simulated_web:
		if _simulated_sync.is_valid():
			var outcome: Variant = _simulated_sync.call(web_path, expected_bytes, _idb_files)
			if outcome is String and outcome == "pending":
				return OperationResult.failure("web_sync_pending")
			if not bool(outcome):
				abort_pending(global_path)
				return OperationResult.failure("web_sync_failed")
		else:
			_idb_files[web_path] = expected_bytes.duplicate()
		var sim_state := poll_state()
		if sim_state == "confirmed":
			return OperationResult.success()
		if sim_state == "pending":
			return OperationResult.failure("web_sync_pending")
		return OperationResult.failure("web_sync_failed")
	install_bridge()
	begin_write(web_path, expected_bytes, _write_id)
	JavaScriptBridge.force_fs_sync()
	var state := poll_state()
	if state == "confirmed":
		return OperationResult.success()
	if state == "pending":
		return OperationResult.failure("web_sync_pending")
	return OperationResult.failure("web_sync_failed")

func sync_and_verify(global_path: String, expected_bytes: PackedByteArray) -> OperationResult:
	# Synchronous verification boundary: never reports success while state is "pending".
	var result := begin_sync(global_path, expected_bytes)
	if result.code == "web_sync_pending":
		abort_pending(global_path)
	return result

func poll_state() -> String:
	if not is_web():
		_dirty = false
		_last_state = "confirmed"
		return "confirmed"
	if _last_state != "pending":
		return _last_state
	if _simulated_web:
		if _simulated_poll.is_valid():
			var polled := str(_simulated_poll.call(_pending_path, _pending_expected, _idb_files))
			if polled == "pending":
				_dirty = true
				_last_state = "pending"
				return "pending"
			if polled == "failed":
				abort_pending(_pending_disk_path)
				return "failed"
		if _idb_files.has(_pending_path) and _idb_files[_pending_path] == _pending_expected:
			_persist_simulated_idb(_pending_disk_path, _pending_expected)
			_dirty = false
			_last_state = "confirmed"
			_pending_path = ""
			_pending_disk_path = ""
			_pending_expected = PackedByteArray()
			return "confirmed"
		abort_pending(_pending_disk_path)
		return "failed"
	install_bridge()
	var result: Variant = JavaScriptBridge.eval("window.__btlSaveAck.check();", true)
	var state := str(result)
	if state == "confirmed":
		clear_dirty()
		_last_state = "confirmed"
		_pending_path = ""
		_pending_disk_path = ""
		_pending_expected = PackedByteArray()
		return "confirmed"
	if state == "failed":
		clear_dirty()
		_last_state = "failed"
		_pending_path = ""
		_pending_disk_path = ""
		_pending_expected = PackedByteArray()
		return "failed"
	_dirty = true
	_last_state = "pending"
	return "pending"

func abort_pending(global_path: String = "") -> void:
	_write_id += 1
	_dirty = false
	_last_state = "failed"
	_pending_path = ""
	_pending_disk_path = ""
	_pending_expected = PackedByteArray()
	if _simulated_web and not global_path.is_empty():
		var web_path := _normalize_web_path(global_path)
		var idb_file := global_path + ".idb"
		if FileAccess.file_exists(idb_file):
			_idb_files[web_path] = FileAccess.get_file_as_bytes(idb_file)
		else:
			_idb_files.erase(web_path)
	if OS.has_feature("web"):
		clear_dirty()
		JavaScriptBridge.force_fs_sync()

func is_slot_confirmed(global_path: String, disk_bytes: PackedByteArray) -> bool:
	if not is_web(): return true
	var web_path := _normalize_web_path(global_path)
	if _last_state == "pending" and web_path == _pending_path:
		return false
	if _simulated_web:
		if _idb_files.has(web_path):
			return _idb_files[web_path] == disk_bytes
		var idb_file := global_path + ".idb"
		if FileAccess.file_exists(idb_file):
			var committed := FileAccess.get_file_as_bytes(idb_file)
			_idb_files[web_path] = committed
			return committed == disk_bytes
		return false
	return true

func install_bridge() -> void:
	if _installed or not OS.has_feature("web"): return
	_installed = true
	JavaScriptBridge.eval("""
		(function () {
			if (window.__btlSaveAck) return;
			const state = {
				writeId: 0,
				dirty: false,
				status: 'idle',
				path: '',
				expectedHex: '',
				checking: false
			};
			window.addEventListener('beforeunload', function (event) {
				if (!state.dirty) return;
				event.preventDefault();
				event.returnValue = '';
			});
			function toHex(bytes) {
				const out = new Array(bytes.length);
				for (let i = 0; i < bytes.length; i += 1) {
					out[i] = bytes[i].toString(16).padStart(2, '0');
				}
				return out.join('');
			}
			function extractBytes(record) {
				if (!record) return null;
				const raw = record.contents !== undefined ? record.contents : record;
				if (raw instanceof Uint8Array) return raw;
				if (ArrayBuffer.isView(raw)) return new Uint8Array(raw.buffer, raw.byteOffset, raw.byteLength);
				if (raw instanceof ArrayBuffer) return new Uint8Array(raw);
				if (Array.isArray(raw)) return new Uint8Array(raw);
				return null;
			}
			window.__btlSaveAck = {
				state: state,
				begin: function (path, expectedHex, writeId) {
					state.writeId = writeId;
					state.dirty = true;
					state.status = 'pending';
					state.path = path;
					state.expectedHex = expectedHex;
					state.checking = false;
				},
				clear: function () {
					state.writeId += 1;
					state.dirty = false;
					state.checking = false;
				},
				check: function () {
					if (state.status !== 'pending' || state.checking) return state.status;
					if (!window.indexedDB) {
						state.status = 'failed';
						state.dirty = false;
						return state.status;
					}
					const activeWriteId = state.writeId;
					const activePath = state.path;
					const activeHex = state.expectedHex;
					state.checking = true;
					try {
						const openReq = window.indexedDB.open('/userfs');
						openReq.onerror = function () {
							if (state.writeId !== activeWriteId) return;
							state.checking = false;
							state.status = 'failed';
							state.dirty = false;
						};
						openReq.onsuccess = function () {
							const db = openReq.result;
							if (state.writeId !== activeWriteId || state.status !== 'pending') {
								db.close();
								return;
							}
							if (!db.objectStoreNames.contains('FILE_DATA')) {
								db.close();
								state.checking = false;
								return;
							}
							const tx = db.transaction(['FILE_DATA'], 'readonly');
							tx.onerror = function () {
								db.close();
								if (state.writeId !== activeWriteId) return;
								state.checking = false;
								state.status = 'failed';
								state.dirty = false;
							};
							tx.onabort = tx.onerror;
							const req = tx.objectStore('FILE_DATA').get(activePath);
							req.onerror = function () {
								db.close();
								if (state.writeId !== activeWriteId) return;
								state.checking = false;
								state.status = 'failed';
								state.dirty = false;
							};
							req.onsuccess = function () {
								const bytes = extractBytes(req.result);
								db.close();
								if (state.writeId !== activeWriteId || state.status !== 'pending') return;
								state.checking = false;
								if (bytes && toHex(bytes) === activeHex) {
									state.status = 'confirmed';
									state.dirty = false;
								}
							};
						};
					} catch (_err) {
						if (state.writeId === activeWriteId) {
							state.checking = false;
							state.status = 'failed';
							state.dirty = false;
						}
					}
					return state.status;
				}
			};
		})();
	""", true)

func begin_write(web_path: String, expected_bytes: PackedByteArray, write_id: int) -> void:
	if not OS.has_feature("web"): return
	install_bridge()
	var js_path := JSON.stringify(web_path)
	var js_hex := JSON.stringify(expected_bytes.hex_encode())
	JavaScriptBridge.eval("window.__btlSaveAck.begin(%s, %s, %d);" % [js_path, js_hex, write_id], true)

func clear_dirty() -> void:
	_dirty = false
	if not OS.has_feature("web"): return
	install_bridge()
	JavaScriptBridge.eval("window.__btlSaveAck.clear();", true)

func _persist_simulated_idb(global_path: String, bytes: PackedByteArray) -> void:
	if global_path.is_empty(): return
	var file := FileAccess.open(global_path + ".idb", FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.flush()
		file.close()

func _normalize_web_path(global_path: String) -> String:
	if global_path.begins_with("/userfs/"): return global_path
	if _simulated_web and not global_path.is_empty():
		var marker := global_path.find("user://")
		if marker >= 0: return "/userfs/" + global_path.substr(marker + 7)
		return "/userfs/" + global_path.trim_prefix("/")
	return ""
