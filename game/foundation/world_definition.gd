class_name WorldDefinition
extends RefCounted
## Immutable, validated authored identities. No live scene references.

var _data: Dictionary
var _fingerprint: String

static func create(data: Dictionary, rules_content: Dictionary = {}) -> WorldDefinition:
	if not WorldData.keys(data, ["regions", "definitions", "entities", "facts", "claims"]) or not WorldData.valid(data):
		return null
	if not WorldData.valid(rules_content): return null
	for field in ["regions", "definitions", "claims"]:
		if not data[field] is Array: return null
		var seen: Dictionary = {}
		for key in data[field]:
			if not WorldData.id(key) or seen.has(key): return null
			seen[key] = true
	if data.regions.is_empty() or data.definitions.is_empty() or not data.entities is Dictionary or not data.facts is Dictionary:
		return null
	for key in data.entities:
		if not WorldData.id(key) or not key.begins_with("a:"): return null
		var entity: Variant = data.entities[key]
		if not WorldData.keys(entity, ["definition_id", "region_id"]): return null
		if not entity.definition_id in data.definitions or not entity.region_id in data.regions: return null
	for key in data.facts:
		if not WorldData.id(key) or not data.facts[key] is bool: return null
	var definition := WorldDefinition.new()
	definition._data = data.duplicate(true)
	definition._fingerprint = JSON.stringify(data, "", true, true).sha256_text()
	if not rules_content.is_empty():
		definition._fingerprint = JSON.stringify({"world": data, "rules": rules_content}, "", true, true).sha256_text()
	return definition

func fingerprint() -> String:
	return _fingerprint

func has_region(region_id: String) -> bool:
	return region_id in _data.regions

func has_definition(definition_id: String) -> bool:
	return definition_id in _data.definitions

func has_claim(claim_id: String) -> bool:
	return claim_id in _data.claims

func fact(fact_id: String) -> bool:
	return _data.facts.get(fact_id, false)

func authored_entities() -> Dictionary:
	return _data.entities.duplicate(true)
