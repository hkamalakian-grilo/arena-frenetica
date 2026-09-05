class_name TravessiaDefinition
extends RefCounted

## Canonical gameplay data for the first production map.
##
## Keeping coordinates and rules here lets the map art change without silently
## changing combat. This is the Godot source of truth; the HTML build is only a
## reference for comparing the original prototype.

const PLAYER_SPAWN := Vector3(-1.5, 0.0, 12.2)
const MAP_SIZE := Vector2(18.02, 34.0)
const PLAYABLE_HALF_EXTENTS := Vector2(8.30, 16.25)
const LANE_X := [-5.35, 5.35]

## Physical movement mask. Rectangles deliberately overlap at junctions so a
## capsule can slide naturally from a base into a lane or central approach.
## Decorative grass, jungle, river and the exterior are not walkable.
const WALKABLE_RECTS := [
	{"name": &"left_north_road", "center": Vector2(-5.35, -7.85),
		"half_extents": Vector2(1.35, 6.85)},
	{"name": &"left_bridge", "center": Vector2(-5.35, 0.0),
		"half_extents": Vector2(1.15, 1.85)},
	{"name": &"left_south_road", "center": Vector2(-5.35, 7.85),
		"half_extents": Vector2(1.35, 6.85)},
	{"name": &"left_north_jungle_side", "center": Vector2(-3.90, -7.50),
		"half_extents": Vector2(0.93, 2.75)},
	{"name": &"right_north_road", "center": Vector2(5.35, -7.85),
		"half_extents": Vector2(1.35, 6.85)},
	{"name": &"right_bridge", "center": Vector2(5.35, 0.0),
		"half_extents": Vector2(1.15, 1.85)},
	{"name": &"right_south_road", "center": Vector2(5.35, 7.85),
		"half_extents": Vector2(1.35, 6.85)},
	{"name": &"north_center_path", "center": Vector2(0.0, -7.10),
		"half_extents": Vector2(1.55, 3.80)},
	{"name": &"south_center_path", "center": Vector2(0.0, 7.10),
		"half_extents": Vector2(1.55, 3.80)},
	# Broad junctions follow the painted stone openings between each base and
	# its three roads. They prevent an apparently open diagonal from behaving
	# like an invisible wall while keeping the jungle interiors blocked.
	{"name": &"north_left_junction", "center": Vector2(-3.30, -10.95),
		"half_extents": Vector2(2.15, 2.0)},
	{"name": &"north_right_junction", "center": Vector2(3.30, -10.95),
		"half_extents": Vector2(2.15, 2.0)},
	{"name": &"south_left_junction", "center": Vector2(-3.30, 10.95),
		"half_extents": Vector2(2.15, 2.0)},
	{"name": &"south_right_junction", "center": Vector2(3.30, 10.95),
		"half_extents": Vector2(2.15, 2.0)},
]

## The painted base walls are curved. Ellipses prevent the rectangular corner
## leaks that allowed actors to stand behind the north/south perimeter walls.
const WALKABLE_ELLIPSES := [
	{"name": &"red_base", "center": Vector2(0.0, -12.70),
		"radii": Vector2(7.65, 2.70)},
	{"name": &"blue_base", "center": Vector2(0.0, 12.70),
		"radii": Vector2(7.65, 2.70)},
]

const DRAGON_ACCESS_RECTS := [
	{"name": &"north_dragon_bridge", "center": Vector2(0.0, -2.80),
		"half_extents": Vector2(0.88, 1.80)},
	{"name": &"south_dragon_bridge", "center": Vector2(0.0, 2.80),
		"half_extents": Vector2(0.88, 1.80)},
]
const DRAGON_ISLAND_RADIUS := 1.85


static func is_walkable(point: Vector2, dragon_access_open := false,
		body_radius := 0.42) -> bool:
	for zone in WALKABLE_RECTS:
		if _point_in_walkable_rect(point, zone, body_radius):
			return true
	for zone in WALKABLE_ELLIPSES:
		if _point_in_walkable_ellipse(point, zone, body_radius):
			return true
	if not dragon_access_open:
		return false
	for zone in DRAGON_ACCESS_RECTS:
		if _point_in_walkable_rect(point, zone, body_radius):
			return true
	return point.length() <= maxf(0.0, DRAGON_ISLAND_RADIUS - body_radius)


