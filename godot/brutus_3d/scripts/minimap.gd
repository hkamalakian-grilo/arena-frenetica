class_name Minimap
extends Control

## Schematic overview drawn every frame: lanes, river, island, structures,
## units, the player and the rectangle the close camera currently shows.

signal tapped

const PANEL_SIZE := Vector2(92.0, 174.0)
const MAP_HALF := Vector2(9.01, 17.0)

var game: Node
var camera: Camera3D
var camera_rig: Node3D
var full_view := false


func setup(match_root: Node) -> void:
	game = match_root
	camera = match_root.get_node("CameraRig/Camera3D") as Camera3D
	camera_rig = match_root.get_node("CameraRig") as Node3D
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = PANEL_SIZE


## Tapping the minimap toggles the whole-map camera.
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		tapped.emit()
		accept_event()


func _to_panel(world_x: float, world_z: float) -> Vector2:
	return Vector2(
		(world_x + MAP_HALF.x) / (MAP_HALF.x * 2.0) * size.x,
		(world_z + MAP_HALF.y) / (MAP_HALF.y * 2.0) * size.y)


func _rect(center: Vector2, half: Vector2) -> Rect2:
	var top_left := _to_panel(center.x - half.x, center.y - half.y)
	var bottom_right := _to_panel(center.x + half.x, center.y + half.y)
	return Rect2(top_left, bottom_right - top_left)


func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(panel.position + Vector2(0, 3), panel.size).grow(3.0), Color(0, 0, 0, 0.35))
	draw_rect(panel, Color(0.05, 0.10, 0.06, 0.82))
	draw_rect(panel, Color(1.0, 0.85, 0.45, 1.0) if full_view else Color(0.86, 0.68, 0.28, 0.85),
		false, 3.0 if full_view else 2.0)
	# Terrain: grass, river band, lanes and bridges, island.
	draw_rect(panel.grow(-2.0), Color(0.24, 0.45, 0.22, 0.9))
	draw_rect(_rect(Vector2(0.0, 0.0), Vector2(MAP_HALF.x, 1.55)), Color(0.19, 0.48, 0.70, 0.95))
	for lane_x in TravessiaDefinition.LANE_X:
		draw_rect(_rect(Vector2(lane_x, 0.0), Vector2(1.2, 15.0)), Color(0.78, 0.62, 0.36, 0.95))
	draw_rect(_rect(Vector2(0.0, -7.1), Vector2(1.3, 3.8)), Color(0.78, 0.62, 0.36, 0.9))
	draw_rect(_rect(Vector2(0.0, 7.1), Vector2(1.3, 3.8)), Color(0.78, 0.62, 0.36, 0.9))
	draw_rect(_rect(Vector2(0.0, -12.7), Vector2(7.2, 2.4)), Color(0.72, 0.56, 0.34, 0.9))
	draw_rect(_rect(Vector2(0.0, 12.7), Vector2(7.2, 2.4)), Color(0.72, 0.56, 0.34, 0.9))
	for bush in TravessiaDefinition.CAMP_BUSHES:
		var camp_center: Vector2 = bush.center
		var camp := _to_panel(camp_center.x, camp_center.y)
		var camp_radius := float(bush.radius) / (MAP_HALF.x * 2.0) * size.x
		draw_circle(camp, camp_radius, Color(0.30, 0.62, 0.28, 0.95))
	var island := _to_panel(0.0, 0.0)
	var island_radius := TravessiaDefinition.DRAGON_ISLAND_RADIUS / (MAP_HALF.x * 2.0) * size.x
	draw_circle(island, island_radius, Color(0.58, 0.40, 0.72, 0.95))
	if game == null:
		return
	# Actors.
	for node in game.get_tree().get_nodes_in_group("arena_actors"):
		if not is_instance_valid(node):
			continue
		var actor := node as ArenaActor
		if actor != null:
			if actor.is_defeated:
				continue
			var point := _to_panel(actor.global_position.x, actor.global_position.z)
			var color := CombatWorld.team_color(actor.team)
			match actor.actor_kind:
				&"tower":
					draw_rect(Rect2(point - Vector2(3.5, 3.5), Vector2(7, 7)), color)
				&"base":
					draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), color)
					draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), Color.WHITE, false, 1.0)
				&"minion":
					draw_circle(point, 1.6, color)
				&"dragon":
					draw_circle(point, 4.0, Color(0.85, 0.55, 1.0))
				&"dragon_egg":
					draw_circle(point, 3.0, Color(0.7, 0.5, 0.9))
			continue
		var hero := node as HeroBot
		if hero != null and not hero.is_defeated:
			var point := _to_panel(hero.global_position.x, hero.global_position.z)
			draw_circle(point, 3.2, CombatWorld.team_color(hero.team))
			draw_arc(point, 3.2, 0.0, TAU, 12, Color(0, 0, 0, 0.6), 1.0)
	var brutus := game.get_node_or_null("Brutus") as Node3D
	if brutus != null:
		var point := _to_panel(brutus.global_position.x, brutus.global_position.z)
		draw_circle(point, 3.6, Color(1.0, 0.86, 0.3))
		draw_arc(point, 5.0, 0.0, TAU, 16, Color.WHITE, 1.5)
	# Camera window on the ground plane.
	if camera != null and camera_rig != null:
		var aspect := 0.5625
		var viewport := get_viewport()
		if viewport != null and viewport.get_visible_rect().size.y > 0.0:
			aspect = viewport.get_visible_rect().size.x / viewport.get_visible_rect().size.y
		var half_width := camera.size * aspect * 0.5
		var tilt := absf(deg_to_rad(camera.rotation_degrees.x))
		var half_depth := camera.size * 0.5 / maxf(sin(tilt), 0.2)
		var center_z := camera_rig.global_position.z + _camera_ground_offset()
		var window := _rect(Vector2(camera_rig.global_position.x, center_z),
			Vector2(half_width, half_depth))
		draw_rect(window.intersection(panel), Color(1.0, 1.0, 1.0, 0.85), false, 1.5)
	# Tap hint under the panel.
	var font := get_theme_default_font()
	var hint := "MAPA" if not full_view else "VOLTAR"
	var hint_size := 11
	var width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, hint_size).x
	var at := Vector2((size.x - width) * 0.5, size.y + 13.0)
	draw_string_outline(font, at, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, 4,
		Color(0.02, 0.03, 0.03, 0.9))
	draw_string(font, at, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(1.0, 0.85, 0.45))


## Where the camera's centre ray hits the ground, relative to the rig.
func _camera_ground_offset() -> float:
	if camera == null:
		return 0.0
	var tilt := deg_to_rad(camera.rotation_degrees.x)
	var forward := Vector3(0.0, sin(tilt), -cos(tilt))
	if absf(forward.y) < 0.001:
		return 0.0
	var t := -camera.position.y / forward.y
	return camera.position.z + forward.z * t
