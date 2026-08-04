class_name TravessiaMap
extends Node3D

## Fully modular 2.5D build of Travessia. No visual module depends on a complete
## painted-map bitmap: terrain, paths, water, bridges, platforms, walls and
## vegetation are independent nodes with stable gameplay anchors.

const MODULAR_BRIDGE_SCENE := preload("res://scenes/world/modular_bridge_3d.tscn")
const DRAGON_BRIDGE_WIDTH := 2.06
const DRAGON_BRIDGE_ISLAND_OVERLAP := 0.20
const NORTH_BRIDGE_START_SCALE := 0.93
const NORTH_GATE_EDGE_Z := -4.38
const NORTH_ISLAND_ENTRY_Z := -2.67
const SOUTH_GATE_EDGE_Z := 3.36
const SOUTH_ISLAND_ENTRY_Z := 1.95

var dragon_access: Node3D
var terrain_layer: Node3D
var static_props: Node3D
var dynamic_props: Node3D
var anchors: Node3D
var tower_platforms: Dictionary = {}
var structure_anchors: Dictionary = {}
var _materials: Dictionary = {}


func build() -> void:
	name = "TravessiaMap"
	add_to_group("travessia_map")
	_create_layers()
	_build_environment()
	_build_water_module()
	_build_land_modules()
	_build_path_modules()
	_build_island_module()
	_build_static_bridges()
	_build_structure_platforms()
	_build_wall_modules()
	_build_shore_modules()
	_build_jungle_modules()
	_build_outer_forest()
	_build_gameplay_anchors()
	_add_floor_collision()
	_add_boundary_collisions()


func uses_composite_map_art() -> bool:
	return false


func get_module_counts() -> Dictionary:
	return {
		"terrain": terrain_layer.get_child_count() if terrain_layer != null else 0,
		"static_props": static_props.get_child_count() if static_props != null else 0,
		"anchors": anchors.get_child_count() if anchors != null else 0,
	}


func _create_layers() -> void:
	terrain_layer = Node3D.new()
	terrain_layer.name = "TerrainModules"
	add_child(terrain_layer)
	static_props = Node3D.new()
	static_props.name = "StaticModules"
	add_child(static_props)
	dynamic_props = Node3D.new()
	dynamic_props.name = "DynamicModules"
	add_child(dynamic_props)
	anchors = Node3D.new()
	anchors.name = "GameplayAnchors"
	add_child(anchors)


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b2117")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bad8bd")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)


