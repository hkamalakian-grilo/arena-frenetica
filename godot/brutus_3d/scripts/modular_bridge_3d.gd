class_name ModularBridge3D
extends Node3D

signal reveal_completed

## Reusable physical bridge for Travessia. The visible deck is assembled from
## complete masonry rows sampled from the approved lateral bridge, preserving
## its exact grout, palette, baked light and stone proportions.

const TARGET_ROW_DEPTH := 0.45
const MIN_ROW_COUNT := 4
const DECK_WIDTH_RATIO := 0.92
const MIN_DECK_WIDTH := 1.82
const DECK_THICKNESS := 0.08
# The authored river mesh gains a little height near both stone banks. Keeping
# the deck above that interpolation prevents water pixels from cutting through
# the masonry while collision remains on the canonical gameplay plane.
const REST_Y := 0.165

const MAP_ART := preload("res://assets/maps/travessia_terrain_v3.png")

## These are the two complete three-stone courses from the western bridge.
## Repeating courses, instead of stretching a bridge image, keeps every block
## at the same painted scale as the rest of the map.
const DECK_ROW_REGIONS := [
	Rect2i(164, 820, 57, 20),
	Rect2i(164, 842, 57, 19),
]

var bridge_length := 1.0
var growth_direction := 1.0
var bridge_width := 2.1
var start_width_scale := 1.0
var end_width_scale := 1.0
var rows_root: Node3D
var row_nodes: Array[Node3D] = []
var _materials: Dictionary = {}
var _row_textures: Dictionary = {}
var _revealed_rows := 0
var _collision_shape: CollisionShape3D


func configure(length: float, direction: float, width: float = 2.1,
		start_scale: float = 1.0, end_scale: float = 1.0) -> void:
	bridge_length = maxf(length, TARGET_ROW_DEPTH)
	growth_direction = 1.0 if direction >= 0.0 else -1.0
	bridge_width = maxf(width, 1.2)
	start_width_scale = clampf(start_scale, 0.80, 1.20)
	end_width_scale = clampf(end_scale, 0.80, 1.20)
	_build_bridge()


func reveal(duration: float = 1.2) -> void:
	_revealed_rows = 0
	_set_collision_enabled(false)
	var row_count := row_nodes.size()
	for row_index in range(row_count):
		var row := row_nodes[row_index]
		row.visible = false
		row.position.y = -0.28
		row.scale = Vector3(0.94, 0.12, 0.16)
		var delay := duration * 0.64 * float(row_index) \
			/ float(maxi(1, row_count - 1))
		var rise_duration := duration * 0.36
		var tween := row.create_tween()
		tween.set_ignore_time_scale(true)
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void: row.visible = true)
		tween.tween_property(row, "position:y", 0.0, rise_duration) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(row, "scale", Vector3.ONE,
			rise_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_on_row_revealed)


func is_fully_revealed() -> bool:
	return not row_nodes.is_empty() and _revealed_rows == row_nodes.size()


func get_row_count() -> int:
	return row_nodes.size()


func is_collision_enabled() -> bool:
	return _collision_shape != null and not _collision_shape.disabled


func _on_row_revealed() -> void:
	_revealed_rows += 1
	if _revealed_rows != row_nodes.size():
		return
	_set_collision_enabled(true)
	reveal_completed.emit()


func _build_bridge() -> void:
	for child in get_children():
		child.queue_free()
	row_nodes.clear()
	rows_root = Node3D.new()
	rows_root.name = "DeckRows"
	add_child(rows_root)
	var row_count := maxi(MIN_ROW_COUNT,
		roundi(bridge_length / TARGET_ROW_DEPTH))
	var row_depth := bridge_length / float(row_count)
	for row_index in range(row_count):
		var progress := float(row_index) / float(maxi(1, row_count - 1))
		var outer_width := bridge_width * lerpf(start_width_scale,
			end_width_scale, progress)
		var deck_width := maxf(MIN_DECK_WIDTH,
			outer_width * DECK_WIDTH_RATIO)
		var row := _build_row(row_index, row_count, row_depth, deck_width)
		row.position.z = growth_direction * row_depth \
			* (float(row_index) + 0.5)
		rows_root.add_child(row)
		row_nodes.append(row)
	_add_collision()


func _build_row(row_index: int, row_count: int, row_depth: float,
		deck_width: float) -> Node3D:
	var row := Node3D.new()
	row.name = "Row%02d" % (row_index + 1)
	var stone_tone := Color(0.37, 0.36, 0.30) \
		if row_index % 2 == 0 else Color(0.33, 0.32, 0.27)
	var foundation := _build_stone_box("StoneFoundation",
		Vector3(deck_width, DECK_THICKNESS, row_depth + 0.018),
		stone_tone)
	foundation.position.y = REST_Y - DECK_THICKNESS * 0.5
	row.add_child(foundation)
	var surface := MeshInstance3D.new()
	surface.name = "DeckSurface"
	var surface_mesh := PlaneMesh.new()
	surface_mesh.size = Vector2(deck_width - 0.018, row_depth + 0.014)
	surface.mesh = surface_mesh
	surface.position.y = REST_Y + 0.006
	var global_course := row_index if growth_direction > 0.0 \
		else row_count - row_index - 1
	surface.material_override = _deck_material(global_course)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	row.add_child(surface)
	return row


func _build_stone_box(node_name: String, size: Vector3,
		color: Color) -> MeshInstance3D:
	var stone := MeshInstance3D.new()
	stone.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	stone.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	material.metallic = 0.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	stone.material_override = material
	stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return stone


func _deck_material(course_index: int) -> StandardMaterial3D:
	var normalized_index := posmod(course_index, DECK_ROW_REGIONS.size())
	var key := "deck_%d" % normalized_index
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_texture = _deck_texture(normalized_index)
	material.albedo_color = Color.WHITE
	material.roughness = 0.96
	material.metallic = 0.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = \
		BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = material
	return material


func _deck_texture(course_index: int) -> ImageTexture:
	if _row_textures.has(course_index):
		return _row_textures[course_index] as ImageTexture
	var source_image := MAP_ART.get_image()
	var row_image := source_image.get_region(DECK_ROW_REGIONS[course_index])
	var texture := ImageTexture.create_from_image(row_image)
	_row_textures[course_index] = texture
	return texture


func _add_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "BridgeCollision"
	body.position = Vector3(0.0, 0.035,
		growth_direction * bridge_length * 0.5)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(bridge_width, 0.10, bridge_length)
	collision.shape = shape
	collision.disabled = true
	_collision_shape = collision
	body.add_child(collision)
	add_child(body)


func _set_collision_enabled(enabled: bool) -> void:
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", not enabled)
