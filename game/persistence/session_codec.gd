class_name SessionCodec
extends RefCounted
## Exact payload bytes are checksummed, avoiding numeric reserialization ambiguity.

const FORMAT: String = "btl-session-v1"
const MAX_BYTES: int = 8 * 1024 * 1024

static func encode(session: GameSession, generation: int = 0) -> String:
	if session == null or not WorldData.integer(generation): return ""
	var payload := JSON.stringify({"generation": generation, "snapshot": session.snapshot()}, "", true, true)
	var encoded := JSON.stringify({"format": FORMAT, "payload": payload, "sha256": payload.sha256_text()})
	return encoded if encoded.to_utf8_buffer().size() <= MAX_BYTES else ""

static func decode(text: String, composition: GameSession) -> GameSession:
	return inspect(text, composition).get("session")

static func inspect(text: String, composition: GameSession) -> Dictionary:
	if composition == null or text.is_empty() or text.to_utf8_buffer().size() > MAX_BYTES: return {}
	var parser := JSON.new()
	if parser.parse(text) != OK: return {}
	var envelope: Variant = parser.data
	if not WorldData.keys(envelope, ["format", "payload", "sha256"]): return {}
	if not envelope.format is String or not envelope.payload is String or not envelope.sha256 is String: return {}
	if envelope.format != FORMAT: return {}
	if envelope.payload.sha256_text() != envelope.sha256: return {}
	if parser.parse(envelope.payload) != OK: return {}
	var body: Variant = parser.data
	if not WorldData.keys(body, ["generation", "snapshot"]) or not WorldData.integer(body.generation): return {}
	var candidate := composition.restore_candidate(body.snapshot)
	if candidate == null: return {}
	return {"session": candidate, "generation": int(body.generation), "digest": envelope.sha256}
