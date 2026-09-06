class_name BlockMap
extends Node3D

## Rebuilds the approved painted Travessia with the modular 3D kit
## (assets/kit/map_kit.glb). The painting is the source of truth for looks:
## every tile takes the colour the painting has at that spot, and trees,
## bushes, walls and rocks are placed where the painted layers (forests,
## boundaries, river banks, jungle camps) are opaque, tinted with their
## painted colour. Gameplay shape still comes from TravessiaDefinition.

const KIT_SCENE := preload("res://assets/kit/map_kit.glb")
const TERRAIN_ART := preload("res://assets/maps/travessia_terrain_v6.png")
const LAYERS := [
	{"kind": &"boundary", "texture": preload("res://assets/maps/north_boundary_full_v1.png")},
	{"kind": &"boundary", "texture": preload("res://assets/maps/south_boundary_full_v1.png")},
	{"kind": &"forest", "texture": preload("res://assets/maps/west_outer_forest_full_v1.png")},
	{"kind": &"forest", "texture": preload("res://assets/maps/east_outer_forest_full_v1.png")},
	{"kind": &"bank", "texture": preload("res://assets/maps/north_river_bank_full_v1.png")},
	{"kind": &"bank", "texture": preload("res://assets/maps/south_river_bank_full_v1.png")},
	{"kind": &"camp", "texture": preload("res://assets/maps/upper_left_camp_full_v1.png")},
	{"kind": &"camp", "texture": preload("res://assets/maps/upper_right_camp_full_v1.png")},
	{"kind": &"camp", "texture": preload("res://assets/maps/lower_left_camp_full_v1.png")},
	{"kind": &"camp", "texture": preload("res://assets/maps/lower_right_camp_full_v1.png")},
]
const TINTABLE := ["Grass", "Road", "Water", "Island", "Stone", "Leaf", "Pine", "Wood"]
const CELL := 0.5
const RIVER_HALF_WIDTH := 1.55
const LAKE_OUTER_RADIUS := 4.55
const ISLAND_WALL_OUTER := 2.40
const GATE_HALF_WIDTH := 1.0

enum Cell { GRASS, ROAD, WATER, ISLAND, ISLAND_WALL, BRIDGE }

var pieces: Dictionary = {}
## Untinted copies for plain MeshInstance3D nodes (platforms, pit, gates).
var plain_pieces: Dictionary = {}
var multimeshes: Dictionary = {}
var columns := 0
var rows := 0
var cells: PackedInt32Array = PackedInt32Array()
var gate_blocks: Array[MeshInstance3D] = []
var tower_platforms: Dictionary = {}
var terrain_image: Image
var layer_images: Array = []
var _pending: Dictionary = {}


func build() -> void:
	name = "BlockMap"
	_load_kit()
	_load_painting()
	_classify()
	_place_ground()
	_place_props()
	_place_structures()
	_place_island_wall()


# ---------------------------------------------------------------------------
# Kit and painting
# ---------------------------------------------------------------------------

func _load_kit() -> void:
	var kit := KIT_SCENE.instantiate()
	for child in kit.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var mesh := mesh_instance.mesh.duplicate(true) as Mesh
		var is_tile := mesh_instance.name.begins_with("tile_")
		# Tiles sit at ground level: no vertical gradient, or they all darken.
		ToonStyle.convert_mesh(mesh, 0.012 if is_tile else 0.02, 0.35 if is_tile else 1.3,
			1.0, PackedStringArray(TINTABLE), 1.0 if is_tile else 0.78)
		pieces[StringName(mesh_instance.name)] = mesh
		var plain := mesh_instance.mesh.duplicate(true) as Mesh
		ToonStyle.convert_mesh(plain, 0.02, 1.3, 1.05, PackedStringArray(), 0.8)
		plain_pieces[StringName(mesh_instance.name)] = plain
	kit.free()


