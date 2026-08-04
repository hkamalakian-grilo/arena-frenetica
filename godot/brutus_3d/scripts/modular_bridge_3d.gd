class_name ModularBridge3D
extends Node3D

## Reusable stone bridge built from independent 3D masonry. It deliberately
## contains no crop or sample from the old painted map.

const TARGET_ROW_DEPTH := 0.46
const MIN_ROW_COUNT := 4
const REST_Y := 0.08

var bridge_length := 1.0
var growth_direction := 1.0
var bridge_width := 2.1
var start_width_scale := 1.0
var end_width_scale := 1.0
var rows_root: Node3D
var row_nodes: Array[Node3D] = []
var _revealed_rows := 0
var _stone_materials: Array[StandardMaterial3D] = []


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
	var row_count := row_nodes.size()
	for row_index in range(row_count):
		var row := row_nodes[row_index]
		row.visible = false
		row.position.y = -0.26
		row.scale = Vector3(0.92, 0.12, 0.18)
		var delay := duration * 0.64 * float(row_index) \
			/ float(maxi(1, row_count - 1))
		var rise_duration := duration * 0.36
		var tween := row.create_tween()
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void: row.visible = true)
		tween.tween_property(row, "position:y", 0.0, rise_duration) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(row, "scale", Vector3.ONE,
			rise_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func() -> void: _revealed_rows += 1)


func is_fully_revealed() -> bool:
	return not row_nodes.is_empty() and _revealed_rows == row_nodes.size()


func get_row_count() -> int:
	return row_nodes.size()


func uses_composite_map_art() -> bool:
	return false


func _build_bridge() -> void:
	for child in get_children():
		child.queue_free()
	row_nodes.clear()
	_ensure_materials()
	rows_root = Node3D.new()
	rows_root.name = "DeckRows"
	add_child(rows_root)
	var row_count := maxi(MIN_ROW_COUNT, roundi(bridge_length / TARGET_ROW_DEPTH))
	var row_depth := bridge_length / float(row_count)
	for row_index in range(row_count):
		var progress := float(row_index) / float(maxi(1, row_count - 1))
		var width := bridge_width * lerpf(start_width_scale,
			end_width_scale, progress)
		var row := _build_row(row_index, row_depth, width)
		row.position.z = growth_direction * row_depth * (float(row_index) + 0.5)
		rows_root.add_child(row)
		row_nodes.append(row)
	_add_collision()


func _build_row(row_index: int, row_depth: float, width: float) -> Node3D:
	var row := Node3D.new()
	row.name = "Row%02d" % (row_index + 1)
	var joint := 0.035
	var side_stone_width := width * 0.23
	var center_stone_width := width - side_stone_width * 2.0 - joint * 2.0
	var stone_widths := [side_stone_width, center_stone_width, side_stone_width]
	var cursor := -width * 0.5
	for stone_index in range(3):
		var stone_width: float = stone_widths[stone_index]
		var stone := MeshInstance3D.new()
		stone.name = "Stone%d" % (stone_index + 1)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(stone_width - joint, 0.16,
			row_depth - joint)
		stone.mesh = mesh
		stone.position = Vector3(cursor + stone_width * 0.5,
			REST_Y, 0.0)
		stone.position.y += 0.014 if (row_index + stone_index) % 3 == 0 else 0.0
		stone.rotation.y = deg_to_rad(0.8 * (-1.0 if stone_index == 0 else 1.0))
		stone.material_override = _stone_materials[(row_index + stone_index) \
			% _stone_materials.size()]
		row.add_child(stone)
		cursor += stone_width + joint
	return row


func _ensure_materials() -> void:
	if not _stone_materials.is_empty():
		return
	for color in [Color("c9aa70"), Color("b99a65"), Color("d4b77d")]:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.96
		material.metallic = 0.0
		_stone_materials.append(material)


func _add_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "BridgeCollision"
	# The top of the collision stays flush with ground Y=0 so CharacterBody3D
	# actors do not hit an invisible vertical step when entering the bridge.
	body.position = Vector3(0.0, -0.08,
		growth_direction * bridge_length * 0.5)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(bridge_width, 0.16, bridge_length)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