func _build_water_module() -> void:
	var water := MeshInstance3D.new()
	water.name = "WaterField"
	var mesh := PlaneMesh.new()
	mesh.size = TravessiaDefinition.MAP_SIZE + Vector2(0.8, 0.8)
	water.mesh = mesh
	water.position.y = -0.08
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, unshaded;
void fragment() {
	float ripple = sin((UV.x * 54.0 + UV.y * 38.0) + TIME * 0.65) * 0.025;
	float cross_wave = sin((UV.x * 31.0 - UV.y * 45.0) - TIME * 0.42) * 0.018;
	vec3 deep = vec3(0.025, 0.20, 0.31);
	vec3 shallow = vec3(0.045, 0.40, 0.52);
	ALBEDO = mix(deep, shallow, 0.46 + ripple + cross_wave);
	ROUGHNESS = 0.28;
	METALLIC = 0.08;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain_layer.add_child(water)


func _build_land_modules() -> void:
	var north_land := _add_ground_box(terrain_layer, "NorthLand", Vector2(17.2, 13.65),
		Color("397c42"), Vector3(0, 0.0, -10.18), 0.18)
	north_land.material_override = _grass_material()
	var south_land := _add_ground_box(terrain_layer, "SouthLand", Vector2(17.2, 13.65),
		Color("37783f"), Vector3(0, 0.0, 10.18), 0.18)
	south_land.material_override = _grass_material()


func _build_path_modules() -> void:
	var paths := Node3D.new()
	paths.name = "PathModules"
	terrain_layer.add_child(paths)
	# Base plazas are independent ellipses and establish the structure footprint.
	_add_ellipse(paths, "RedBasePlazaEdge", Vector2(7.55, 2.72),
		Color("80683f"), Vector3(0, 0.13, -12.75), 0.10)
	var red_plaza := _add_ellipse(paths, "RedBasePlaza", Vector2(7.38, 2.55),
		Color("b9995c"), Vector3(0, 0.19, -12.75), 0.09)
	red_plaza.material_override = _path_material()
	_add_ellipse(paths, "BlueBasePlazaEdge", Vector2(7.55, 2.72),
		Color("80683f"), Vector3(0, 0.13, 12.75), 0.10)
	var blue_plaza := _add_ellipse(paths, "BlueBasePlaza", Vector2(7.38, 2.55),
		Color("b9995c"), Vector3(0, 0.19, 12.75), 0.09)
	blue_plaza.material_override = _path_material()
	for lane_x in TravessiaDefinition.LANE_X:
		_add_capsule_path(paths, "NorthLane_%s" % absf(lane_x),
			Vector3(lane_x, 0.20, -7.75), 2.52, 9.75)
		_add_capsule_path(paths, "SouthLane_%s" % absf(lane_x),
			Vector3(lane_x, 0.20, 7.75), 2.52, 9.75)
	_add_capsule_path(paths, "NorthCenterPath", Vector3(0, 0.20, -7.55),
		2.55, 7.55)
	_add_capsule_path(paths, "SouthCenterPath", Vector3(0, 0.20, 7.55),
		2.55, 7.55)


func _add_capsule_path(parent: Node3D, node_name: String, center: Vector3,
		width: float, length: float) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = center
	parent.add_child(root)
	var middle_length := maxf(0.1, length - width)
	_add_ground_box(root, "Edge", Vector2(width + 0.18, middle_length),
		Color("80683f"), Vector3(0, 0.0, 0), 0.08)
	var paving := _add_ground_box(root, "Paving", Vector2(width, middle_length),
		Color("bda066"), Vector3(0, 0.055, 0), 0.07)
	paving.material_override = _path_material()
	for cap_sign in [-1.0, 1.0]:
		_add_ellipse(root, "EdgeCap%s" % cap_sign,
			Vector2((width + 0.18) * 0.5, (width + 0.18) * 0.5),
			Color("80683f"), Vector3(0, 0.04,
				cap_sign * middle_length * 0.5), 0.08)
		var paving_cap := _add_ellipse(root, "PavingCap%s" % cap_sign,
			Vector2(width * 0.5, width * 0.5), Color("bda066"),
			Vector3(0, 0.095, cap_sign * middle_length * 0.5), 0.07)
		paving_cap.material_override = _path_material()
	# Repeated paving joints are separate pieces and stay readable from above.
	var course_count := maxi(2, floori(length / 0.75))
	for course in range(course_count):
		var joint := MeshInstance3D.new()
		joint.name = "Joint%02d" % course
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width * 0.86, 0.012, 0.026)
		joint.mesh = mesh
		joint.position = Vector3(0, 0.102,
			-length * 0.5 + (course + 1) * length / float(course_count + 1))
		joint.material_override = _material("path_joint", Color("8f774f"), 0.98)
		joint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(joint)
	return root


func _build_island_module() -> void:
	var island := Node3D.new()
	island.name = "DragonIslandModule"
	terrain_layer.add_child(island)
	_add_ellipse(island, "StoneFoundation", Vector2(2.82, 2.82),
		Color("827d67"), Vector3(0, 0.08, 0), 0.20)
	var island_grass := _add_ellipse(island, "GrassInterior", Vector2(2.15, 2.15),
		Color("609b47"), Vector3(0, 0.21, 0), 0.12)
	island_grass.material_override = _grass_material()
	var ring := Node3D.new()
	ring.name = "IndependentStoneRing"
	island.add_child(ring)
	for index in range(22):
		var angle := TAU * float(index) / 22.0
		var stone := _add_box_mesh(ring, "RingStone%02d" % index,
			Vector3(0.72, 0.32, 0.42), Color("a49a78"),
			Vector3(cos(angle) * 2.48, 0.34, sin(angle) * 2.48))
		stone.rotation.y = -angle
		stone.scale.y = 0.88 + 0.12 * sin(float(index) * 2.3)