func _load_painting() -> void:
	terrain_image = TERRAIN_ART.get_image()
	if terrain_image.is_compressed():
		terrain_image.decompress()
	for layer in LAYERS:
		var image: Image = layer.texture.get_image()
		if image.is_compressed():
			image.decompress()
		layer_images.append({"kind": layer.kind, "image": image})


func piece_names() -> Array:
	return pieces.keys()


func _pixel(image: Image, point: Vector2) -> Vector2i:
	var u := (point.x + TravessiaDefinition.MAP_SIZE.x * 0.5) / TravessiaDefinition.MAP_SIZE.x
	var v := (point.y + TravessiaDefinition.MAP_SIZE.y * 0.5) / TravessiaDefinition.MAP_SIZE.y
	return Vector2i(clampi(int(u * image.get_width()), 0, image.get_width() - 1),
		clampi(int(v * image.get_height()), 0, image.get_height() - 1))


## Average painted colour (and alpha) over a small patch around `point`.
func _sample(image: Image, point: Vector2, spread := 0.16) -> Color:
	var total := Color(0, 0, 0, 0)
	var count := 0
	for dx in [-spread, 0.0, spread]:
		for dz in [-spread, 0.0, spread]:
			var pixel := _pixel(image, point + Vector2(dx, dz))
			total += image.get_pixelv(pixel)
			count += 1
	return total / count


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


func _queue(piece: StringName, transform: Transform3D, tint := Color.WHITE) -> void:
	if not pieces.has(piece):
		push_warning("Map kit is missing piece %s" % piece)
		return
	if not _pending.has(piece):
		_pending[piece] = {"transforms": [], "colors": []}
	_pending[piece].transforms.append(transform)
	_pending[piece].colors.append(tint)


func _flush() -> void:
	for piece in _pending:
		var transforms: Array = _pending[piece].transforms
		var colors: Array = _pending[piece].colors
		var multimesh: MultiMesh
		if multimeshes.has(piece):
			multimesh = multimeshes[piece]
		else:
			multimesh = MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = true
			multimesh.mesh = pieces[piece]
			multimeshes[piece] = multimesh
		var start := multimesh.instance_count
		# Godot drops instance data when instance_count changes: re-apply.
		var old_transforms: Array = []
		var old_colors: Array = []
		for index in range(start):
			old_transforms.append(multimesh.get_instance_transform(index))
			old_colors.append(multimesh.get_instance_color(index))
		multimesh.instance_count = start + transforms.size()
		for index in range(start):
			multimesh.set_instance_transform(index, old_transforms[index])
			multimesh.set_instance_color(index, old_colors[index])
		for index in range(transforms.size()):
			multimesh.set_instance_transform(start + index, transforms[index])
			multimesh.set_instance_color(start + index, colors[index])
		if not has_node(NodePath(String(piece))):
			var node := MultiMeshInstance3D.new()
			node.name = String(piece)
			node.multimesh = multimesh
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				if not String(piece).begins_with("tile_") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
	_pending.clear()


func _place_ground() -> void:
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
			var painted := _sample(terrain_image, point)
			if kind == Cell.BRIDGE:
				painted = Color(0.55, 0.36, 0.17)
			_queue(piece, _tile_transform(point, 0.0, CELL), _boost(painted, 0.90))
	_flush()


## Props come from the painted layers: wherever a layer is opaque, place the
## piece that matches its colour there, tinted with that colour.
func _place_props() -> void:
	for row in range(rows):
		for column in range(columns):
			var kind := cells[row * columns + column]
			if _is_open(kind) or kind == Cell.ISLAND_WALL or kind == Cell.WATER:
				continue
			var point := _cell_center(column, row)
			var placed := false
			for layer in layer_images:
				var painted: Color = _sample(layer.image, point, 0.12)
				if painted.a < 0.55:
					continue
				_place_layer_prop(layer.kind, point, column, row, painted)
				placed = true
				break
			if placed:
				continue
	# Bridge posts at lane bridge corners, tinted like the painted stone.
	for lane_x in TravessiaDefinition.LANE_X:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var post := Vector2(lane_x + sx * 1.35, sz * (RIVER_HALF_WIDTH + 0.15))
				_queue(&"bridge_post", _tile_transform(post, 0.0, 1.0), Color(0.62, 0.60, 0.55))
	_flush()


