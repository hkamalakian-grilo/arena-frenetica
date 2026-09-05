class_name TravessiaNav
extends RefCounted

## Tiny waypoint navigation over TravessiaDefinition.nav_waypoints(). Bots go
## straight when the line is walkable; otherwise they follow the shortest
## waypoint path. Pure static functions so tests can call them directly.

const SAMPLE_STEP := 0.35


static func line_is_walkable(from: Vector2, to: Vector2, dragon_open: bool,
		body_radius := 0.42) -> bool:
	var distance := from.distance_to(to)
	var samples := maxi(1, int(ceil(distance / SAMPLE_STEP)))
	for index in range(samples + 1):
		var point := from.lerp(to, float(index) / samples)
		if not TravessiaDefinition.is_walkable(point, dragon_open, body_radius):
			return false
	return true


static func nearest_waypoint(point: Vector2, dragon_open: bool) -> StringName:
	var waypoints := TravessiaDefinition.nav_waypoints()
	var best: StringName = &""
	var best_distance := INF
	var best_visible: StringName = &""
	var best_visible_distance := INF
	for key in waypoints:
		var position: Vector2 = waypoints[key]
		if not dragon_open and _is_dragon_node(key):
			continue
		var distance := position.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best = key
		if distance < best_visible_distance and line_is_walkable(point, position, dragon_open):
			best_visible_distance = distance
			best_visible = key
	return best_visible if best_visible != &"" else best


static func _is_dragon_node(key: StringName) -> bool:
	return key == &"south_dragon_bridge" or key == &"north_dragon_bridge" \
		or key == &"dragon_island"


static func _neighbours(dragon_open: bool) -> Dictionary:
	var result := {}
	var edges: Array = TravessiaDefinition.nav_edges().duplicate()
	if dragon_open:
		edges.append_array(TravessiaDefinition.nav_dragon_edges())
	for edge in edges:
		var a: StringName = edge[0]
		var b: StringName = edge[1]
		if not result.has(a):
			result[a] = []
		if not result.has(b):
			result[b] = []
		result[a].append(b)
		result[b].append(a)
	return result


## Dijkstra over the waypoint graph. Returns the list of waypoint names from
## `start` to `goal` inclusive, or an empty array when unreachable.
static func waypoint_path(start: StringName, goal: StringName, dragon_open: bool) -> Array:
	if start == goal:
		return [start]
	var waypoints := TravessiaDefinition.nav_waypoints()
	var neighbours := _neighbours(dragon_open)
	var distances := {start: 0.0}
	var previous := {}
	var open: Array = [start]
	while not open.is_empty():
		var best_index := 0
		for index in range(1, open.size()):
			if distances[open[index]] < distances[open[best_index]]:
				best_index = index
		var current: StringName = open[best_index]
		open.remove_at(best_index)
		if current == goal:
			break
		for next in neighbours.get(current, []):
			var candidate: float = distances[current] \
				+ waypoints[current].distance_to(waypoints[next])
			if candidate < distances.get(next, INF):
				distances[next] = candidate
				previous[next] = current
				if not open.has(next):
					open.append(next)
	if not distances.has(goal):
		return []
	var path: Array = [goal]
	var cursor: StringName = goal
	while previous.has(cursor):
		cursor = previous[cursor]
		path.push_front(cursor)
	return path


## World-space route from `from` to `to`: a list of Vector2 points to visit in
## order (the final entry is always `to`).
static func route(from: Vector2, to: Vector2, dragon_open: bool, body_radius := 0.42) -> Array:
	if line_is_walkable(from, to, dragon_open, body_radius):
		return [to]
	var waypoints := TravessiaDefinition.nav_waypoints()
	var start := nearest_waypoint(from, dragon_open)
	var goal := nearest_waypoint(to, dragon_open)
	var names := waypoint_path(start, goal, dragon_open)
	var points: Array = []
	for name in names:
		points.append(waypoints[name])
	# Skip leading waypoints that are behind us when a later one is visible.
	while points.size() >= 2 and line_is_walkable(from, points[1], dragon_open, body_radius):
		points.remove_at(0)
	points.append(to)
	return points
