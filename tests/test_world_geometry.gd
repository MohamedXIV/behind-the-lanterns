extends RefCounted

func run(t) -> void:
	var geometry := WorldGeometry.create({"radius": 10, "obstacles": [{"x": 90, "y": 40, "width": 30, "height": 100}]}, Vector2(240, 180))
	t.check(geometry != null, "authored geometry loads")
	t.check(not geometry.walkable(Vector2(85, 80)), "actor clearance blocks overlap")
	t.check(not geometry.clear_segment(Vector2(30, 80), Vector2(180, 80)), "wall blocks interaction line")
	var route := geometry.route(Vector2(30, 80), Vector2(180, 80))
	t.check(route.size() > 1, "tap route goes around obstacle")
	var previous := Vector2(30, 80)
	for point in route:
		t.check(geometry.walkable(point) and geometry.clear_segment(previous, point, 10), "every route segment clears actor radius")
		previous = point
	t.check(route == geometry.route(Vector2(30, 80), Vector2(180, 80)), "routing deterministic")
	t.check(geometry.route(Vector2(30, 80), Vector2(100, 80)).is_empty(), "blocked destinations rejected")
	t.check(WorldGeometry.create({"radius": -1, "obstacles": []}, Vector2(240, 180)) == null, "invalid clearance rejected")
	var divided := WorldGeometry.create({"radius": 10, "obstacles": [{"x": 90, "y": 0, "width": 30, "height": 180}]}, Vector2(240, 180))
	t.check(divided.route(Vector2(30, 80), Vector2(180, 80)).is_empty(), "unreachable destination rejected")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/connected_gameplay.json"))
	var m := GameplayModel.create(data, "world.spatial")
	var before := m.session.snapshot()
	t.check(not m.move_actor("blocked", "a:player", 350, 220).ok and m.session.snapshot() == before, "blocked movement preserves transaction state")
	t.check(m.move_actor("left", "a:player", 319, 230).ok, "valid position beside wall")
	var denied := m.session.transact("through-wall", func(tx: WorldTransaction) -> String: return m.interactions.reach_error(tx, "a:player", "a:chest"))
	t.check(denied.code == "interaction_obstructed", "distance alone cannot authorize through-wall use")
	data.npcs["a:courier"].slots[0].x = 350
	data.npcs["a:courier"].slots[0].y = 220
	t.check(GameplayModel.create(data, "world.invalid-npc") == null, "NPC routine cannot place person in wall")
	m.session.close()