static func constrain_walkable_motion(previous: Vector3, desired: Vector3,
		dragon_access_open := false, body_radius := 0.42) -> Vector3:
	var previous_point := Vector2(previous.x, previous.z)
	var desired_point := Vector2(desired.x, desired.z)
	if is_walkable(desired_point, dragon_access_open, body_radius):
		return Vector3(desired_point.x, desired.y, desired_point.y)
	if not is_walkable(previous_point, dragon_access_open, body_radius):
		var recovered := nearest_walkable_point(desired_point,
			dragon_access_open, body_radius)
		return Vector3(recovered.x, desired.y, recovered.y)

	# Resolve each axis independently first. This produces the familiar MOBA
	# slide along river banks, jungle edges and arena walls.
	var slide_candidates: Array[Vector2] = []
	var x_motion := Vector2(desired_point.x, previous_point.y)
	if is_walkable(x_motion, dragon_access_open, body_radius):
		slide_candidates.append(x_motion)
	var z_motion := Vector2(previous_point.x, desired_point.y)
	if is_walkable(z_motion, dragon_access_open, body_radius):
		slide_candidates.append(z_motion)
	if not slide_candidates.is_empty():
		var best_slide := slide_candidates[0]
		for candidate in slide_candidates:
			if candidate.distance_squared_to(desired_point) \
					< best_slide.distance_squared_to(desired_point):
				best_slide = candidate
		return Vector3(best_slide.x, desired.y, best_slide.y)

	# Dashes can cross a boundary within one physics tick. Binary search retains
	# the last valid point instead of snapping all the way back to the start.
	var valid_ratio := 0.0
	var blocked_ratio := 1.0
	for _iteration in range(12):
		var middle := (valid_ratio + blocked_ratio) * 0.5
		var candidate := previous_point.lerp(desired_point, middle)
		if is_walkable(candidate, dragon_access_open, body_radius):
			valid_ratio = middle
		else:
			blocked_ratio = middle
	var boundary_point := previous_point.lerp(desired_point, valid_ratio)
	return Vector3(boundary_point.x, desired.y, boundary_point.y)


static func nearest_walkable_point(point: Vector2,
		dragon_access_open := false, body_radius := 0.42) -> Vector2:
	var best_point := Vector2.ZERO
	var best_distance := INF
	var zones: Array = WALKABLE_RECTS.duplicate()
	if dragon_access_open:
		zones.append_array(DRAGON_ACCESS_RECTS)
	for zone in zones:
		var center: Vector2 = zone.center
		var half_extents: Vector2 = zone.half_extents \
			- Vector2.ONE * body_radius
		half_extents.x = maxf(0.0, half_extents.x)
		half_extents.y = maxf(0.0, half_extents.y)
		var candidate := Vector2(
			clampf(point.x, center.x - half_extents.x,
				center.x + half_extents.x),
			clampf(point.y, center.y - half_extents.y,
				center.y + half_extents.y))
		var distance := candidate.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best_point = candidate
	for zone in WALKABLE_ELLIPSES:
		var center: Vector2 = zone.center
		var radii: Vector2 = zone.radii - Vector2.ONE * body_radius
		radii.x = maxf(0.001, radii.x)
		radii.y = maxf(0.001, radii.y)
		var local_point := point - center
		var normalized_point := Vector2(local_point.x / radii.x,
			local_point.y / radii.y)
		var candidate := point
		if normalized_point.length_squared() > 1.0:
			var edge_direction := normalized_point.normalized()
			candidate = center + Vector2(edge_direction.x * radii.x,
				edge_direction.y * radii.y)
		var distance := candidate.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best_point = candidate
	if dragon_access_open:
		var island_radius := maxf(0.0, DRAGON_ISLAND_RADIUS - body_radius)
		var island_point := point
		if point.length() > island_radius:
			island_point = point.normalized() * island_radius
		var island_distance := island_point.distance_squared_to(point)
		if island_distance < best_distance:
			best_point = island_point
	return best_point


static func _point_in_walkable_rect(point: Vector2, zone: Dictionary,
		body_radius: float) -> bool:
	var center: Vector2 = zone.center
	var half_extents: Vector2 = zone.half_extents - Vector2.ONE * body_radius
	if half_extents.x < 0.0 or half_extents.y < 0.0:
		return false
	return absf(point.x - center.x) <= half_extents.x \
		and absf(point.y - center.y) <= half_extents.y


