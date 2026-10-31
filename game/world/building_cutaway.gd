class_name BuildingCutaway
extends RefCounted
## Reusable 2D building cutaway and floor-visibility presentation rules (P03).
## Keeps global visible-floor selection distinct from camera/player-relative occlusion.
## Presentation-only: world geometry, housing access and inventory remain authoritative.

var _config: Dictionary = {}
var _layers: Dictionary = {}
var _furnishing_sprites: Dictionary = {}

static func create(config: Dictionary) -> BuildingCutaway:
	if not config is Dictionary or not WorldData.keys(config, ["fixture_id", "projection", "canvas", "footprint", "regions", "floors", "openings", "occlusion_zones", "layers", "furnishings"], ["schema_version", "noncanonical", "proof_sheet"]):
		return null
	if not config.fixture_id is String or config.fixture_id.is_empty(): return null
	if not config.projection is Dictionary or config.projection.get("kind", "") != "elevated_3_4_oblique" or config.projection.get("true_isometric", true) != false:
		return null
	if not config.footprint is Dictionary or not WorldData.keys(config.footprint, ["x", "y", "width", "height"]):
		return null
	if config.footprint.width <= 0 or config.footprint.height <= 0: return null
	if not config.regions is Dictionary or not WorldData.keys(config.regions, ["exterior_region", "interior_region", "property_id"]):
		return null
	if not config.floors is Array or config.floors.is_empty(): return null
	var seen_floors: Dictionary = {}
	for floor_row in config.floors:
		if not floor_row is Dictionary or not WorldData.keys(floor_row, ["floor_index", "label", "z_base", "wall_height"]):
			return null
		if not WorldData.integer(floor_row.floor_index, 0) or seen_floors.has(floor_row.floor_index):
			return null
		seen_floors[floor_row.floor_index] = true
	if not config.openings is Dictionary or not config.openings.has("courtyard_door"):
		return null
	var door: Variant = config.openings.courtyard_door
	if not door is Dictionary or not WorldData.keys(door, ["exterior_portal_id", "interior_portal_id", "wall", "x", "width", "z_bottom", "z_top", "exterior_anchor", "interior_anchor"]):
		return null
	if not config.occlusion_zones is Dictionary or not WorldData.keys(config.occlusion_zones, ["exterior_eave_occluder", "interior_front_wall_band"]):
		return null
	for zone_key in ["exterior_eave_occluder", "interior_front_wall_band"]:
		var z: Variant = config.occlusion_zones[zone_key]
		if not z is Dictionary or not WorldData.keys(z, ["x", "y", "width", "height", "fade_alpha"]):
			return null
		if z.width <= 0 or z.height <= 0 or float(z.fade_alpha) <= 0.0 or float(z.fade_alpha) >= 1.0:
			return null
	if not config.layers is Dictionary or not WorldData.keys(config.layers, ["shell", "interior", "front_wall", "roof", "upper_floor"]):
		return null
	if not config.furnishings is Dictionary:
		return null
	var cutaway := BuildingCutaway.new()
	cutaway._config = config.duplicate(true)
	for layer_name in config.layers:
		var path: String = str(config.layers[layer_name])
		var tex := _load_texture(path)
		if tex == null: return null
		cutaway._layers[layer_name] = tex
	for item_id in config.furnishings:
		var fspec: Variant = config.furnishings[item_id]
		if not fspec is Dictionary or not WorldData.keys(fspec, ["kind", "texture", "width", "height", "origin", "footprint"]):
			return null
		var ftex := _load_texture(str(fspec.texture))
		if ftex == null: return null
		cutaway._furnishing_sprites[item_id] = ftex
	return cutaway

static func load_from_manifest(manifest_path: String) -> BuildingCutaway:
	if not FileAccess.file_exists(manifest_path): return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary: return null
	return create(parsed)

static func _load_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return null
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D: return res
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(path)) == OK:
		return ImageTexture.create_from_image(img)
	return null


func fixture_id() -> String:
	return _config.fixture_id

func projection() -> Dictionary:
	return _config.projection.duplicate(true)

func footprint_rect() -> Rect2:
	var fp: Dictionary = _config.footprint
	return Rect2(float(fp.x), float(fp.y), float(fp.width), float(fp.height))

func canvas_rect_world() -> Rect2:
	var c: Dictionary = _config.canvas
	return Rect2(float(c.origin_world.x), float(c.origin_world.y), float(c.width), float(c.height))

func exterior_region() -> String:
	return _config.regions.exterior_region

func interior_region() -> String:
	return _config.regions.interior_region

func property_id() -> String:
	return _config.regions.property_id

func max_floor_index() -> int:
	var highest: int = 0
	for floor_row in _config.floors:
		highest = maxi(highest, int(floor_row.floor_index))
	return highest

