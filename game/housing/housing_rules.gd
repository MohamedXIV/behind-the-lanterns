class_name HousingRules
extends SessionDomain
## Property permission and physical furniture identity; goods remain in Inventory.
const DOMAIN: String = "housing"
var _config: Dictionary
var _interactions: InteractionRules
var _commerce: CommerceRules

static func create(config: Dictionary, world: Dictionary, interactions: InteractionRules, commerce: CommerceRules) -> HousingRules:
	if not WorldData.valid(config) or not WorldData.keys(config, ["properties", "furnishings"]): return null
	if not config.properties is Dictionary or not config.furnishings is Dictionary: return null
	var rules := HousingRules.new()
	rules._config = config.duplicate(true)
	rules._interactions = interactions
	rules._commerce = commerce
	for id in world.entities: rules._entity_regions[id] = world.entities[id].region_id
	var regions: Dictionary = {}
	for id in config.properties:
		var row: Variant = config.properties[id]
		if not WorldData.id(id) or not WorldData.keys(row, ["label", "region_id", "provider_id", "price", "initial_resident", "floor_index", "cells"]): return null
		if not WorldData.integer(row.floor_index, 0) or not row.label is String or row.label.is_empty() or not row.region_id in world.regions or regions.has(row.region_id): return null
		regions[row.region_id] = true
		if not row.provider_id in interactions.target_ids() or not commerce.has_wallet(row.provider_id) or not WorldData.integer(row.price, 0): return null
		if row.initial_resident != "" and not row.initial_resident in interactions.actors(): return null
		if not row.cells is Dictionary or row.cells.is_empty(): return null
		for cell_id in row.cells:
			var cell: Variant = row.cells[cell_id]
			if not WorldData.id(cell_id) or not WorldData.keys(cell, ["x", "y", "width", "height"]): return null
			for value in cell.values():
				if not WorldData.integer(value, 0): return null
			if cell.width <= 0 or cell.height <= 0: return null
	for id in config.furnishings:
		var row: Variant = config.furnishings[id]
		if not WorldData.id(id) or not WorldData.keys(row, ["label", "owner_id", "property_id", "cell_id", "width", "height", "storage"]): return null
		if not row.label is String or row.label.is_empty() or not row.owner_id in interactions.actors(): return null
		if not id in world.entities or not id in interactions.target_ids(): return null
		if not row.property_id in config.properties or not row.cell_id in config.properties[row.property_id].cells: return null
		if not WorldData.integer(row.width, 1) or not WorldData.integer(row.height, 1) or not row.storage is bool: return null
		if row.storage:
			var container := interactions._inventory.container_definition(id)
			if container.is_empty() or container.owner_id != row.owner_id or container.access != "owner": return null
		elif id in interactions._inventory.container_ids(): return null
	return rules

func domain_id() -> String:
	return DOMAIN

func properties() -> Dictionary:
	return _config.properties.duplicate(true)

func furnishings() -> Dictionary:
	return _config.furnishings.duplicate(true)

func initial_state() -> Dictionary:
	var residents: Dictionary = {}
	for id in _config.properties: residents[id] = _config.properties[id].initial_resident
	var placements: Dictionary = {}
	for id in _config.furnishings:
		var row: Dictionary = _config.furnishings[id]
		placements[id] = {"property_id": row.property_id, "cell_id": row.cell_id}
	return {"residents": residents, "placements": placements}

func property_for(region_id: String) -> String:
	for id in _config.properties:
		if _config.properties[id].region_id == region_id: return id
	return ""

func can_access(snapshot: Dictionary, actor: String, property_id: String) -> bool:
	return snapshot.domains[DOMAIN].residents.get(property_id, "") == actor and actor in _interactions.actors()

func region_error(snapshot: Dictionary, actor: String, region_id: String) -> String:
	var property_id := property_for(region_id)
	return "housing_access_denied" if not property_id.is_empty() and not can_access(snapshot, actor, property_id) else ""

func acquire(tx: WorldTransaction, actor: String, property_id: String) -> String:
	if not property_id in _config.properties: return "unknown_property"
	if not actor in _interactions.actors(): return "unknown_actor"
	var row: Dictionary = _config.properties[property_id]
	var state := tx.read_domain(DOMAIN)
	if state.residents[property_id] != "": return "property_already_assigned"
	var error := _interactions.reach_error(tx, actor, row.provider_id)
	if not error.is_empty(): return error
	if not _interactions.available(row.provider_id, tx.now()): return "person_unavailable"
	if row.price > 0:
		error = _commerce.transfer_funds(tx, actor, row.provider_id, row.price)
		if not error.is_empty(): return error
	state.residents[property_id] = actor
	return "" if tx.write_domain(DOMAIN, state) else "housing_write_failed"

