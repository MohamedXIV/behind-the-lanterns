extends RefCounted

func manifest_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://dev/art/cutaway_fixture/manifest.json"))

func spec_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://dev/art/building_fixture_spec.json"))

func world_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))

func run(t) -> void:
	var spec := spec_data()
	var manifest := manifest_data()
	var cutaway := BuildingCutaway.load_from_manifest("res://dev/art/cutaway_fixture/manifest.json")
	t.check(cutaway != null, "building cutaway loads manifest and separable 2D layer textures")
	if cutaway == null: return

	# 1. Fixed elevated 3/4 oblique projection (not true isometric) & exterior/interior footprint match.
	var proj := cutaway.projection()
	t.check(proj.get("kind") == "elevated_3_4_oblique" and proj.get("true_isometric") == false, "building uses fixed elevated 3/4 oblique projection, never true isometric")
	t.check(cutaway.footprint_rect() == Rect2(float(spec.footprint.x), float(spec.footprint.y), float(spec.footprint.width), float(spec.footprint.height)), "manifest footprint matches authoritative building spec")
	for layer_name in ["shell", "interior", "front_wall", "roof", "upper_floor"]:
		var tex := cutaway.layer_texture(layer_name)
		t.check(tex != null and tex.get_width() == int(manifest.canvas.width) and tex.get_height() == int(manifest.canvas.height), "separable 2D pass loaded with matching canvas extent: " + layer_name)

	# 2. Detachable furniture sprites match HousingRules furnishing definitions without baking into interior room floor.
	var m := GameplayModel.create(world_data(), "world.cutaway-test")
	t.check(m != null and m.housing != null, "world model composes alongside cutaway presentation")
	if m == null: return
	for fid in ["a:housing-chest", "a:lamp", "a:cushion"]:
		var fspec := cutaway.furnishing_spec(fid)
		var hdef: Dictionary = m.housing.furnishings()[fid]
		t.check(cutaway.has_furnishing_sprite(fid) and cutaway.furnishing_texture(fid) != null, "detachable sprite loaded for furnishing: " + fid)
		t.check(int(fspec.footprint.width) == int(hdef.width) and int(fspec.footprint.height) == int(hdef.height), "detachable sprite footprint matches HousingRules logical dimensions: " + fid)

	# Verify interior floor layer has no baked furniture at cell.0 (208, 60) vs cell.1 (308, 60): both empty cells share the repeatable tile pattern.
	var interior_img := cutaway.layer_texture("interior").get_image()
	var ox := float(manifest.canvas.origin_world.x)
	var oy := float(manifest.canvas.origin_world.y)
	var sample_cell0 := interior_img.get_pixel(int(208 - ox), int(60 - oy))
	var sample_cell2 := interior_img.get_pixel(int(488 - ox), int(60 - oy))
	t.check(sample_cell0.a > 0.9 and sample_cell2.a > 0.9 and sample_cell0 == sample_cell2, "interior floor pass contains clean tile pattern without baked-in furniture at placement cells")

	# 3. Separation between global visible-floor selection and local camera/player occlusion.
	var ext_clear := cutaway.evaluate_state("region.playground", Vector2(360, 220), 0)
	t.check(ext_clear.active and ext_clear.mode == "exterior_normal" and ext_clear.visible_floor == 0 and not ext_clear.local_occlusion, "courtyard far from doorway presents normal exterior")
	t.check(is_equal_approx(float(ext_clear.roof_alpha), 1.0) and is_equal_approx(float(ext_clear.front_wall_alpha), 1.0) and is_equal_approx(float(ext_clear.interior_alpha), 0.0), "normal exterior shows opaque roof and front wall with hidden interior")

	var ext_occluded := cutaway.evaluate_state("region.playground", Vector2(40, 60), 0)
	t.check(ext_occluded.active and ext_occluded.mode == "exterior_occluded" and ext_occluded.local_occlusion, "approaching exterior doorway under roof eave triggers local occlusion")
	t.check(float(ext_occluded.roof_alpha) < 0.35 and float(ext_occluded.front_wall_alpha) < 0.45 and float(ext_occluded.interior_alpha) > 0.4, "exterior eave occlusion fades roof/front wall and reveals doorway interior")

	var ext_upper := cutaway.evaluate_state("region.playground", Vector2(360, 220), 1)
	t.check(ext_upper.mode == "exterior_upper_floor" and ext_upper.visible_floor == 1 and not ext_upper.local_occlusion and is_equal_approx(float(ext_upper.upper_floor_alpha), 1.0), "global floor 1 selection activates upper terrace layer independently of local occlusion")

	var int_normal := cutaway.evaluate_state("region.inn", Vector2(208, 100), 0)
	t.check(int_normal.active and int_normal.mode == "interior_cutaway" and not int_normal.local_occlusion, "entering interior switches to floor 0 cutaway presentation")
	t.check(is_equal_approx(float(int_normal.roof_alpha), 0.0) and is_equal_approx(float(int_normal.interior_alpha), 1.0) and float(int_normal.front_wall_alpha) < 0.5, "interior cutaway hides roof, shows full interior floor, and semi-fades south wall")

	var int_behind_front := cutaway.evaluate_state("region.inn", Vector2(100, 300), 0)
	t.check(int_behind_front.mode == "interior_front_occluded" and int_behind_front.local_occlusion and float(int_behind_front.front_wall_alpha) < float(int_normal.front_wall_alpha), "standing behind south facade inside room fades front-wall occluder further for player readability")

	var int_upper := cutaway.evaluate_state("region.inn", Vector2(208, 100), 1)
	t.check(int_upper.mode == "interior_upper_floor" and int_upper.visible_floor == 1 and is_equal_approx(float(int_upper.upper_floor_alpha), 1.0) and float(int_upper.roof_alpha) > 0.0, "selecting global floor 1 while indoors displays upper floor parapet independently of player position")
	var int_upper_occluded := cutaway.evaluate_state("region.inn", Vector2(100, 300), 1)
	t.check(int_upper_occluded.visible_floor == 1 and int_upper_occluded.local_occlusion and float(int_upper_occluded.front_wall_alpha) < float(int_upper.front_wall_alpha), "local front-wall occlusion still applies when global floor 1 is selected")

	var unrelated := cutaway.evaluate_state("region.river", Vector2(220, 180), 0)
	t.check(not unrelated.active and unrelated.mode == "inactive" and is_equal_approx(float(unrelated.shell_alpha), 0.0), "unrelated regions keep cutaway layers inactive")

	# 4. Presentation changes never mutate authoritative world state, permissions, or container contents.
	var snap_before := m.session.snapshot()
	var view := WorldView.new()
	view.size = Vector2(760, 420)
	view.configure(m, "a:player", {}, 210.0)
	view.set_building_cutaway(cutaway)
	view.set_visible_floor(1)
	t.check(view.visible_floor() == 1 and view.cutaway_state().visible_floor == 1, "WorldView stores global visible floor selection")
	view.set_visible_floor(99)
	t.check(view.visible_floor() == 1, "WorldView clamps visible floor to authored building maximum")
	view.set_visible_floor(0)
	t.check(m.session.snapshot() == snap_before, "toggling cutaway and visible floor never mutates GameSession state")
	view.free()
	m.session.close()

	# 5. Negative validation tests for malformed cutaway configs.
	var bad_iso := manifest.duplicate(true)
	bad_iso.projection.true_isometric = true
	t.check(BuildingCutaway.create(bad_iso) == null, "true-isometric projection rejected by BuildingCutaway contract")

	var bad_missing_layer := manifest.duplicate(true)
	bad_missing_layer.layers.roof = "res://dev/art/cutaway_fixture/nonexistent_roof.png"
	t.check(BuildingCutaway.create(bad_missing_layer) == null, "missing layer texture rejected")
