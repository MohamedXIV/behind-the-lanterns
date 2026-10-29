class_name OperationResult
extends RefCounted
## Stable machine-readable failure plus the blocking occurrence, where applicable.

var ok: bool
var code: String
var event_id: String
var events_processed: int

static func success(processed: int = 0, status: String = "ok") -> OperationResult:
	var result := OperationResult.new()
	result.ok = true
	result.code = status
	result.events_processed = processed
	return result

static func failure(reason: String, occurrence: String = "") -> OperationResult:
	var result := OperationResult.new()
	result.code = reason
	result.event_id = occurrence
	return result