static func _point_in_walkable_ellipse(point: Vector2, zone: Dictionary,
		body_radius: float) -> bool:
	var center: Vector2 = zone.center
	var radii: Vector2 = zone.radii - Vector2.ONE * body_radius
	if radii.x <= 0.0 or radii.y <= 0.0:
		return false
	var local_point := point - center
	var normalized_point := Vector2(local_point.x / radii.x,
		local_point.y / radii.y)
	return normalized_point.length_squared() <= 1.0


static func match_rules() -> Dictionary:
	return {
		# Moment-to-moment presentation remains deliberately cadenced. Match
		# clock, waves, cooldowns and respawns explicitly use real time.
		"game_speed": 0.50,
		"match_duration": 180.0,
		"dragon_hatch_remaining": 60.0,
		"wave_interval": 10.0,
		"max_actors": 38,
		"max_minions_per_lane": 4,
		"respawn_time": 3.0,
		# Dragon reward (GAME_DESIGN / README): +30% damage for 45 s and the
		# next two waves of that team spawn reinforced.
		"dragon_team_damage_bonus": 1.30,
		"dragon_buff_duration": 45.0,
		"dragon_reinforced_waves": 2,
		"reinforced_wave_multiplier": 1.5,
		# Fountain: fast regeneration next to the own main tower.
		"fountain_radius": 3.2,
		"fountain_heal_pct_per_second": 0.08,
		# Bot decision thresholds (mirrors src/config/balance.js `bots`).
		"bot_retreat_hp_pct": 0.30,
		"bot_retreat_exit_hp_pct": 0.55,
		"bot_dragon_min_hp_pct": 0.50,
		"bot_rotate_empty_lane_seconds": 4.0,
		"bot_dive_min_hp_pct": 0.60,
		"tower_attack_range": 4.5,
	}


## Waypoint graph used by hero bots to travel between lanes, bases and the
## dragon island without pushing against jungle or water. Positions sit inside
## WALKABLE_RECTS / ELLIPSES; edges follow the painted stone openings.
static func nav_waypoints() -> Dictionary:
	return {
		&"blue_core": Vector2(0.0, 11.4),
		&"red_core": Vector2(0.0, -11.4),
		&"south_left_junction": Vector2(-3.30, 10.95),
		&"south_right_junction": Vector2(3.30, 10.95),
		&"north_left_junction": Vector2(-3.30, -10.95),
		&"north_right_junction": Vector2(3.30, -10.95),
		# Lane ends sit inside the overlap of the road and the base junction so
		# every edge stays walkable for a 0.42 body radius.
		&"left_south_lane": Vector2(-5.0, 9.6),
		&"left_bridge": Vector2(-5.35, 0.0),
		&"left_north_lane": Vector2(-5.0, -9.6),
		&"right_south_lane": Vector2(5.0, 9.6),
		&"right_bridge": Vector2(5.35, 0.0),
		&"right_north_lane": Vector2(5.0, -9.6),
		&"south_center": Vector2(0.0, 7.1),
		&"north_center": Vector2(0.0, -7.1),
		&"south_center_gate": Vector2(0.0, 4.2),
		&"north_center_gate": Vector2(0.0, -4.2),
		&"south_dragon_bridge": Vector2(0.0, 2.6),
		&"north_dragon_bridge": Vector2(0.0, -2.6),
		&"dragon_island": Vector2(0.0, 0.0),
	}


static func nav_edges() -> Array:
	return [
		[&"blue_core", &"south_left_junction"], [&"blue_core", &"south_right_junction"],
		[&"blue_core", &"south_center"],
		[&"south_left_junction", &"left_south_lane"], [&"south_right_junction", &"right_south_lane"],
		[&"left_south_lane", &"left_bridge"], [&"left_bridge", &"left_north_lane"],
		[&"right_south_lane", &"right_bridge"], [&"right_bridge", &"right_north_lane"],
		[&"red_core", &"north_left_junction"], [&"red_core", &"north_right_junction"],
		[&"red_core", &"north_center"],
		[&"north_left_junction", &"left_north_lane"], [&"north_right_junction", &"right_north_lane"],
		[&"south_center", &"south_center_gate"], [&"north_center", &"north_center_gate"],
	]


