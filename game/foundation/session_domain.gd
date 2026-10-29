class_name SessionDomain
extends RefCounted
## Stateless domain rules. All mutable data belongs to the candidate/session.
## Validators and handlers must be synchronous, deterministic and free of I/O.

func domain_id() -> String:
	return ""

func schema_version() -> int:
	return 1

func initial_state() -> Dictionary:
	return {}

func validate(_state: Dictionary, _snapshot: Dictionary) -> String:
	return "validator_not_implemented"

func event_kinds() -> Array[String]:
	return []

func validate_event(_event: Dictionary, _snapshot: Dictionary) -> String:
	return "event_validator_not_implemented"

func handle_event(_event: Dictionary, _transaction: WorldTransaction) -> String:
	return "unhandled_event"
