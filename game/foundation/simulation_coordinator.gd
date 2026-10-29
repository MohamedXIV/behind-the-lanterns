class_name SimulationCoordinator
extends RefCounted
## Chronology only. Domain handlers own rules; caller owns publish/rollback.

func advance(tx: WorldTransaction, target: int, handlers: Dictionary, validator: Callable, budget: int) -> OperationResult:
	var processed: int = 0
	while true:
		var event := tx._scheduler.next_due(target)
		if event.is_empty():
			if not tx._clock.advance_to(target): return OperationResult.failure("invalid_target")
			return OperationResult.success(processed)
		if processed >= budget: return OperationResult.failure("event_budget_exceeded", event.id)
		if not handlers.has(event.kind): return OperationResult.failure("unknown_event_kind", event.id)
		if not tx._clock.advance_to(event.due): return OperationResult.failure("event_in_past", event.id)
		var handler: SessionDomain = handlers[event.kind]
		tx._executing_event = event.id
		var error: String = handler.handle_event(event.duplicate(true), tx)
		tx._executing_event = ""
		if not error.is_empty(): return OperationResult.failure(error, event.id)
		if not tx._fault.is_empty(): return OperationResult.failure(tx._fault, event.id)
		tx._scheduler.complete(event.id)
		error = validator.call(tx.snapshot())
		if not error.is_empty(): return OperationResult.failure(error, event.id)
		processed += 1
	return OperationResult.failure("unreachable")