func position(snapshot: Dictionary, id: String) -> Vector2:
	var placement: Dictionary = snapshot.domains[DOMAIN].placements.get(id, {})
	if placement.is_empty() or placement.property_id == "": return Vector2.INF
	var cell: Dictionary = _config.properties[placement.property_id].cells[placement.cell_id]
	return Vector2(cell.x + cell.width / 2.0, cell.y + cell.height / 2.0)

func usable(snapshot: Dictionary, actor: String, id: String) -> bool:
	if not id in _config.furnishings: return true
	var placement: Dictionary = snapshot.domains[DOMAIN].placements[id]
	return placement.property_id != "" and _config.furnishings[id].owner_id == actor and can_access(snapshot, actor, placement.property_id)

func pack(tx: WorldTransaction, actor: String, id: String) -> String:
	if not id in _config.furnishings: return "unknown_furnishing"
	if not usable(tx.snapshot(), actor, id): return "housing_access_denied"
	var error := _interactions.reach_error(tx, actor, id)
	if not error.is_empty(): return error
	var state := tx.read_domain(DOMAIN)
	state.placements[id] = {"property_id": "", "cell_id": ""}
	return "" if tx.write_domain(DOMAIN, state) else "housing_write_failed"

func placement_error(snapshot: Dictionary, actor: String, id: String, property_id: String, cell_id: String) -> String:
	if not id in _config.furnishings or not property_id in _config.properties: return "unknown_housing_reference"
	if _config.furnishings[id].owner_id != actor or not can_access(snapshot, actor, property_id): return "housing_access_denied"
	var property: Dictionary = _config.properties[property_id]
	if snapshot.entities.get(actor, {}).get("region_id", "") != property.region_id: return "different_region"
	if not cell_id in property.cells: return "invalid_placement_cell"
	var cell: Dictionary = property.cells[cell_id]
	var furnishing: Dictionary = _config.furnishings[id]
	if furnishing.width > cell.width or furnishing.height > cell.height: return "furnishing_does_not_fit"
	for other in snapshot.domains[DOMAIN].placements:
		var placed: Dictionary = snapshot.domains[DOMAIN].placements[other]
		if other != id and placed.property_id == property_id and placed.cell_id == cell_id: return "placement_occupied"
	var space_error := _space_error(property_id, cell_id)
	if not space_error.is_empty(): return space_error
	var previous: Dictionary = snapshot.domains[DOMAIN].placements[id]
	if previous.property_id != "":
		if not usable(snapshot, actor, id): return "housing_access_denied"
		if snapshot.entities[id].region_id != property.region_id: return "pack_before_travel"
		if _interactions.position_of(snapshot, actor).distance_to(position(snapshot, id)) > _interactions.reach(): return "out_of_reach"
		if not _interactions.reach_geometry(snapshot, property.region_id, id).clear_segment(_interactions.position_of(snapshot, actor), position(snapshot, id)): return "interaction_obstructed"
	var candidate := snapshot.duplicate(true)
	candidate.domains[DOMAIN].placements[id] = {"property_id": property_id, "cell_id": cell_id}
	candidate.entities[id].region_id = property.region_id
	return validate(candidate.domains[DOMAIN], candidate)

func place(tx: WorldTransaction, actor: String, id: String, property_id: String, cell_id: String) -> String:
	var error := placement_error(tx.snapshot(), actor, id, property_id, cell_id)
	if not error.is_empty(): return error
	var state := tx.read_domain(DOMAIN)
	var previous: Dictionary = state.placements[id]
	if previous.property_id != "":
		if not usable(tx.snapshot(), actor, id): return "housing_access_denied"
		error = _interactions.reach_error(tx, actor, id)
		if not error.is_empty(): return error
	state.placements[id] = {"property_id": property_id, "cell_id": cell_id}
	error = tx.move_entity(id, _config.properties[property_id].region_id)
	if not error.is_empty(): return error
	return "" if tx.write_domain(DOMAIN, state) else "housing_write_failed"

func geometry(snapshot: Dictionary, region_id: String, excluded_target: String = "") -> WorldGeometry:
	var source := _interactions.geometry_for(region_id)
	var result := WorldGeometry.new()
	result.extent = source.extent
	result.radius = source.radius
	result.blocks = source.blocks.duplicate()
	for id in snapshot.domains[DOMAIN].placements:
		var placed: Dictionary = snapshot.domains[DOMAIN].placements[id]
		if id == excluded_target: continue
		if placed.property_id == "" or _config.properties[placed.property_id].region_id != region_id: continue
		var cell: Dictionary = _config.properties[placed.property_id].cells[placed.cell_id]
		result.blocks.append(Rect2(cell.x, cell.y, cell.width, cell.height))
	return result

