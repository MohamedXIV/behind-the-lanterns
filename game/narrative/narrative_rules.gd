class_name NarrativeRules
extends SessionDomain
## Knowledge lives in GameSession; conversations own only their bounded Ink history.
const DOMAIN: String = "narrative"
var _config: Dictionary
var _interactions: InteractionRules
var _work: WorkRules

static func create(config: Dictionary, world: Dictionary, interactions: InteractionRules, work: WorkRules) -> NarrativeRules:
	if not WorldData.keys(config, ["conversations", "discoveries", "journal"]): return null
	for field in config:
		if not config[field] is Dictionary: return null
	for claim in config.journal:
		if not claim in world.claims or not config.journal[claim] is String: return null
	for id in config.discoveries:
		var discovery: Variant = config.discoveries[id]
		if not id in interactions.target_ids() or not WorldData.keys(discovery, ["claim_id", "fact_id"]): return null
		if not discovery.claim_id in world.claims or not world.facts.has(discovery.fact_id) or not world.facts[discovery.fact_id]: return null
	for npc in config.conversations:
		var conversation: Variant = config.conversations[npc]
		if not npc in interactions.target_ids() or not WorldData.keys(conversation, ["compiled", "queries", "actions"]): return null
		if not conversation.compiled is String: return null
		var program: Variant = JSON.parse_string(conversation.compiled)
		if not program is Dictionary or program.get("inkVersion") != 21 or not program.get("root") is Array or program.root.is_empty() or not program.root[-1] is Dictionary: return null
		var declarations: Variant = program.root[-1].get("global decl", [])
		if not declarations is Array: return null
		var globals: Array = []
		for declaration in declarations:
			if declaration is Dictionary and declaration.has("VAR="): globals.append(declaration["VAR="])
		if not conversation.queries is Dictionary: return null
		for key in conversation.queries:
			if not key in globals: return null
		if not conversation.queries is Dictionary or not conversation.actions is Dictionary: return null
		for query in conversation.queries.values():
			if not WorldData.keys(query, ["kind", "id"]): return null
			if query.kind in ["confirmed", "heard"]:
				if not query.id in world.claims: return null
			elif query.kind == "reported":
				if not query.id in world.claims: return null
			elif query.kind in ["accepted", "completed"]:
				if not work.definitions().has(query.id): return null
			else: return null
		for action in conversation.actions.values():
			if not WorldData.keys(action, ["kind", "id"]): return null
			if action.kind == "hear":
				if not action.id in world.claims: return null
			elif action.kind == "report":
				if not action.id in world.claims or not config.journal.has(action.id): return null
			elif action.kind in ["accept_job", "deliver_job"]:
				if not work.definitions().has(action.id): return null
			else: return null
	var rules := NarrativeRules.new()
	rules._config = config.duplicate(true)
	rules._interactions = interactions
	rules._work = work
	return rules

func domain_id() -> String:
	return DOMAIN

func schema_version() -> int:
	return 2

func initial_state() -> Dictionary:
	return {"conversations": {}, "reports": {}}

func can_talk(npc_id: String) -> bool:
	return _config.conversations.has(npc_id)

func journal(snapshot: Dictionary, actor_id: String = "") -> String:
	var lines: PackedStringArray = []
	for claim in _config.journal:
		if snapshot.knowledge.has(claim): lines.append("%s%s · %s" % [snapshot.knowledge[claim].capitalize(), " / Reported" if snapshot.domains[DOMAIN].reports.get(actor_id, {}).has(claim) else "", _config.journal[claim]])
	return "No rumors or discoveries recorded yet." if lines.is_empty() else "\n".join(lines)

func conversation(snapshot: Dictionary, actor_id: String) -> Dictionary:
	return snapshot.domains[DOMAIN].conversations.get(actor_id, {}).duplicate(true)

func observe(tx: WorldTransaction, actor_id: String, target_id: String) -> String:
	if not _config.discoveries.has(target_id): return ""
	var error := _interactions.reach_error(tx, actor_id, target_id)
	if not error.is_empty(): return error
	return tx.discover(_config.discoveries[target_id].claim_id, "confirmed")