func _build_static_bridges() -> void:
	var bridges := Node3D.new()
	bridges.name = "StaticBridgeModules"
	static_props.add_child(bridges)
	for lane_x in TravessiaDefinition.LANE_X:
		var bridge := MODULAR_BRIDGE_SCENE.instantiate() as ModularBridge3D
		bridge.name = "LeftLaneBridge" if lane_x < 0.0 else "RightLaneBridge"
		bridge.position = Vector3(lane_x, 0.01, -1.90)
		bridges.add_child(bridge)
		bridge.configure(3.80, 1.0, 2.18, 1.0, 1.0)


func _build_structure_platforms() -> void:
	var platforms_root := Node3D.new()
	platforms_root.name = "StructurePlatforms"
	static_props.add_child(platforms_root)
	for marker in TravessiaDefinition.main_tower_markers():
		_build_platform_anchor(platforms_root, marker, true)
	for marker in TravessiaDefinition.tower_markers():
		_build_platform_anchor(platforms_root, marker, false)


func _build_platform_anchor(parent: Node3D, marker: Dictionary,
		is_main: bool) -> void:
	var structure_id: StringName = marker.id
	var anchor := Node3D.new()
	anchor.name = String(structure_id).to_pascal_case()
	anchor.position = marker.position
	anchor.set_meta("structure_id", structure_id)
	anchor.set_meta("platform_kind", &"main" if is_main else &"lane")
	parent.add_child(anchor)
	var radius := 1.68 if is_main else 1.10
	_add_ellipse(anchor, "PlatformFoundation", Vector2(radius, radius * 0.72),
		Color("8e7650"), Vector3(0, 0.18, 0), 0.18)
	_add_ellipse(anchor, "PlatformTop", Vector2(radius * 0.86, radius * 0.60),
		Color("c3a36a"), Vector3(0, 0.30, 0), 0.10)
	var segment_count := 14 if is_main else 10
	for index in range(segment_count):
		var angle := TAU * float(index) / float(segment_count)
		var block := _add_box_mesh(anchor, "EdgeStone%02d" % index,
			Vector3(radius * 0.44, 0.16, 0.22), Color("d1b57a"),
			Vector3(cos(angle) * radius * 0.78, 0.39,
				sin(angle) * radius * 0.54))
		block.rotation.y = -angle
	tower_platforms[structure_id] = anchor


func get_tower_platform(structure_id: StringName) -> Node3D:
	return tower_platforms.get(structure_id) as Node3D


func move_tower_platform(structure_id: StringName, at_position: Vector3) -> bool:
	var platform := get_tower_platform(structure_id)
	if platform == null:
		return false
	platform.position = Vector3(at_position.x, 0.0, at_position.z)
	var anchor := structure_anchors.get(structure_id) as Node3D
	if anchor != null:
		anchor.position = platform.position
	return true


func get_structure_anchor(structure_id: StringName) -> Node3D:
	return structure_anchors.get(structure_id) as Node3D


func _build_gameplay_anchors() -> void:
	for marker in TravessiaDefinition.main_tower_markers() \
			+ TravessiaDefinition.tower_markers():
		var anchor := Node3D.new()
		anchor.name = "%sAnchor" % String(marker.id).to_pascal_case()
		anchor.position = marker.position
		anchor.set_meta("structure_id", marker.id)
		anchors.add_child(anchor)
		structure_anchors[marker.id] = anchor
	for data in [
		{"name": "DragonObjective", "position": Vector3.ZERO},
		{"name": "BlueSpawn", "position": TravessiaDefinition.PLAYER_SPAWN},
		{"name": "RedSpawn", "position": Vector3(0, 0, -12.0)},
	]:
		var anchor := Node3D.new()
		anchor.name = data.name
		anchor.position = data.position
		anchors.add_child(anchor)


func _build_wall_modules() -> void:
	var walls := Node3D.new()
	walls.name = "WallModules"
	static_props.add_child(walls)
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var z: float = side * 15.85
		for index in range(13):
			var x := -7.2 + float(index) * 1.2
			_add_wall_segment(walls, "BackWall_%s_%02d" % [side, index],
				Vector3(x, 0.48, z), 1.12, 0.48, 0.58)
		for x in [-8.1, 8.1]:
			for index in range(4):
				_add_wall_segment(walls, "SideWall_%s_%s_%02d" % [side, x, index],
					Vector3(x, 0.48, side * (12.5 + index * 0.92)),
					0.54, 0.92, 0.58)
	# Central gate pillars visually mark the locked dragon approaches.
	for z in [NORTH_GATE_EDGE_Z, SOUTH_GATE_EDGE_Z]:
		for x in [-1.18, 1.18]:
			_add_stone_pillar(walls, "DragonGate_%s_%s" % [z, x],
				Vector3(x, 0.0, z), 0.42, 0.92)