func _space_error(property_id: String, cell_id: String) -> String:
	var property: Dictionary = _config.properties[property_id]
	var cell: Dictionary = property.cells[cell_id]
	var rect := Rect2(cell.x, cell.y, cell.width, cell.height)
	var geometry := _interactions.geometry_for(property.region_id)
	if not Rect2(Vector2.ZERO, geometry.extent).encloses(rect): return "placement_out_of_bounds"
	for block in geometry.blocks:
		if rect.intersects(block.grow(geometry.radius)): return "placement_blocked"
	# Authored cells are isolated furniture islands. Reserve the approach perimeter,
	# all portal landing/exit space and every static interaction's usable space.
	for id in _interactions.target_ids():
		if id in _config.furnishings or id in _interactions.actors(): continue
		var point: Dictionary = _interactions._config.positions[id]
		if _world_region(id) == property.region_id and rect.grow(geometry.radius + 24).has_point(Vector2(point.x, point.y)): return "placement_blocks_use"
	for portal in _interactions._portals.values():
		if portal.region_id == property.region_id and rect.grow(geometry.radius + 24).has_point(Vector2(portal.x, portal.y)): return "placement_blocks_entry"
	for other_id in property.cells:
		if other_id == cell_id: continue
		var other: Dictionary = property.cells[other_id]
		if rect.grow(geometry.radius + 12).intersects(Rect2(other.x, other.y, other.width, other.height)): return "placement_cells_too_close"
	return ""

var _entity_regions: Dictionary = {}
func _world_region(id: String) -> String:
	return _entity_regions.get(id, "")

func validate(state: Dictionary, snapshot: Dictionary) -> String:
	if not WorldData.keys(state, ["residents", "placements"]) or not state.residents is Dictionary or not state.placements is Dictionary: return "housing_schema"
	if state.residents.size() != _config.properties.size() or state.placements.size() != _config.furnishings.size(): return "housing_identity_set"
	for property_id in _config.properties:
		if not state.residents.has(property_id): return "property_reference"
		var resident: Variant = state.residents[property_id]
		if not resident is String or (resident != "" and not resident in _interactions.actors()): return "resident_reference"
		if _config.properties[property_id].initial_resident != "" and resident != _config.properties[property_id].initial_resident: return "initial_resident_changed"
	for actor in _interactions.actors():
		var error := region_error(snapshot, actor, snapshot.entities[actor].region_id)
		if not error.is_empty(): return error
	var occupied: Dictionary = {}
	for id in _config.furnishings:
		if not state.placements.has(id) or not snapshot.entities.has(id): return "furnishing_identity"
		var placement: Variant = state.placements[id]
		if not WorldData.keys(placement, ["property_id", "cell_id"]) or not placement.property_id is String or not placement.cell_id is String: return "placement_schema"
		if placement.property_id == "":
			if placement.cell_id != "": return "packed_cell"
			continue
		if not placement.property_id in _config.properties: return "placement_property_reference"
		var property: Dictionary = _config.properties[placement.property_id]
		if not placement.cell_id in property.cells or snapshot.entities[id].region_id != property.region_id: return "placement_region_or_cell"
		if state.residents[placement.property_id] != _config.furnishings[id].owner_id: return "placement_access"
		var cell: Dictionary = property.cells[placement.cell_id]
		if _config.furnishings[id].width > cell.width or _config.furnishings[id].height > cell.height: return "placement_fit"
		var key: String = placement.property_id + ":" + placement.cell_id
		if occupied.has(key): return "placement_duplicate_cell"
		occupied[key] = true
		var error := _space_error(placement.property_id, placement.cell_id)
		if not error.is_empty(): return error
	for property_id in _config.properties:
		var region_id: String = _config.properties[property_id].region_id
		var local := geometry(snapshot, region_id)
		var anchors: Array[Vector2] = []
		for actor in _interactions.actors():
			if snapshot.entities[actor].region_id == region_id:
				var actor_at := _interactions.position_of(snapshot, actor)
				if not local.walkable(actor_at): return "placement_blocks_actor"
				anchors.append(actor_at)
		for portal in _interactions._portals.values():
			if portal.region_id == region_id: anchors.append(Vector2(portal.x, portal.y))
		for id in _interactions.target_ids():
			if id in _config.furnishings or id in _interactions.actors() or snapshot.entities[id].region_id != region_id: continue
			anchors.append(_interactions.position_of(snapshot, id))
		for id in state.placements:
			var placed: Dictionary = state.placements[id]
			if placed.property_id != property_id: continue
			var cell: Dictionary = _config.properties[property_id].cells[placed.cell_id]
			anchors.append(Vector2(cell.x + cell.width / 2.0, cell.y + cell.height + local.radius + 2))
		if not anchors.is_empty():
			for point in anchors:
				if not local.walkable(point) or local.route(anchors[0], point).is_empty(): return "placement_blocks_route"
	return ""

