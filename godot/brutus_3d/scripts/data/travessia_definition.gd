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


static func match_rules() -> Dictionary:
	return {
		# Canonical Alpha pace: every time-based system runs at half speed.
		"game_speed": 0.50,
		"wave_interval": 8.0,
		"max_actors": 42,
		"respawn_time": 3.0,
	}


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
			# "base" remains the internal gameplay identifier. In the game and
			# documentation this objective is called the main tower/core.
			"kind": &"base",
			"team": marker.team,
			"position": marker.position,
			"health": 3200.0,
			"color": Color("2aa8d8") if marker.team == 0 else Color("d8455d"),
		})
	for marker in tower_markers():
		result.append({
			"kind": &"tower",
			"team": marker.team,
			"position": marker.position,
			"health": 1250.0,
			"color": Color("37bfe8") if marker.team == 0 else Color("ef5268"),
		})
	return result


static func main_tower_markers() -> Array[Dictionary]:
	# Centers of the two large circular platforms. They are measured separately
	# because the approved painted map is intentionally not perfectly symmetric.
	return [
		{"team": 1, "map_pixel": Vector2(455, 171),
			"position": Vector3(-0.0296, 0, -13.6257)},
		{"team": 0, "map_pixel": Vector2(455, 1502),
			"position": Vector3(-0.0296, 0, 12.6390)},
	]


static func tower_markers() -> Array[Dictionary]:
	# Exact pixel centers measured on the 913x1723 approved map texture and
	# converted to the 18.02x34 Godot plane. The generated art is intentionally
	# not forced into mathematical symmetry.
	return [
		{"team": 1, "map_pixel": Vector2(200, 238),
			"position": Vector3(-5.0626, 0, -12.3035)},
		{"team": 1, "map_pixel": Vector2(705, 238),
			"position": Vector3(4.9047, 0, -12.3035)},
		{"team": 0, "map_pixel": Vector2(200, 1463),
			"position": Vector3(-5.0626, 0, 11.8694)},
		{"team": 0, "map_pixel": Vector2(705, 1463),
			"position": Vector3(4.9047, 0, 11.8694)},
	]


static func neutral_objectives() -> Array[Dictionary]:
	return [{
		"kind": &"dragon",
		"team": 2,
		"position": Vector3.ZERO,
		"health": 2200.0,
		"attack_damage": 85.0,
		"attack_range": 3.4,
		"attack_interval": 1.15,
		"color": Color("9c55cc"),
	}]


static func hero_bots() -> Array[Dictionary]:
	return [
		{
			"hero": &"sol", "name": "Sol", "team": 0, "lane_x": LANE_X[1],
			"position": Vector3(1.5, 0, 12.2), "health": 700.0,
			"move_speed": 2.35, "attack_damage": 62.0, "attack_range": 3.0,
			"attack_interval": 0.8, "texture": "res://assets/heroes/sol.png",
		},
		{
			"hero": &"lyra", "name": "Lyra", "team": 1, "lane_x": LANE_X[0],
			"position": Vector3(-1.5, 0, -12.2), "health": 750.0,
			"move_speed": 2.45, "attack_damage": 72.0, "attack_range": 3.05,
			"attack_interval": 0.75, "texture": "res://assets/heroes/lyra.png",
		},
		{
			"hero": &"nix", "name": "Nix", "team": 1, "lane_x": LANE_X[1],
			"position": Vector3(1.5, 0, -12.2), "health": 800.0,
			"move_speed": 2.6, "attack_damage": 90.0, "attack_range": 1.2,
			"attack_interval": 0.62, "texture": "res://assets/heroes/nix.png",
		},
	]


static func minion(team: int, lane_x: float) -> Dictionary:
	return {
		"kind": &"minion",
		"team": team,
		"position": Vector3(lane_x, 0, 12.8 if team == 0 else -12.8),
		"health": 280.0,
		"move_speed": 1.15,
		"attack_damage": 38.0,
		"attack_range": 1.25,
		"attack_interval": 1.0,
		"lane_x": lane_x,
		"color": Color("58c9ef") if team == 0 else Color("ef6073"),
	}