## Painted colours are authored for a flat picture; lit blocks need a lift so
## the map keeps the picture's brightness under real light and shadow.
func _boost(painted: Color, gain: float) -> Color:
	return Color(minf(painted.r * gain, 1.0), minf(painted.g * gain, 1.0), minf(painted.b * gain, 1.0))


func _place_layer_prop(kind: StringName, point: Vector2, column: int, row: int, painted: Color) -> void:
	var tint := _boost(painted, 0.96)
	var hue := painted.h
	var green := painted.s > 0.25 and hue > 0.16 and hue < 0.45
	var purple := painted.s > 0.25 and hue > 0.65 and hue < 0.95
	var yaw := float((column * 7 + row * 13) % 360) * TAU / 360.0
	var coarse := column % 2 == 0 and row % 2 == 0
	if purple:
		_queue(&"flower", _tile_transform(point, yaw, 0.9), tint)
		return
	if green:
		# Painted foliage: a tree on the coarse grid, a bush elsewhere.
		if coarse and kind != &"camp":
			_queue(&"tree_round", _tile_transform(point, yaw, 0.85), tint)
		else:
			_queue(&"bush", _tile_transform(point, yaw, 0.72), tint)
		return
	# Neutral colours: stone walls on the boundary, rocks elsewhere.
	if kind == &"boundary":
		_queue(&"wall_stone", _tile_transform(point, 0.0, CELL * 1.02), tint)
	elif (column + row) % 2 == 0:
		_queue(&"rock", _tile_transform(point, yaw, 0.75), tint)


func _place_structures() -> void:
	var platforms_root := Node3D.new()
	platforms_root.name = "TowerPlatforms"
	add_child(platforms_root)
	for marker in TravessiaDefinition.tower_markers():
		var anchor := MeshInstance3D.new()
		anchor.name = String(marker.id).to_pascal_case()
		anchor.mesh = plain_pieces.get(&"platform_tower")
		anchor.position = marker.position + Vector3(0, 0.01, 0)
		anchor.set_meta("structure_id", marker.id)
		platforms_root.add_child(anchor)
		tower_platforms[marker.id] = anchor
	for marker in TravessiaDefinition.main_tower_markers():
		var core := MeshInstance3D.new()
		core.name = String(marker.id).to_pascal_case() + "Platform"
		core.mesh = plain_pieces.get(&"platform_core")
		core.position = marker.position + Vector3(0, 0.01, 0)
		add_child(core)
	var pit := MeshInstance3D.new()
	pit.name = "DragonPit"
	pit.mesh = plain_pieces.get(&"dragon_pit")
	pit.position = Vector3(0, 0.02, 0)
	add_child(pit)


## Stone ring around the island, tinted like the painted island stone. The
## blocks in front of the two gates are separate nodes so the hatch event can
## remove them.
func _place_island_wall() -> void:
	var gates := Node3D.new()
	gates.name = "DragonGates"
	add_child(gates)
	var count := 26
	var radius := (TravessiaDefinition.DRAGON_ISLAND_RADIUS + ISLAND_WALL_OUTER) * 0.5
	var stone := _sample(terrain_image, Vector2(0.0, -radius))
	var tint := Color(stone.r, stone.g, stone.b).lightened(0.1)
	for index in range(count):
		var angle := TAU * index / count
		var point := Vector2(cos(angle), sin(angle)) * radius
		var transform := _tile_transform(point, -angle, 0.62)
		if absf(point.x) < GATE_HALF_WIDTH:
			var block := MeshInstance3D.new()
			block.name = "Gate%d" % index
			block.mesh = plain_pieces.get(&"wall_stone")
			block.transform = transform
			gates.add_child(block)
			gate_blocks.append(block)
		else:
			_queue(&"wall_stone", transform, tint)
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
