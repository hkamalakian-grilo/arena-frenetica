class_name BlockMap
extends Node3D

## Builds the Travessia out of the modular 3D kit (assets/kit/map_kit.glb).
## The grid is derived from TravessiaDefinition's walkable mask, so gameplay
## data stays the single source of truth: change a rectangle and the blocks
## follow. Every piece type is one MultiMeshInstance3D; real light and shadow
## do the depth work the painted map faked.

const KIT_SCENE := preload("res://assets/kit/map_kit.glb")
const CELL := 0.5
const RIVER_HALF_WIDTH := 1.55
const LAKE_OUTER_RADIUS := 4.55
const ISLAND_WALL_OUTER := 2.40
const GATE_HALF_WIDTH := 1.0

enum Cell { GRASS, ROAD, WATER, ISLAND, ISLAND_WALL, BRIDGE }

var pieces: Dictionary = {}
var multimeshes: Dictionary = {}
var columns := 0
var rows := 0
var cells: PackedInt32Array = PackedInt32Array()
var gate_blocks: Array[MeshInstance3D] = []
var tower_platforms: Dictionary = {}
var rng := RandomNumberGenerator.new()


func build() -> void:
	name = "BlockMap"
	rng.seed = 20260905
	_load_kit()
	_classify()
	_place_ground()
	_place_props()
	_place_structures()
	_place_island_wall()


# ---------------------------------------------------------------------------
# Kit
# ---------------------------------------------------------------------------

func _load_kit() -> void:
	var kit := KIT_SCENE.instantiate()
	for child in kit.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var mesh := mesh_instance.mesh.duplicate(true) as Mesh
		var is_tile := mesh_instance.name.begins_with("tile_")
		ToonStyle.convert_mesh(mesh, 0.012 if is_tile else 0.02, 0.35 if is_tile else 1.3)
		pieces[StringName(mesh_instance.name)] = mesh
	kit.free()


func piece_names() -> Array:
	return pieces.keys()


func _multimesh_for(piece: StringName) -> MultiMesh:
	if multimeshes.has(piece):
		return multimeshes[piece]
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = pieces[piece]
	multimesh.instance_count = 0
	multimeshes[piece] = multimesh
	return multimesh


var _pending: Dictionary = {}


func _queue(piece: StringName, transform: Transform3D) -> void:
	if not pieces.has(piece):
		push_warning("Map kit is missing piece %s" % piece)
		return
	if not _pending.has(piece):
		_pending[piece] = []
	_pending[piece].append(transform)


func _flush() -> void:
	for piece in _pending:
		var transforms: Array = _pending[piece]
		var multimesh := _multimesh_for(piece)
		var start := multimesh.instance_count
		multimesh.instance_count = start + transforms.size()
		for index in range(transforms.size()):
			multimesh.set_instance_transform(start + index, transforms[index])
		if not has_node(NodePath(String(piece))):
			var node := MultiMeshInstance3D.new()
			node.name = String(piece)
			node.multimesh = multimesh
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				if not String(piece).begins_with("tile_") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
	_pending.clear()


# ---------------------------------------------------------------------------
# Grid
# ---------------------------------------------------------------------------

func _classify() -> void:
	columns = int(ceil(TravessiaDefinition.MAP_SIZE.x / CELL))
	rows = int(ceil(TravessiaDefinition.MAP_SIZE.y / CELL))
	cells.resize(columns * rows)
	for row in range(rows):
		for column in range(columns):
			cells[row * columns + column] = _classify_point(_cell_center(column, row))


func _cell_center(column: int, row: int) -> Vector2:
	return Vector2((column + 0.5) * CELL - TravessiaDefinition.MAP_SIZE.x * 0.5,
		(row + 0.5) * CELL - TravessiaDefinition.MAP_SIZE.y * 0.5)


func cell_at(column: int, row: int) -> int:
	if column < 0 or row < 0 or column >= columns or row >= rows:
		return Cell.GRASS
	return cells[row * columns + column]


func _classify_point(point: Vector2) -> int:
	var radius := point.length()
	if radius < TravessiaDefinition.DRAGON_ISLAND_RADIUS:
		return Cell.ISLAND
	if radius < ISLAND_WALL_OUTER:
		return Cell.ISLAND_WALL
	var walkable := TravessiaDefinition.is_walkable(point, false, 0.0)
	var in_river := absf(point.y) < RIVER_HALF_WIDTH
	var in_lake := radius < LAKE_OUTER_RADIUS
	if walkable and (in_river or in_lake):
		return Cell.BRIDGE
	if walkable:
		return Cell.ROAD
	if in_river or in_lake:
		return Cell.WATER
	return Cell.GRASS


func _is_open(kind: int) -> bool:
	return kind == Cell.ROAD or kind == Cell.BRIDGE or kind == Cell.ISLAND


# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------

func _tile_transform(point: Vector2, yaw := 0.0, scale := 1.0) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale))
	return Transform3D(basis, Vector3(point.x, 0.0, point.y))


func _place_ground() -> void:
	var tile_scale := CELL
	for row in range(rows):
		for column in range(columns):
			var point := _cell_center(column, row)
			var kind := cells[row * columns + column]
			var piece: StringName
			match kind:
				Cell.ROAD:
					piece = &"tile_road"
				Cell.BRIDGE:
					piece = &"tile_bridge"
				Cell.WATER:
					piece = &"tile_water"
				Cell.ISLAND, Cell.ISLAND_WALL:
					piece = &"tile_island"
				_:
					piece = &"tile_grass"
			_queue(piece, _tile_transform(point, 0.0, tile_scale))
	_flush()