func _build_shore_modules() -> void:
	var shores := Node3D.new()
	shores.name = "ShoreModules"
	static_props.add_child(shores)
	var rock_index := 0
	for shore_z in [-3.38, 3.38]:
		for column in range(17):
			var x := -8.0 + float(column)
			var near_lane := absf(absf(x) - absf(TravessiaDefinition.LANE_X[0])) < 1.25
			var near_center := absf(x) < 1.45
			if near_lane or near_center:
				continue
			_add_rock(shores, "ShoreRock%02d" % rock_index,
				Vector3(x, 0.12, shore_z + 0.10 * sin(float(column) * 1.7)),
				0.30 + 0.035 * float(column % 3))
			rock_index += 1


func _add_wall_segment(parent: Node3D, node_name: String, position: Vector3,
		width: float, depth: float, height: float) -> void:
	var base := _add_box_mesh(parent, node_name, Vector3(width, height, depth),
		Color("8a876f"), position)
	base.material_override = _material("wall_stone", Color("918d73"), 0.93)
	_add_box_mesh(base, "Cap", Vector3(width * 1.04, 0.16, depth * 1.05),
		Color("bbb083"), Vector3(0, height * 0.5 + 0.08, 0))


func _add_stone_pillar(parent: Node3D, node_name: String, position: Vector3,
		radius: float, height: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = position
	parent.add_child(root)
	_add_cylinder(root, "Shaft", radius, height, Color("8f8a70"),
		Vector3(0, height * 0.5, 0), 10)
	_add_cylinder(root, "Cap", radius * 1.18, 0.16, Color("c3b98e"),
		Vector3(0, height + 0.04, 0), 10)


func _build_jungle_modules() -> void:
	var jungle := Node3D.new()
	jungle.name = "JungleModules"
	static_props.add_child(jungle)
	var camps := [
		Vector3(-2.85, 0, -7.4), Vector3(2.85, 0, -7.4),
		Vector3(-2.85, 0, 7.4), Vector3(2.85, 0, 7.4),
	]
	for camp_index in range(camps.size()):
		var camp := Node3D.new()
		camp.name = "Camp%02d" % (camp_index + 1)
		camp.position = camps[camp_index]
		jungle.add_child(camp)
		var clearing := _add_ellipse(camp, "Clearing", Vector2(1.35, 1.12),
			Color("679b4b"), Vector3(0, 0.18, 0), 0.07)
		clearing.material_override = _grass_material()
		for index in range(9):
			var angle := TAU * float(index) / 9.0
			var radius := 1.46 + 0.10 * sin(float(index) * 2.1)
			var position := Vector3(cos(angle) * radius, 0,
				sin(angle) * radius * 0.82)
			if index % 3 == 0:
				_add_rock(camp, "CampRock%02d" % index, position,
					0.38 + 0.04 * index)
			else:
				_add_bush(camp, "CampBush%02d" % index, position,
					0.44 + 0.025 * index)


func _build_outer_forest() -> void:
	var forest := Node3D.new()
	forest.name = "OuterForestModules"
	static_props.add_child(forest)
	var tree_index := 0
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		for row in range(15):
			var z: float = -14.2 + float(row) * 2.02
			var x: float = side * (8.15 - 0.12 * float(row % 2))
			_add_tree(forest, "OuterTree%02d" % tree_index,
				Vector3(x, 0, z), 0.76 + 0.06 * (row % 3), tree_index)
			tree_index += 1
	# Interior clusters frame paths while keeping the requested left corridor open.
	for position in [
		Vector3(-1.15, 0, -10.0), Vector3(1.15, 0, -10.2),
		Vector3(-1.25, 0, 10.0), Vector3(1.25, 0, 10.2),
		Vector3(-7.1, 0, -5.2), Vector3(7.1, 0, -5.2),
		Vector3(-7.1, 0, 5.2), Vector3(7.1, 0, 5.2),
	]:
		_add_tree(forest, "InteriorTree%02d" % tree_index, position,
			0.72, tree_index)
		tree_index += 1


func _add_tree(parent: Node3D, node_name: String, position: Vector3,
		scale_factor: float, variant: int) -> void:
	var tree := Node3D.new()
	tree.name = node_name
	tree.position = position
	tree.scale = Vector3.ONE * scale_factor
	parent.add_child(tree)
	_add_cylinder(tree, "Trunk", 0.16, 0.65, Color("73502f"),
		Vector3(0, 0.325, 0), 8)
	var greens := [Color("174c31"), Color("1e6137"), Color("2a7040")]
	for tier in range(3):
		var crown := MeshInstance3D.new()
		crown.name = "Crown%d" % tier
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = 0.66 - tier * 0.11
		mesh.top_radius = 0.08
		mesh.height = 0.78
		mesh.radial_segments = 10
		crown.mesh = mesh
		crown.position.y = 0.68 + tier * 0.46
		crown.material_override = _material("tree_%d" % ((variant + tier) % 3),
			greens[(variant + tier) % 3], 0.90)
		tree.add_child(crown)


func _add_bush(parent: Node3D, node_name: String, position: Vector3,
		size: float) -> void:
	var bush := Node3D.new()
	bush.name = node_name
	bush.position = position
	parent.add_child(bush)
	for offset in [Vector3(-0.22, 0.24, 0), Vector3(0.22, 0.24, 0),
			Vector3(0, 0.34, -0.13)]:
		var leaf := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = size
		mesh.height = size * 1.45
		mesh.radial_segments = 10
		mesh.rings = 5
		leaf.mesh = mesh
		leaf.position = offset
		leaf.material_override = _material("bush", Color("1f6538"), 0.94)
		bush.add_child(leaf)


func _add_rock(parent: Node3D, node_name: String, position: Vector3,
		size: float) -> void:
	var rock := _add_box_mesh(parent, node_name,
		Vector3(size * 1.1, size * 0.72, size), Color("85846f"),
		position + Vector3(0, size * 0.30, 0))
	rock.rotation = Vector3(0.08, size * 0.3, 0.05)


func _material(key: String, color: Color, roughness := 0.88) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	_materials[key] = material
	return material


func _flat_material(key: String, color: Color) -> StandardMaterial3D:
	var flat_key := "flat_%s" % key
	if _materials.has(flat_key):
		return _materials[flat_key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[flat_key] = material
	return material


func _grass_material() -> ShaderMaterial:
	if _materials.has("procedural_grass"):
		return _materials.procedural_grass as ShaderMaterial
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	vec2 cells = floor(UV * vec2(46.0, 74.0));
	float grain = hash(cells);
	float broad = sin(UV.x * 24.0) * sin(UV.y * 31.0) * 0.5 + 0.5;
	vec3 dark_grass = vec3(0.075, 0.30, 0.16);
	vec3 light_grass = vec3(0.16, 0.46, 0.21);
	ALBEDO = mix(dark_grass, light_grass, grain * 0.42 + broad * 0.18 + 0.18);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_materials.procedural_grass = material
	return material


func _path_material() -> ShaderMaterial:
	if _materials.has("procedural_path"):
		return _materials.procedural_path as ShaderMaterial
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(91.7, 217.3))) * 43758.5453);
}
void fragment() {
	vec2 grid = UV * vec2(8.0, 22.0);
	float row = floor(grid.y);
	grid.x += mod(row, 2.0) * 0.5;
	vec2 cell = fract(grid);
	float edge = min(min(cell.x, 1.0 - cell.x), min(cell.y, 1.0 - cell.y));
	float mortar = smoothstep(0.035, 0.075, edge);
	float variation = hash(floor(grid));
	vec3 joint = vec3(0.30, 0.235, 0.13);
	vec3 stone_a = vec3(0.58, 0.43, 0.23);
	vec3 stone_b = vec3(0.76, 0.60, 0.34);
	vec3 stone = mix(stone_a, stone_b, variation * 0.72 + 0.14);
	ALBEDO = mix(joint, stone, mortar);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_materials.procedural_path = material
	return material


func _add_ground_box(parent: Node3D, node_name: String, size: Vector2,
		color: Color, position: Vector3, height: float) -> MeshInstance3D:
	var node := _add_box_mesh(parent, node_name,
		Vector3(size.x, height, size.y), color,
		position + Vector3(0, height * 0.5, 0))
	node.material_override = _flat_material("ground_%s" % color.to_html(), color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _add_box_mesh(parent: Node3D, node_name: String, size: Vector3,
		color: Color, position: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material("box_%s" % color.to_html(), color, 0.90)
	node.position = position
	parent.add_child(node)
	return node


func _add_ellipse(parent: Node3D, node_name: String, radii: Vector2,
		color: Color, position: Vector3, height: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = height
	mesh.radial_segments = 48
	node.mesh = mesh
	node.scale = Vector3(radii.x, 1.0, radii.y)
	node.position = position
	node.material_override = _flat_material("ellipse_%s" % color.to_html(), color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _add_cylinder(parent: Node3D, node_name: String, radius: float,
		height: float, color: Color, position: Vector3,
		segments: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	node.mesh = mesh
	node.position = position
	node.material_override = _material("cylinder_%s" % color.to_html(), color, 0.90)
	parent.add_child(node)
	return node


func _add_floor_collision() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorCollision"
	var floor_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(TravessiaDefinition.MAP_SIZE.x, 0.2,
		TravessiaDefinition.MAP_SIZE.y)
	floor_shape.shape = box_shape
	floor_shape.position = Vector3(0, -0.1, 0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)


func _add_boundary_collisions() -> void:
	var bounds := Node3D.new()
	bounds.name = "ArenaBounds"
	add_child(bounds)
	var half_width := TravessiaDefinition.MAP_SIZE.x * 0.5
	var half_depth := TravessiaDefinition.MAP_SIZE.y * 0.5
	_add_boundary(bounds, "North", Vector3(0, 1.5, -half_depth - 0.5),
		Vector3(TravessiaDefinition.MAP_SIZE.x + 2.0, 3.0, 1.0))
	_add_boundary(bounds, "South", Vector3(0, 1.5, half_depth + 0.5),
		Vector3(TravessiaDefinition.MAP_SIZE.x + 2.0, 3.0, 1.0))
	_add_boundary(bounds, "West", Vector3(-half_width - 0.5, 1.5, 0),
		Vector3(1.0, 3.0, TravessiaDefinition.MAP_SIZE.y))
	_add_boundary(bounds, "East", Vector3(half_width + 0.5, 1.5, 0),
		Vector3(1.0, 3.0, TravessiaDefinition.MAP_SIZE.y))


func _add_boundary(parent: Node3D, node_name: String, position: Vector3,
		size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func open_dragon_access(duration: float = 1.2) -> void:
	if dragon_access != null:
		return
	dragon_access = Node3D.new()
	dragon_access.name = "DragonAccessBridges"
	dynamic_props.add_child(dragon_access)
	_build_dragon_bridge("NorthBridge", NORTH_GATE_EDGE_Z,
		NORTH_ISLAND_ENTRY_Z, duration)
	_build_dragon_bridge("SouthBridge", SOUTH_GATE_EDGE_Z,
		SOUTH_ISLAND_ENTRY_Z, duration)


func is_dragon_access_open() -> bool:
	return dragon_access != null


func _build_dragon_bridge(node_name: String, gate_edge_z: float,
		island_entry_z: float, duration: float) -> Node3D:
	var bridge := MODULAR_BRIDGE_SCENE.instantiate() as ModularBridge3D
	bridge.name = node_name
	bridge.position = Vector3(0, 0.01, gate_edge_z)
	dragon_access.add_child(bridge)
	var growth_direction := signf(island_entry_z - gate_edge_z)
	var blended_island_entry := island_entry_z \
		+ growth_direction * DRAGON_BRIDGE_ISLAND_OVERLAP
	var bridge_length := absf(blended_island_entry - gate_edge_z)
	var start_scale := NORTH_BRIDGE_START_SCALE if node_name == "NorthBridge" else 1.0
	bridge.configure(bridge_length, growth_direction, DRAGON_BRIDGE_WIDTH,
		start_scale, 1.0)
	bridge.reveal(duration)
	return bridge