func floor_label(floor_index: int) -> String:
	for floor_row in _config.floors:
		if int(floor_row.floor_index) == floor_index:
			return str(floor_row.label)
	return "Floor %d" % floor_index

func layer_texture(layer_name: String) -> Texture2D:
	return _layers.get(layer_name, null)

func has_furnishing_sprite(item_id: String) -> bool:
	return _furnishing_sprites.has(item_id)

func furnishing_texture(item_id: String) -> Texture2D:
	return _furnishing_sprites.get(item_id, null)

func furnishing_spec(item_id: String) -> Dictionary:
	return _config.furnishings.get(item_id, {}).duplicate(true)

func exterior_eave_rect() -> Rect2:
	var z: Dictionary = _config.occlusion_zones.exterior_eave_occluder
	return Rect2(float(z.x), float(z.y), float(z.width), float(z.height))

func interior_front_wall_rect() -> Rect2:
	var z: Dictionary = _config.occlusion_zones.interior_front_wall_band
	return Rect2(float(z.x), float(z.y), float(z.width), float(z.height))

## Evaluates building layer visibility and alpha from:
## 1) active `region_id` (exterior vs interior vs unrelated region),
## 2) global `visible_floor` selection (0 = ground floor, 1 = upper terrace/roof floor),
## 3) local `actor_pos` relative to roof eave / front-wall occlusion zones.
func evaluate_state(region_id: String, actor_pos: Vector2, visible_floor: int = 0) -> Dictionary:
	var clamped_floor := clampi(visible_floor, 0, max_floor_index())
	var eave_zone := exterior_eave_rect()
	var front_zone := interior_front_wall_rect()
	if region_id == exterior_region():
		var eave_occludes := eave_zone.has_point(actor_pos)
		var eave_alpha := float(_config.occlusion_zones.exterior_eave_occluder.fade_alpha)
		if clamped_floor >= 1:
			return {
				"active": true,
				"mode": "exterior_upper_floor",
				"visible_floor": clamped_floor,
				"local_occlusion": eave_occludes,
				"shell_alpha": 1.0,
				"interior_alpha": 0.45 if eave_occludes else 0.0,
				"front_wall_alpha": 0.45 if eave_occludes else 1.0,
				"upper_floor_alpha": 1.0,
				"roof_alpha": eave_alpha if eave_occludes else 1.0,
				"front_wall_y_sort": float(_config.footprint.y + _config.footprint.height),
			}
		return {
			"active": true,
			"mode": "exterior_occluded" if eave_occludes else "exterior_normal",
			"visible_floor": clamped_floor,
			"local_occlusion": eave_occludes,
			"shell_alpha": 1.0,
			"interior_alpha": 0.55 if eave_occludes else 0.0,
			"front_wall_alpha": 0.38 if eave_occludes else 1.0,
			"upper_floor_alpha": 0.0,
			"roof_alpha": eave_alpha if eave_occludes else 1.0,
			"front_wall_y_sort": float(_config.footprint.y + _config.footprint.height),
		}
	if region_id == interior_region():
		var behind_front_wall := front_zone.has_point(actor_pos)
		var front_fade := float(_config.occlusion_zones.interior_front_wall_band.fade_alpha)
		if clamped_floor >= 1:
			return {
				"active": true,
				"mode": "interior_upper_floor",
				"visible_floor": clamped_floor,
				"local_occlusion": behind_front_wall,
				"shell_alpha": 1.0,
				"interior_alpha": 0.45,
				"front_wall_alpha": front_fade if behind_front_wall else 0.62,
				"upper_floor_alpha": 1.0,
				"roof_alpha": 0.35,
				"front_wall_y_sort": float(_config.footprint.y + _config.footprint.height),
			}
		return {
			"active": true,
			"mode": "interior_front_occluded" if behind_front_wall else "interior_cutaway",
			"visible_floor": clamped_floor,
			"local_occlusion": behind_front_wall,
			"shell_alpha": 1.0,
			"interior_alpha": 1.0,
			"front_wall_alpha": front_fade if behind_front_wall else 0.42,
			"upper_floor_alpha": 0.0,
			"roof_alpha": 0.0,
			"front_wall_y_sort": float(_config.footprint.y + _config.footprint.height),
		}
	return {
		"active": false,
		"mode": "inactive",
		"visible_floor": clamped_floor,
		"local_occlusion": false,
		"shell_alpha": 0.0,
		"interior_alpha": 0.0,
		"front_wall_alpha": 0.0,
		"upper_floor_alpha": 0.0,
		"roof_alpha": 0.0,
		"front_wall_y_sort": 0.0,
	}
