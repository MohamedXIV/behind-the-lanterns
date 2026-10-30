class_name WebSaveAck
extends RefCounted
## Browser IndexedDB (/userfs) persistence sync and acknowledgment adapter.
## Keeps a beforeunload guard active while a Web save flush is in flight and
## verifies that Emscripten's /userfs FILE_DATA store matches the written bytes.

var _installed: bool = false
var _simulated_web: bool = false
var _simulated_persistent: bool = true
var _simulated_sync: Callable = Callable()
var _idb_files: Dictionary = {}
var _dirty: bool = false
var _last_state: String = "idle"

func configure_simulated_web(persistent: bool = true, sync_fn: Callable = Callable()) -> void:
	_simulated_web = true
	_simulated_persistent = persistent
	_simulated_sync = sync_fn
	_idb_files.clear()
	_dirty = false
	_last_state = "idle"

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

func simulated_idb_bytes(global_path: String) -> PackedByteArray:
	return _idb_files.get(_normalize_web_path(global_path), PackedByteArray())

func sync_and_verify(global_path: String, expected_bytes: PackedByteArray) -> OperationResult:
	if not is_web():
		_last_state = "confirmed"
		return OperationResult.success()
	if not is_persistent():
		_last_state = "unavailable"
		return OperationResult.failure("web_storage_unavailable")
	var web_path := _normalize_web_path(global_path)
	if web_path.is_empty():
		_last_state = "failed"
		return OperationResult.failure("invalid_web_path")
	_dirty = true
	_last_state = "pending"
	if _simulated_web:
		var ok := true
		if _simulated_sync.is_valid():
			ok = bool(_simulated_sync.call(web_path, expected_bytes, _idb_files))
		else:
			_idb_files[web_path] = expected_bytes.duplicate()
		if not ok or not _idb_files.has(web_path) or _idb_files[web_path] != expected_bytes:
			_dirty = false
			_last_state = "failed"
			return OperationResult.failure("web_sync_failed")
		_dirty = false
		_last_state = "confirmed"
		return OperationResult.success()
	install_bridge()
	begin_write(web_path, expected_bytes)
	JavaScriptBridge.force_fs_sync()
	var state := poll_state()
	if state == "failed":
		clear_dirty()
		_last_state = "failed"
		return OperationResult.failure("web_sync_failed")
	if state == "confirmed":
		clear_dirty()
	_last_state = state
	return OperationResult.success()

func install_bridge() -> void:
	if _installed or not OS.has_feature("web"): return
	_installed = true
	JavaScriptBridge.eval("""
		(function () {
			if (window.__btlSaveAck) return;
			const state = {
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
				begin: function (path, expectedHex) {
					state.dirty = true;
					state.status = 'pending';
					state.path = path;
					state.expectedHex = expectedHex;
					state.checking = false;
				},
				clear: function () {
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
					state.checking = true;
					try {
						const openReq = window.indexedDB.open('/userfs');
						openReq.onerror = function () {
							state.checking = false;
							state.status = 'failed';
						};
						openReq.onsuccess = function () {
							const db = openReq.result;
							if (!db.objectStoreNames.contains('FILE_DATA')) {
								db.close();
								state.checking = false;
								return;
							}
							const tx = db.transaction(['FILE_DATA'], 'readonly');
							const req = tx.objectStore('FILE_DATA').get(state.path);
							req.onerror = function () {
								db.close();
								state.checking = false;
							};
							req.onsuccess = function () {
								const bytes = extractBytes(req.result);
								db.close();
								state.checking = false;
								if (bytes && toHex(bytes) === state.expectedHex) {
									state.status = 'confirmed';
									state.dirty = false;
								}
							};
						};
					} catch (_err) {
						state.checking = false;
						state.status = 'failed';
					}
					return state.status;
				}
			};
		})();
	""", true)

func begin_write(web_path: String, expected_bytes: PackedByteArray) -> void:
	if not OS.has_feature("web"): return
	install_bridge()
	var js_path := JSON.stringify(web_path)
	var js_hex := JSON.stringify(expected_bytes.hex_encode())
	JavaScriptBridge.eval("window.__btlSaveAck.begin(%s, %s);" % [js_path, js_hex], true)

func poll_state() -> String:
	if _simulated_web: return _last_state
	if not OS.has_feature("web"): return "confirmed"
	install_bridge()
	var result: Variant = JavaScriptBridge.eval("window.__btlSaveAck.check();", true)
	var state := str(result)
	_dirty = (state == "pending")
	_last_state = state
	return state

func clear_dirty() -> void:
	_dirty = false
	if not OS.has_feature("web"): return
	install_bridge()
	JavaScriptBridge.eval("window.__btlSaveAck.clear();", true)

func _normalize_web_path(global_path: String) -> String:
	if global_path.begins_with("/userfs/"): return global_path
	if _simulated_web and not global_path.is_empty():
		var marker := global_path.find("user://")
		if marker >= 0: return "/userfs/" + global_path.substr(marker + 7)
		return "/userfs/" + global_path.trim_prefix("/")
	return ""