## Edges that only exist once the dragon bridges have finished assembling.
static func nav_dragon_edges() -> Array:
	return [
		[&"south_center_gate", &"south_dragon_bridge"], [&"south_dragon_bridge", &"dragon_island"],
		[&"north_center_gate", &"north_dragon_bridge"], [&"north_dragon_bridge", &"dragon_island"],
	]


static func palette() -> Dictionary:
	return {
		"grass": Color("4d9b45"),
		"grass_dark": Color("357a38"),
		"lane": Color("c99a56"),
		"water": Color("3184b5"),
		"stone": Color("70777d"),
	}


static func surfaces() -> Array[Dictionary]:
	var colors := palette()
	return [
		{"name": "Grass", "size": MAP_SIZE, "color": colors.grass, "position": Vector3.ZERO},
		{"name": "GrassInset", "size": Vector2(21.5, 31.5), "color": colors.grass_dark,
			"position": Vector3(0.0, 0.008, 0.0)},
		{"name": "LeftLane", "size": Vector2(4.1, 30.0), "color": colors.lane,
			"position": Vector3(LANE_X[0], 0.016, 0.0)},
		{"name": "RightLane", "size": Vector2(4.1, 30.0), "color": colors.lane,
			"position": Vector3(LANE_X[1], 0.016, 0.0)},
		{"name": "River", "size": Vector2(21.5, 3.1), "color": colors.water,
			"position": Vector3(0.0, 0.025, 0.0)},
		{"name": "LeftBridge", "size": Vector2(4.5, 3.7), "color": colors.lane.lightened(0.08),
			"position": Vector3(LANE_X[0], 0.035, 0.0)},
		{"name": "RightBridge", "size": Vector2(4.5, 3.7), "color": colors.lane.lightened(0.08),
			"position": Vector3(LANE_X[1], 0.035, 0.0)},
	]


static func greybox_props() -> Array[Dictionary]:
	var stone: Color = palette().stone
	return [
		{"name": "RockA", "size": Vector3(2.2, 0.8, 1.3), "color": stone,
			"position": Vector3(-1.8, 0.4, -4.0)},
		{"name": "RockB", "size": Vector3(1.5, 1.0, 2.0), "color": stone,
			"position": Vector3(2.1, 0.5, 4.2)},
		{"name": "RockC", "size": Vector3(1.4, 0.7, 1.3), "color": stone,
			"position": Vector3(-1.1, 0.35, 6.3)},
	]


static func structures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for marker in main_tower_markers():
		result.append({
			"id": marker.id,
			# "base" remains the internal gameplay identifier. In the game and
			# documentation this objective is called the main tower/core.
			"kind": &"base",
			"team": marker.team,
			"position": marker.position,
			"health": 4200.0,
			"color": Color("2aa8d8") if marker.team == 0 else Color("d8455d"),
		})
	for marker in tower_markers():
		result.append({
			"id": marker.id,
			"kind": &"tower",
			"team": marker.team,
			"position": marker.position,
			# HTML lane tower on map C is 1150. One wave plus one hero must be
			# able to finish a tower; towers shoot minions before heroes.
			"health": 1100.0,
			"color": Color("37bfe8") if marker.team == 0 else Color("ef5268"),
		})
	return result


static func main_tower_markers() -> Array[Dictionary]:
	# Centers of the two large circular platforms. They are measured separately
	# because the approved painted map is intentionally not perfectly symmetric.
	return [
		{"id": &"red_core", "team": 1, "map_pixel": Vector2(455, 171),
			"position": Vector3(-0.0296, 0, -13.6257)},
		{"id": &"blue_core", "team": 0, "map_pixel": Vector2(455, 1502),
			"position": Vector3(-0.0296, 0, 12.6390)},
	]


static func tower_markers() -> Array[Dictionary]:
	# Exact pixel centers measured on the 913x1723 approved map texture and
	# converted to the 18.02x34 Godot plane. The generated art is intentionally
	# not forced into mathematical symmetry.
	return [
		{"id": &"red_left_tower", "team": 1, "map_pixel": Vector2(200, 238),
			"position": Vector3(-5.0626, 0, -12.3035)},
		{"id": &"red_right_tower", "team": 1, "map_pixel": Vector2(705, 238),
			"position": Vector3(4.9047, 0, -12.3035)},
		{"id": &"blue_left_tower", "team": 0, "map_pixel": Vector2(200, 1463),
			"position": Vector3(-5.0626, 0, 11.8694)},
		{"id": &"blue_right_tower", "team": 0, "map_pixel": Vector2(705, 1463),
			"position": Vector3(4.9047, 0, 11.8694)},
	]