func _place_props() -> void:
	var border_cells := 1
	for row in range(rows):
		for column in range(columns):
			var kind := cells[row * columns + column]
			if kind != Cell.GRASS:
				continue
			var point := _cell_center(column, row)
			var on_border := column < border_cells or row < border_cells \
				or column >= columns - border_cells or row >= rows - border_cells
			if on_border:
				if (column + row) % 2 == 0:
					_queue(&"wall_stone", _tile_transform(point, 0.0, 0.98))
				continue
			var edge := _touches_open(column, row)
			var near_water := _touches(column, row, Cell.WATER)
			var roll := rng.randf()
			if edge:
				# Hedge along every path: bushes with the occasional tree.
				if roll < 0.62:
					_queue(&"bush", _tile_transform(point, rng.randf() * TAU, 0.75 + rng.randf() * 0.2))
				elif roll < 0.86:
					_queue(&"tree_round", _tile_transform(point, rng.randf() * TAU, 0.62 + rng.randf() * 0.15))
				else:
					_queue(&"rock", _tile_transform(point, rng.randf() * TAU, 0.8))
			elif near_water:
				if roll < 0.35:
					_queue(&"rock", _tile_transform(point, rng.randf() * TAU, 0.7))
			else:
				if roll < 0.10:
					_queue(&"tree_pine", _tile_transform(point, rng.randf() * TAU, 0.7 + rng.randf() * 0.2))
				elif roll < 0.20:
					_queue(&"tree_round", _tile_transform(point, rng.randf() * TAU, 0.7 + rng.randf() * 0.2))
				elif roll < 0.25:
					_queue(&"rock", _tile_transform(point, rng.randf() * TAU, 0.7))
				elif roll < 0.31:
					_queue(&"flower", _tile_transform(point, rng.randf() * TAU, 0.9))
	# Bridge posts at lane bridge corners.
	for lane_x in TravessiaDefinition.LANE_X:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var post := Vector2(lane_x + sx * 1.35, sz * (RIVER_HALF_WIDTH + 0.15))
				_queue(&"bridge_post", _tile_transform(post, 0.0, 1.0))
	_flush()


func _touches_open(column: int, row: int) -> bool:
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _is_open(cell_at(column + offset.x, row + offset.y)):
			return true
	return false


func _touches(column: int, row: int, kind: int) -> bool:
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if cell_at(column + offset.x, row + offset.y) == kind:
			return true
	return false


func _place_structures() -> void:
	var platforms_root := Node3D.new()
	platforms_root.name = "TowerPlatforms"
	add_child(platforms_root)
	for marker in TravessiaDefinition.tower_markers():
		var anchor := MeshInstance3D.new()
		anchor.name = String(marker.id).to_pascal_case()
		anchor.mesh = pieces.get(&"platform_tower")
		anchor.position = marker.position + Vector3(0, 0.01, 0)
		anchor.set_meta("structure_id", marker.id)
		platforms_root.add_child(anchor)
		tower_platforms[marker.id] = anchor
	for marker in TravessiaDefinition.main_tower_markers():
		var core := MeshInstance3D.new()
		core.name = String(marker.id).to_pascal_case() + "Platform"
		core.mesh = pieces.get(&"platform_core")
		core.position = marker.position + Vector3(0, 0.01, 0)
		add_child(core)
	var pit := MeshInstance3D.new()
	pit.name = "DragonPit"
	pit.mesh = pieces.get(&"dragon_pit")
	pit.position = Vector3(0, 0.02, 0)
	add_child(pit)


## Stone ring around the island. The blocks in front of the two gates are
## separate nodes so the hatch event can remove them.
func _place_island_wall() -> void:
	var gates := Node3D.new()
	gates.name = "DragonGates"
	add_child(gates)
	var count := 26
	var radius := (TravessiaDefinition.DRAGON_ISLAND_RADIUS + ISLAND_WALL_OUTER) * 0.5
	for index in range(count):
		var angle := TAU * index / count
		var point := Vector2(cos(angle), sin(angle)) * radius
		var transform := _tile_transform(point, -angle, 0.62)
		if absf(point.x) < GATE_HALF_WIDTH:
			var block := MeshInstance3D.new()
			block.name = "Gate%d" % index
			block.mesh = pieces.get(&"wall_stone")
			block.transform = transform
			gates.add_child(block)
			gate_blocks.append(block)
		else:
			_queue(&"wall_stone", transform)
	_flush()


func open_gates() -> void:
	for block in gate_blocks:
		if is_instance_valid(block):
			block.visible = false


func get_tower_platform(structure_id: StringName) -> Node3D:
	return tower_platforms.get(structure_id) as Node3D


func move_tower_platform(structure_id: StringName, at_position: Vector3) -> bool:
	var platform := get_tower_platform(structure_id)
	if platform == null:
		return false
	platform.position = Vector3(at_position.x, 0.01, at_position.z)
	return true


func count_cells(kind: int) -> int:
	var total := 0
	for value in cells:
		if value == kind:
			total += 1
	return total
