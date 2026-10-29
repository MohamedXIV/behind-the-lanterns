extends "res://game/foundation/session_domain.gd"
## Disposable cross-domain rules. Not a Farming/Economy implementation.

var _id: String

func _init(id: String = "growth") -> void:
	_id = id

func domain_id() -> String:
	return _id

func initial_state() -> Dictionary:
	if _id == "growth":
		return {"planted_at": 0, "growth_minutes": 4320, "harvested": false}
	return {"coins": 0, "visits": []}

func validate(state: Dictionary, snapshot: Dictionary) -> String:
	if _id == "growth":
		if state.keys().size() != 3 or not state.has_all(["planted_at", "growth_minutes", "harvested"]):
			return "growth_schema"
		if typeof(state.harvested) != TYPE_BOOL or not state.planted_at is int or not state.growth_minutes is int:
			return "growth_types"
		if state.planted_at < 0 or state.planted_at > snapshot.minute or state.growth_minutes <= 0:
			return "growth_anchor"
	else:
		if state.keys().size() != 2 or not state.has_all(["coins", "visits"]):
			return "economy_schema"
		if not state.coins is int or state.coins < 0 or not state.visits is Array:
			return "economy_invariant"
	return ""

func event_kinds() -> Array[String]:
	if _id == "growth":
		return ["fixture.sell", "fixture.fail", "fixture.chain"]
	return ["fixture.note"]

func validate_event(event: Dictionary, _snapshot: Dictionary) -> String:
	if event.kind == "fixture.chain":
		if not WorldData.keys(event.payload, ["remaining"]) or not WorldData.integer(event.payload.remaining, 0, 64):
			return "chain_payload"
	elif not event.payload.is_empty():
		return "unexpected_payload"
	return ""

func handle_event(event: Dictionary, tx: WorldTransaction) -> String:
	var money := tx.read_domain("economy")
	if event.kind == "fixture.note":
		money.visits.append([event.id, tx.now()])
		tx.write_domain("economy", money)
		return ""
	if event.kind == "fixture.chain":
		money.visits.append([event.id, tx.now()])
		tx.write_domain("economy", money)
		var remaining: int = event.payload.remaining
		if remaining > 0:
			return tx.schedule({"id": event.id + ".next", "kind": event.kind,
				"target_id": event.target_id, "due": tx.now(), "payload": {"remaining": remaining - 1}})
		return ""
	var crop := tx.read_domain("growth")
	if event.kind == "fixture.fail":
		money.coins += 100
		crop.harvested = true
		tx.write_domain("growth", crop)
		tx.write_domain("economy", money)
		tx.schedule({"id": "leak", "kind": "fixture.note", "target_id": event.target_id, "due": tx.now()})
		return "intentional_failure"
	# The projection uses the event timestamp, never the skip end or a loaded Node.
	if not crop.harvested and tx.now() - crop.planted_at >= crop.growth_minutes:
		crop.harvested = true
		money.coins += 7
		tx.write_domain("growth", crop)
		tx.write_domain("economy", money)
	return ""
