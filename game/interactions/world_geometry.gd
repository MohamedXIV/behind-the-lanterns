class_name WorldGeometry
extends RefCounted
## Shared authored collision geometry. Routes use a small visibility graph.
var extent: Vector2
var radius: float
var blocks: Array[Rect2] = []

static func create(config: Dictionary, bounds: Vector2) -> WorldGeometry:
	if not WorldData.keys(config, ["radius", "obstacles"]): return null
	if not InteractionRules._number(config.radius) or config.radius < 0 or not config.obstacles is Array: return null
	var geometry := WorldGeometry.new()
	geometry.extent = bounds
	geometry.radius = config.radius
	for row in config.obstacles:
		if not WorldData.keys(row, ["x", "y", "width", "height"]): return null
		for value in row.values():
			if not InteractionRules._number(value): return null
		if row.width <= 0 or row.height <= 0 or row.x < 0 or row.y < 0 or row.x + row.width > bounds.x or row.y + row.height > bounds.y: return null
		geometry.blocks.append(Rect2(row.x, row.y, row.width, row.height))
	return geometry

func walkable(point: Vector2) -> bool:
	if not point.is_finite() or not Rect2(Vector2.ZERO, extent).has_point(point): return false
	for block in blocks:
		if block.grow(radius).has_point(point): return false
	return true

func clear_segment(start: Vector2, finish: Vector2, clearance: float = 0.0) -> bool:
	for block in blocks:
		var rect := block.grow(clearance)
		if rect.has_point(start) or rect.has_point(finish): return false
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for index in 4:
			if Geometry2D.segment_intersects_segment(start, finish, corners[index], corners[(index + 1) % 4]) != null: return false
	return true

func route(start: Vector2, finish: Vector2) -> PackedVector2Array:
	if not walkable(start) or not walkable(finish): return []
	var points: Array[Vector2] = [start, finish]
	for block in blocks:
		var rect := block.grow(radius + 1.0)
		for point in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			if walkable(point): points.append(point)
	var distances: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for point in points:
		distances.append(INF)
		previous.append(-1)
		visited.append(false)
	distances[0] = 0
	for iteration in points.size():
		var current := -1
		for index in points.size():
			if not visited[index] and (current == -1 or distances[index] < distances[current]): current = index
		if current == -1 or is_inf(distances[current]): break
		if current == 1: break
		visited[current] = true
		for index in points.size():
			if visited[index] or not clear_segment(points[current], points[index], radius): continue
			var distance := distances[current] + points[current].distance_to(points[index])
			if distance < distances[index]:
				distances[index] = distance
				previous[index] = current
	if is_inf(distances[1]): return []
	var result := PackedVector2Array()
	var cursor := 1
	while cursor != 0:
		result.insert(0, points[cursor])
		cursor = previous[cursor]
	return result