static func neutral_objectives() -> Array[Dictionary]:
	return [{
		"kind": &"dragon_egg",
		"team": 2,
		"position": Vector3.ZERO,
		"health": 1.0,
		"color": Color("8e63bb"),
	}]


static func dragon_definition() -> Dictionary:
	return {
		"kind": &"dragon",
		"team": 2,
		"position": Vector3.ZERO,
		# HTML values: a 2v2 fight must be able to finish the dragon in the
		# last minute instead of trading retreats until the clock ends.
		"health": 1400.0,
		"attack_damage": 70.0,
		"attack_range": 3.4,
		"attack_interval": 1.15,
		"color": Color("9c55cc"),
	}


static func hero_bots() -> Array[Dictionary]:
	return [
		{
			"hero": &"sol", "name": "Sol", "team": 0, "lane_x": LANE_X[1],
			"position": Vector3(1.5, 0, 12.2), "health": 700.0,
			"move_speed": 2.35, "attack_damage": 62.0, "attack_range": 3.0,
			"attack_interval": 0.8, "texture": "res://assets/heroes/sol.png",
			"ranged": true, "projectile_speed": 8.8,
		},
		{
			"hero": &"lyra", "name": "Lyra", "team": 1, "lane_x": LANE_X[0],
			"position": Vector3(-1.5, 0, -12.2), "health": 750.0,
			"move_speed": 2.45, "attack_damage": 72.0, "attack_range": 3.05,
			"attack_interval": 0.75, "texture": "res://assets/heroes/lyra.png",
			"ranged": true, "projectile_speed": 9.5,
		},
		{
			"hero": &"nix", "name": "Nix", "team": 1, "lane_x": LANE_X[1],
			"position": Vector3(1.5, 0, -12.2), "health": 800.0,
			"move_speed": 2.6, "attack_damage": 90.0, "attack_range": 1.2,
			"attack_interval": 0.62, "texture": "res://assets/heroes/nix.png",
			"ranged": false,
		},
	]


## Q / R kits for the roster bots. Values follow src/config/balance.js with
## 100 prototype units = 1 Godot unit; times in seconds of simulation.
static func hero_kits() -> Dictionary:
	return {
		&"lyra": {
			"q": {"name": "Flecha Perfurante", "cooldown": 6.0, "damage": 120.0,
				"range": 6.0, "width": 0.32, "speed": 9.8, "pierce": true},
			"r": {"name": "Chuva de Flechas", "cooldown": 40.0, "damage_per_second": 60.0,
				"duration": 3.0, "radius": 2.0, "cast_range": 5.0, "slow": 0.75,
				"tick": 0.5, "delay": 0.55},
		},
		&"nix": {
			"q": {"name": "Passo Sombrio", "cooldown": 8.0, "blink": 3.0,
				"bonus_damage": 100.0, "bonus_window": 3.0},
			"r": {"name": "Execução", "cooldown": 50.0, "damage": 280.0,
				"execute_hp_pct": 0.35, "range": 4.5, "dash_speed": 5.5},
		},
		&"sol": {
			"q": {"name": "Orbe Solar", "cooldown": 7.0, "damage": 100.0, "heal": 140.0,
				"range": 5.6, "width": 0.34, "speed": 8.4, "pierce": false},
			"r": {"name": "Zona Radiante", "cooldown": 45.0, "radius": 2.2, "duration": 4.0,
				"cast_range": 4.5, "heal_per_second": 40.0, "haste": 0.2, "tick": 0.5,
				"delay": 0.4},
		},
	}


static func minion(team: int, lane_x: float) -> Dictionary:
	return {
		"kind": &"minion",
		"team": team,
		"position": Vector3(lane_x, 0, 12.8 if team == 0 else -12.8),
		"health": 240.0,
		"move_speed": 1.15,
		"attack_damage": 26.0,
		"attack_range": 1.25,
		"attack_interval": 1.10,
		"lane_x": lane_x,
		"color": Color("58c9ef") if team == 0 else Color("ef6073"),
	}
