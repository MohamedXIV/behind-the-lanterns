extends RefCounted

func run(t) -> void:
	if not ResourceLoader.exists("res://game/persistence/session_codec.gd"):
		t.check(false, "validated session codec and recovery implementation required")
		return
	var codec: Script = load("res://game/persistence/session_codec.gd")
	var store_script: Script = load("res://game/persistence/recovery_store.gd")
	_test_roundtrip(t, codec)
	_test_invalid_snapshots(t, codec)
	_test_recovery(t, codec, store_script)

func _test_roundtrip(t, codec: Script) -> void:
	var s = t.session()
	t.check(t.enqueue(s, [t.event("a", 5), t.event("b", 10)]).ok, "persistence fixture queued")
	t.check(s.advance_to(5).ok, "first occurrence committed before save")
	t.check(s.transact("claim", func(tx): return tx.discover("claim.passage", "confirmed")).ok, "knowledge committed before save")
	var before: Dictionary = s.snapshot()
	var encoded: String = codec.encode(s)
	t.check(not encoded.is_empty() and s.snapshot() == before, "encoding is read-only")
	var restored = codec.decode(encoded, s)
	t.check(restored != null and restored != s, "restore constructs a separate candidate")
	if restored == null: return
	t.check(restored.snapshot() == before, "all state, receipts and queue roundtrip")
	t.check(restored.advance_to(20).ok, "restored queue advances")
	t.check(restored.snapshot().domains.economy.visits == [["a", 5], ["b", 10]], "completed occurrence not replayed after load")
	t.check(restored.transact("claim", func(_tx): return "must_not_execute").ok, "command receipts survive reload")
	t.check(s.snapshot() == before, "candidate advancement never modifies original session")
	var envelope: Dictionary = JSON.parse_string(encoded)
	envelope.payload += " "
	t.check(codec.decode(JSON.stringify(envelope), s) == null, "payload corruption rejected by checksum")
	for bad in ["", "null", "[]", "{", "{}", encoded.substr(0, encoded.length() / 2)]:
		t.check(codec.decode(bad, s) == null, "malformed envelope rejected")
	t.check(codec.decode(encoded, t.session("two")) == null, "content fingerprint mismatch rejected")
	t.check(codec.decode(encoded, s).now() == 5, "loading does not add wall-clock elapsed time")

func _test_invalid_snapshots(t, codec: Script) -> void:
	var s = t.session()
	t.enqueue(s, [t.event("done", 5), t.event("pending", 10)])
	s.advance_to(5)
	var valid: Dictionary = s.snapshot()
	var cases: Array[Dictionary] = []
	for field in ["schema", "minute", "revision", "next_entity"]:
		for value in [-1, 0.5, true, "1", INF, NAN, 9007199254740992]:
			var bad := valid.duplicate(true)
			bad[field] = value
			cases.append(bad)
	var changes: Array[Callable] = [
		func(d): d.schema = 2,
		func(d): d.content_hash = "wrong",
		func(d): d.world_id = "other.world",
		func(d): d.unknown = true,
		func(d): d.domains.erase("growth"),
		func(d): d.domains.extra = {},
		func(d): d.domain_versions.growth = 2,
		func(d): d.entities.erase("a:fixture"),
		func(d): d.entities["a:fixture"].region_id = "unknown",
		func(d): d.entities["r:1"] = d.entities["a:fixture"].duplicate(),
		func(d): d.knowledge["unknown"] = "heard",
		func(d): d.knowledge["claim.passage"] = "invented",
		func(d): d.commands["fake"] = 1,
		func(d): d.scheduler.events.pending.kind = "unknown",
		func(d): d.scheduler.events.pending.kind = "fixture.chain", # Missing required payload.
		func(d): d.scheduler.events.pending.target_id = "r:404",
		func(d): d.scheduler.events.pending.due = 4,
		func(d): d.scheduler.events.done.due = 6,
		func(d): d.scheduler.events.pending.sequence = d.scheduler.events.done.sequence,
		func(d): d.scheduler.events.pending.status = "running",
		func(d): d.scheduler.next_sequence = 1,
		func(d): d.domains.economy.coins = -1,
		func(d): d.domains.growth.planted_at = 6,
	]
	for mutate in changes:
		var bad := valid.duplicate(true)
		mutate.call(bad)
		cases.append(bad)
	for field in valid:
		var bad := valid.duplicate(true)
		bad[field] = null
		cases.append(bad)
	for field in valid.scheduler.events.pending:
		var bad := valid.duplicate(true)
		bad.scheduler.events.pending[field] = null
		cases.append(bad)
	for index in cases.size():
		t.check(s.restore_candidate(cases[index]) == null, "invalid candidate rejected %d" % index)
	t.check(s.snapshot() == valid, "failed loads leave live session untouched")
	var envelope: Dictionary = JSON.parse_string(codec.encode(s))
	var body: Dictionary = JSON.parse_string(envelope.payload)
	body.snapshot.minute = -1
	envelope.payload = JSON.stringify(body)
	envelope.sha256 = envelope.payload.sha256_text()
	t.check(codec.decode(JSON.stringify(envelope), s) == null, "valid checksum cannot bypass schema validation")

