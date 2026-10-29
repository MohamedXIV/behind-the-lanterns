class_name WorldData
extends RefCounted
## Shared wire-format rules, not gameplay validation.

const MAX_COUNTER: int = 2147483647
const MAX_SAFE_INTEGER: int = 9007199254740991
const ID_CHARACTERS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:-"

static func id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 128:
		return false
	for character in value:
		if not character in ID_CHARACTERS:
			return false
	return true

static func integer(value: Variant, minimum: int = 0, maximum: int = MAX_COUNTER) -> bool:
	if not typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func keys(value: Variant, required: Array, optional: Array = []) -> bool:
	if not value is Dictionary or not value.has_all(required):
		return false
	for key in value:
		if not key in required and not key in optional:
			return false
	return true

static func valid(value: Variant, depth: int = 0) -> bool:
	if depth > 16:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return true
		TYPE_INT:
			return value >= -MAX_SAFE_INTEGER and value <= MAX_SAFE_INTEGER
		TYPE_FLOAT:
			return is_finite(value) and absf(value) <= float(MAX_SAFE_INTEGER)
		TYPE_ARRAY:
			for entry in value:
				if not valid(entry, depth + 1): return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				# Godot's dictionary.property assignment creates StringName keys.
				if not typeof(key) in [TYPE_STRING, TYPE_STRING_NAME] or not valid(value[key], depth + 1): return false
			return true
	return false

static func normalize(value: Variant) -> Variant:
	# Godot JSON reads numbers as floats. Restore exact safe integral values.
	if value is float and is_finite(value) and value == floor(value) and absf(value) <= float(MAX_SAFE_INTEGER):
		return int(value)
	if value is Array:
		var result: Array = []
		for entry in value: result.append(normalize(entry))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[String(key)] = normalize(value[key])
		return result
	return value
