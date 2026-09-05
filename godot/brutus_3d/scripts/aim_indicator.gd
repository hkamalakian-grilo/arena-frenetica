class_name AimIndicator
extends Control

## Screen-space skill indicator (like mobile brawlers): projects the ground
## strip of the current aim onto the HUD, so it never fights the terrain
## relief, shadows or depth. Reads BrutusController.aim_preview_* each frame.

var camera: Camera3D
var brutus: BrutusController


func setup(match_root: Node) -> void:
	camera = match_root.get_node("CameraRig/Camera3D") as Camera3D
	brutus = match_root.get_node("Brutus") as BrutusController
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	if brutus != null and (brutus.is_aim_preview_visible() or visible):
		queue_redraw()


## Screen corners of the aim strip: near-left, far-left, far-right, near-right.
func strip_points(source: BrutusController) -> PackedVector2Array:
	var points := PackedVector2Array()
	if camera == null or source == null or not source.is_aim_preview_visible():
		return points
	var extent := source.aim_preview_extent(source.aim_preview_kind)
	var direction := source.aim_preview_direction
	var side := Vector3(-direction.z, 0.0, direction.x) * (extent.x * 0.5)
	var origin := source.global_position + Vector3(0, 0.05, 0) + direction * 0.3
	var far := origin + direction * extent.y
	for world in [origin - side, far - side, far + side, origin + side]:
		points.append(camera.unproject_position(world))
	return points


func _draw() -> void:
	var points := strip_points(brutus)
	if points.size() != 4:
		return
	var tint := Color(1.0, 0.62, 0.15) if brutus.aim_preview_kind == &"q" else Color(0.82, 0.55, 1.0)
	var fill := PackedColorArray([
		Color(tint, 0.18), Color(tint, 0.42), Color(tint, 0.42), Color(tint, 0.18)])
	draw_polygon(points, fill)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color(tint, 0.9), 3.0, true)
	var tip := (points[1] + points[2]) * 0.5
	draw_circle(tip, 9.0, Color(tint, 0.95))
	draw_arc(tip, 14.0, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 2.0)