func _test_recovery(t, codec: Script, store_script: Script) -> void:
	var directory := "user://foundation-tests-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var store = store_script.new(directory)
	var s = t.session()
	t.check(store.load_candidate(s) == null, "missing save returns no candidate")
	t.check(store.save(s).ok, "first native generation written")
	s.advance_to(10)
	t.check(store.save(s).ok, "second native generation written")
	t.check(store.load_candidate(s).now() == 10, "load selects newest valid generation")
	var b_path := directory.path_join("slot_b.json")
	var file := FileAccess.open(b_path, FileAccess.WRITE)
	file.store_string("truncated")
	file.close()
	var recovered = store.load_candidate(s)
	t.check(recovered != null and recovered.now() == 0, "corrupt newest generation falls back to intact previous")
	var orphan := FileAccess.open(directory.path_join("slot_b.json.tmp"), FileAccess.WRITE)
	orphan.store_string(codec.encode(s, 999))
	orphan.close()
	t.check(store.load_candidate(s).now() == 0, "uncommitted temp file ignored")
	# A directory at the inactive slot makes the real rename fail, with no fake I/O.
	DirAccess.remove_absolute(b_path)
	DirAccess.make_dir_absolute(b_path)
	t.check(not store.save(s).ok, "failed native publish returns failure")
	t.check(store.load_candidate(s).now() == 0, "failed publish preserves last valid generation")
	DirAccess.remove_absolute(b_path)
	t.check(store.save(s).ok and store.load_candidate(s).now() == 10, "explicit retry after storage repair")
	s.advance_to(20)
	t.check(store.save(s).ok and store.load_candidate(s).now() == 20, "third save replaces an existing inactive file")
	# Equal generations with different complete payloads are ambiguous, not guessed.
	for name in store_script.SLOT_NAMES:
		file = FileAccess.open(directory.path_join(name), FileAccess.WRITE)
		file.store_string(codec.encode(s if name == "slot_a.json" else t.session(), 7))
		file.close()
	t.check(store.load_candidate(s) == null and store.last_error == "ambiguous_generation", "split generation fails closed")
	t.check(not store.save(s).ok, "ambiguous generations are preserved for recovery")
	var invalid_directory := directory.path_join("blocked")
	file = FileAccess.open(invalid_directory, FileAccess.WRITE)
	file.store_string("not a directory")
	file.close()
	var blocked_store = store_script.new(invalid_directory)
	t.check(not blocked_store.save(s).ok, "unusable storage path cannot claim saved")
	# Only this test's owned paths are removed.
	for name in ["slot_a.json", "slot_b.json", "slot_a.json.tmp", "slot_b.json.tmp", "blocked"]:
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
