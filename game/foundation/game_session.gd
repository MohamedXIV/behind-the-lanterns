class_name GameSession
extends RefCounted
## One committed aggregate and its stateless rules. No public mutable stores.

signal committed(revision: int)

const SCHEMA_VERSION: int = 1
var _definition: WorldDefinition
var _domains: Dictionary = {}
var _handlers: Dictionary = {}
var _state: Dictionary = {}
var _coordinator := SimulationCoordinator.new()
var _budget: int
var _busy: bool = false
var _closed: bool = false

static func create(definition: WorldDefinition, domains: Array, world_id: String, event_budget: int = 512) -> GameSession:
	if definition == null or not WorldData.id(world_id) or event_budget <= 0: return null
	var session := GameSession.new()
	session._definition = definition
	session._budget = event_budget
	var initial: Dictionary = {}
	var versions: Dictionary = {}
	for value in domains:
		if not value is SessionDomain: return null
		var domain: SessionDomain = value
		var key := domain.domain_id()
		if not WorldData.id(key) or session._domains.has(key) or not WorldData.integer(domain.schema_version(), 1): return null
		session._domains[key] = domain
		initial[key] = domain.initial_state().duplicate(true)
		versions[key] = domain.schema_version()
		for kind in domain.event_kinds():
			if not WorldData.id(kind) or session._handlers.has(kind): return null
			session._handlers[kind] = domain
	session._state = {"schema": SCHEMA_VERSION, "world_id": world_id,
		"content_hash": definition.fingerprint(), "revision": 0, "minute": 0,
		"next_entity": 1, "entities": definition.authored_entities(), "knowledge": {},
		"domains": initial, "domain_versions": versions,
		"scheduler": {"events": {}, "next_sequence": 1}, "commands": {}}
	if not session._validate_snapshot(session._state).is_empty(): return null
	return session

func definition() -> WorldDefinition:
	return _definition

func snapshot() -> Dictionary:
	return _state.duplicate(true)

func now() -> int:
	return _state.minute

func close() -> bool:
	if _busy: return false
	_closed = true
	return true

func is_closed() -> bool:
	return _closed

func advance_to(target: Variant) -> OperationResult:
	return _execute("", Callable(), target)

func transact(command_id: String, command: Callable, target: Variant = -1) -> OperationResult:
	if not WorldData.id(command_id) or not command.is_valid(): return OperationResult.failure("invalid_command")
	var default_target: bool = typeof(target) == TYPE_INT and target == -1
	return _execute(command_id, command, now() if default_target else target)

func _execute(command_id: String, command: Callable, target: Variant) -> OperationResult:
	if _closed: return OperationResult.failure("session_closed")
	if _busy: return OperationResult.failure("session_busy")
	if not WorldData.integer(target, now()): return OperationResult.failure("invalid_target")
	if not command_id.is_empty() and _state.commands.has(command_id): return OperationResult.success(0, "already_applied")
	if _state.revision >= WorldData.MAX_COUNTER: return OperationResult.failure("revision_exhausted")
	_busy = true
	var tx := WorldTransaction.new(_state, _definition, _handlers.keys())
	if command.is_valid():
		var answer: Variant = command.call(tx)
		if not answer is String or not answer.is_empty():
			_busy = false
			return OperationResult.failure(answer if answer is String else "command_protocol")
		if not tx._fault.is_empty():
			_busy = false
			return OperationResult.failure(tx._fault)
		# Validate before advancing so invalid command state never feeds events.
		var command_error := _validate_snapshot(tx.snapshot())
		if not command_error.is_empty():
			_busy = false
			return OperationResult.failure(command_error)
	var outcome := _coordinator.advance(tx, int(target), _handlers, _validate_snapshot, _budget)
	if outcome.ok:
		var candidate := tx.snapshot()
		var error := _validate_snapshot(candidate)
		if not error.is_empty():
			outcome = OperationResult.failure(error)
		elif candidate != _state or not command_id.is_empty():
			candidate.revision = _state.revision + 1
			if not command_id.is_empty(): candidate.commands[command_id] = true
			_state = candidate.duplicate(true)
			committed.emit(_state.revision)
	_busy = false
	return outcome