func _context(snapshot: Dictionary, actor_id: String, definition: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in definition.queries:
		var query: Dictionary = definition.queries[key]
		if query.kind in ["confirmed", "heard"]:
			result[key] = snapshot.knowledge.get(query.id, "") == "confirmed" if query.kind == "confirmed" else snapshot.knowledge.has(query.id)
		elif query.kind == "reported":
			result[key] = snapshot.domains[DOMAIN].reports.get(actor_id, {}).has(query.id)
		else:
			var job := _work.job_for(snapshot, actor_id, query.id)
			result[key] = job.get("status", "") == query.kind
	return result

func talk(tx: WorldTransaction, actor_id: String, npc_id: String, choice: Variant, expected_turns: int, expected_cursor: String = "") -> String:
	if not can_talk(npc_id): return "no_conversation"
	var error := _interactions.reach_error(tx, actor_id, npc_id)
	if not error.is_empty(): return error
	if not _interactions.available(npc_id, tx.now()): return "person_unavailable"
	var state := tx.read_domain(DOMAIN)
	var previous: Dictionary = state.conversations.get(actor_id, {})
	if not expected_cursor.is_empty() and cursor(previous) != expected_cursor: return "stale_conversation"
	var turns: Array = []
	var epoch: int = tx.snapshot().revision
	if choice != -1:
		if previous.is_empty() or previous.npc_id != npc_id or previous.turns.size() != expected_turns: return "stale_conversation"
		turns = previous.turns.duplicate(true)
		epoch = previous.epoch
	elif typeof(choice) != TYPE_INT: return "invalid_choice"
	var definition: Dictionary = _config.conversations[npc_id]
	turns.append({"choice": choice, "context": _context(tx.snapshot(), actor_id, definition)})
	var frame := InkDialogue.render(definition.compiled, turns)
	if frame.is_empty(): return "invalid_story_choice"
	for action_id in frame.actions:
		if not definition.actions.has(action_id): return "unknown_narrative_action"
		var action: Dictionary = definition.actions[action_id]
		if action.kind == "hear": error = tx.discover(action.id, "heard")
		elif action.kind == "report":
			if tx.snapshot().knowledge.get(action.id, "") != "confirmed": return "evidence_required"
			if not state.reports.has(actor_id): state.reports[actor_id] = {}
			state.reports[actor_id][action.id] = npc_id
		elif action.kind == "deliver_job": error = _work.deliver(tx, actor_id, action.id)
		else: error = _work.accept(tx, actor_id, action.id, "work.dialogue." + actor_id + "." + action.id)
		if not error.is_empty(): return error
	state.conversations[actor_id] = {"npc_id": npc_id, "turns": turns, "frame": frame, "epoch": epoch}
	return "" if tx.write_domain(DOMAIN, state) else "narrative_write_failed"

func validate(state: Dictionary, snapshot: Dictionary) -> String:
	if not WorldData.keys(state, ["conversations", "reports"]) or not state.conversations is Dictionary or not state.reports is Dictionary: return "narrative_schema"
	for actor in state.reports:
		if not actor in _interactions.actors() or not state.reports[actor] is Dictionary: return "report_schema"
		for claim in state.reports[actor]:
			if not _config.journal.has(claim) or snapshot.knowledge.get(claim) != "confirmed" or not state.reports[actor][claim] is String or not can_talk(state.reports[actor][claim]): return "report_evidence"
	for actor in state.conversations:
		var record: Variant = state.conversations[actor]
		if not actor in _interactions.actors() or not WorldData.keys(record, ["npc_id", "turns", "frame", "epoch"]): return "conversation_schema"
		if not WorldData.integer(record.epoch): return "conversation_epoch"
		if not record.npc_id is String or not can_talk(record.npc_id) or not record.turns is Array or record.turns.is_empty() or record.turns.size() > InkDialogue.MAX_TURNS: return "conversation_reference"
		var definition: Dictionary = _config.conversations[record.npc_id]
		for turn in record.turns:
			if not WorldData.keys(turn, ["choice", "context"]) or not turn.context is Dictionary or turn.context.size() != definition.queries.size(): return "conversation_context"
			for key in definition.queries:
				if not turn.context.get(key) is bool: return "conversation_context"
		if InkDialogue.render(definition.compiled, record.turns) != record.frame: return "conversation_replay"
	return ""

static func cursor(record: Dictionary) -> String:
	return JSON.stringify(record, "", true, true).sha256_text()

func observation_text(target_id: String) -> String:
	if not _config.discoveries.has(target_id): return ""
	return _config.journal.get(_config.discoveries[target_id].claim_id, "")