func restore_candidate(data: Variant) -> GameSession:
	# Fresh composition, never replace this live object's state.
	if not data is Dictionary or not WorldData.valid(data): return null
	var candidate := GameSession.create(_definition, _domains.values(), _state.world_id, _budget)
	if candidate == null: return null
	var normalized: Dictionary = WorldData.normalize(data)
	if not candidate._validate_snapshot(normalized).is_empty(): return null
	candidate._state = normalized.duplicate(true)
	return candidate

func _validate_snapshot(data: Dictionary) -> String:
	if not WorldData.valid(data) or not WorldData.keys(data, ["schema", "world_id", "content_hash", "revision", "minute", "next_entity", "entities", "knowledge", "domains", "domain_versions", "scheduler", "commands"]): return "snapshot_schema"
	if not WorldData.integer(data.schema, 1) or data.schema != SCHEMA_VERSION: return "snapshot_version"
	if not data.world_id is String or not data.content_hash is String: return "snapshot_world_or_content"
	if data.world_id != _state.world_id or data.content_hash != _definition.fingerprint(): return "snapshot_world_or_content"
	if not WorldData.integer(data.revision) or not WorldData.integer(data.minute) or not WorldData.integer(data.next_entity, 1): return "snapshot_counter"
	for field in ["entities", "knowledge", "domains", "domain_versions", "commands"]:
		if not data[field] is Dictionary: return "snapshot_store_type"
	var authored := _definition.authored_entities()
	for key in authored:
		if not data.entities.has(key): return "missing_authored_entity"
	for key in data.entities:
		var entity: Variant = data.entities[key]
		if not WorldData.id(key) or not WorldData.keys(entity, ["definition_id", "region_id"]): return "entity_schema"
		if not entity.definition_id is String or not entity.region_id is String: return "entity_schema"
		if not _definition.has_definition(entity.definition_id) or not _definition.has_region(entity.region_id): return "entity_reference"
		if authored.has(key):
			if entity.definition_id != authored[key].definition_id: return "authored_identity_changed"
		elif not key.begins_with("r:") or not key.trim_prefix("r:").is_valid_int(): return "runtime_identity"
		else:
			var number: int = key.trim_prefix("r:").to_int()
			if number < 1 or number >= data.next_entity or key != "r:%d" % number: return "runtime_allocator"
	for key in data.knowledge:
		if not _definition.has_claim(key) or not data.knowledge[key] in ["heard", "confirmed"]: return "knowledge_reference"
	for key in data.commands:
		if not WorldData.id(key) or not data.commands[key] is bool or data.commands[key] != true: return "command_receipt"
	if data.domains.size() != _domains.size() or data.domain_versions.size() != _domains.size(): return "domain_set"
	for key in _domains:
		var domain: SessionDomain = _domains[key]
		if not data.domains.has(key) or not data.domains[key] is Dictionary or not data.domain_versions.has(key): return "domain_schema"
		if not WorldData.integer(data.domain_versions[key], 1) or data.domain_versions[key] != domain.schema_version(): return "domain_version"
		var error := domain.validate(data.domains[key].duplicate(true), data.duplicate(true))
		if not error.is_empty(): return "domain:" + key + ":" + error
	var schedule_error := WorldScheduler.validate(data.scheduler, data.minute, data.entities, _handlers.keys())
	if not schedule_error.is_empty(): return schedule_error
	for event in data.scheduler.events.values():
		var handler: SessionDomain = _handlers[event.kind]
		var event_error := handler.validate_event(event.duplicate(true), data.duplicate(true))
		if not event_error.is_empty(): return "event:" + event.id + ":" + event_error
	return ""
