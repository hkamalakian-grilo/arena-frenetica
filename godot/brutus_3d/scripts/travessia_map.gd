class_name TravessiaMap
extends Node3D

## Builds only the current greybox presentation of Travessia.
## Gameplay positions live in TravessiaDefinition, so this node can later be
## replaced by authored terrain, vegetation and props without rewriting rules.

const TERRAIN_ART := preload("res://assets/maps/travessia_terrain_v6.png")
const TERRAIN_DEPTH := preload("res://assets/maps/travessia_depth_v1.png")
const MODULE_DEPTH := preload("res://assets/maps/travessia_depth_v1.png")
const UPPER_LEFT_CAMP_ART := preload(
	"res://assets/maps/upper_left_camp_full_v1.png")
const UPPER_RIGHT_CAMP_ART := preload(
	"res://assets/maps/upper_right_camp_full_v1.png")
const LOWER_LEFT_CAMP_ART := preload(
	"res://assets/maps/lower_left_camp_full_v1.png")
const LOWER_RIGHT_CAMP_ART := preload(
	"res://assets/maps/lower_right_camp_full_v1.png")
const NORTH_BOUNDARY_ART := preload(
	"res://assets/maps/north_boundary_full_v1.png")
const SOUTH_BOUNDARY_ART := preload(
	"res://assets/maps/south_boundary_full_v1.png")
const WEST_OUTER_FOREST_ART := preload(
	"res://assets/maps/west_outer_forest_full_v1.png")
const EAST_OUTER_FOREST_ART := preload(
	"res://assets/maps/east_outer_forest_full_v1.png")
const NORTH_RIVER_BANK_ART := preload(
	"res://assets/maps/north_river_bank_full_v1.png")
const SOUTH_RIVER_BANK_ART := preload(
	"res://assets/maps/south_river_bank_full_v1.png")
const DRAGON_ISLAND_ART := preload(
	"res://assets/maps/dragon_island_full_v1.png")
const LEFT_LANE_BRIDGE_ART := preload(
	"res://assets/maps/left_lane_bridge_full_v1.png")
const RIGHT_LANE_BRIDGE_ART := preload(
	"res://assets/maps/right_lane_bridge_full_v1.png")
const TOWER_PLATFORM_ART := preload("res://assets/maps/tower_platform_v1.png")
const MODULAR_BRIDGE_SCENE := preload(
	"res://scenes/world/modular_bridge_3d.tscn")
const DRAGON_BRIDGE_WIDTH := 2.06
const DRAGON_BRIDGE_ISLAND_OVERLAP := 0.20
const NORTH_BRIDGE_START_SCALE := 0.93
const NORTH_GATE_EDGE_Z := -4.38
const NORTH_ISLAND_ENTRY_Z := -2.67
const SOUTH_GATE_EDGE_Z := 3.36
const SOUTH_ISLAND_ENTRY_Z := 1.95
const TOWER_PLATFORM_REGION := Rect2(136, 206, 1000, 820)
const TOWER_PLATFORM_WIDTH := 1.92
const UPPER_LEFT_CAMP_REGION := Rect2(175.0, 300.0, 320.0, 360.0)
const UPPER_RIGHT_CAMP_REGION := Rect2(418.0, 300.0, 320.0, 360.0)
const LOWER_LEFT_CAMP_REGION := Rect2(175.0, 980.0, 320.0, 450.0)
const LOWER_RIGHT_CAMP_REGION := Rect2(418.0, 980.0, 320.0, 450.0)

var dragon_access: Node3D
var terrain_layer: Node3D
var static_props: Node3D
var dynamic_props: Node3D
var tower_platforms: Dictionary = {}


func build() -> void:
	name = "TravessiaMap"
	add_to_group("travessia_map")
	_create_visual_layers()
	_build_environment()
	_add_terrain_art()
	_add_static_art_modules()
	_add_jungle_modules()
	_add_tower_platforms()
	_add_floor_collision()
	_add_boundary_collisions()


func _create_visual_layers() -> void:
	terrain_layer = Node3D.new()
	terrain_layer.name = "TerrainLayer"
	add_child(terrain_layer)
	static_props = Node3D.new()
	static_props.name = "StaticProps"
	add_child(static_props)
	dynamic_props = Node3D.new()
	dynamic_props.name = "DynamicProps"
	add_child(dynamic_props)


func _add_terrain_art() -> void:
	var map_art := MeshInstance3D.new()
	map_art.name = "TerrainArt"
	var mesh := PlaneMesh.new()
	mesh.size = TravessiaDefinition.MAP_SIZE
	# Enough vertices for the authored height map to raise forests, walls,
	# rocks and the dragon island without changing the approved texture.
	mesh.subdivide_width = 95
	mesh.subdivide_depth = 191
	map_art.mesh = mesh
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, unshaded;

uniform sampler2D terrain_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D height_texture : filter_linear;
uniform float height_scale = 0.62;

void vertex() {
	float authored_height = textureLod(height_texture, UV, 0.0).r;
	VERTEX.y += authored_height * height_scale;
}

void fragment() {
	vec4 approved_art = texture(terrain_texture, UV);
	ALBEDO = approved_art.rgb;
	ALPHA = approved_art.a;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("terrain_texture", TERRAIN_ART)
	material.set_shader_parameter("height_texture", TERRAIN_DEPTH)
	material.set_shader_parameter("height_scale", 0.62)
	map_art.material_override = material
	map_art.position.y = 0.002
	map_art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map_art.set_meta("presentation", &"canonical_2_5d")
	terrain_layer.add_child(map_art)


func uses_canonical_2_5d_art() -> bool:
	return true


func _add_static_art_modules() -> void:
	var modules := Node3D.new()
	modules.name = "MapArtModules"
	static_props.add_child(modules)
	_add_full_map_art_module(modules, "NorthBoundary", NORTH_BOUNDARY_ART,
		&"boundary")
	_add_full_map_art_module(modules, "SouthBoundary", SOUTH_BOUNDARY_ART,
		&"boundary")
	_add_full_map_art_module(modules, "WestOuterForest",
		WEST_OUTER_FOREST_ART, &"outer_forest")
	_add_full_map_art_module(modules, "EastOuterForest",
		EAST_OUTER_FOREST_ART, &"outer_forest")
	_add_full_map_art_module(modules, "NorthRiverBank",
		NORTH_RIVER_BANK_ART, &"river_bank")
	_add_full_map_art_module(modules, "SouthRiverBank",
		SOUTH_RIVER_BANK_ART, &"river_bank")
	_add_full_map_art_module(modules, "DragonIsland", DRAGON_ISLAND_ART,
		&"dragon_island")
	_add_full_map_art_module(modules, "LeftLaneBridge", LEFT_LANE_BRIDGE_ART,
		&"lane_bridge")
	_add_full_map_art_module(modules, "RightLaneBridge", RIGHT_LANE_BRIDGE_ART,
		&"lane_bridge")


func _add_jungle_modules() -> void:
	var jungle_modules := Node3D.new()
	jungle_modules.name = "JungleModules"
	static_props.add_child(jungle_modules)
	_add_jungle_camp_module(jungle_modules, "UpperLeftCamp",
		UPPER_LEFT_CAMP_ART, UPPER_LEFT_CAMP_REGION)
	_add_jungle_camp_module(jungle_modules, "UpperRightCamp",
		UPPER_RIGHT_CAMP_ART, UPPER_RIGHT_CAMP_REGION)
	_add_jungle_camp_module(jungle_modules, "LowerLeftCamp",
		LOWER_LEFT_CAMP_ART, LOWER_LEFT_CAMP_REGION)
	_add_jungle_camp_module(jungle_modules, "LowerRightCamp",
		LOWER_RIGHT_CAMP_ART, LOWER_RIGHT_CAMP_REGION)


func _add_jungle_camp_module(parent: Node3D, node_name: String,
		camp_art: Texture2D, region: Rect2) -> void:
	var camp := _add_full_map_art_module(parent, node_name, camp_art,
		&"jungle_camp", 0.004)
	camp.set_meta("source_region", region)


func _add_full_map_art_module(parent: Node3D, node_name: String,
		module_art: Texture2D, module_kind: StringName,
		y_offset: float = 0.003) -> MeshInstance3D:
	var module := MeshInstance3D.new()
	module.name = node_name
	var mesh := PlaneMesh.new()
	mesh.size = TravessiaDefinition.MAP_SIZE
	mesh.subdivide_width = 95
	mesh.subdivide_depth = 191
	module.mesh = mesh
	module.position.y = y_offset
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, unshaded;

uniform sampler2D module_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D height_texture : filter_linear;
uniform float height_scale = 0.62;

void vertex() {
	float authored_height = textureLod(height_texture, UV, 0.0).r;
	VERTEX.y += authored_height * height_scale;
}

void fragment() {
	vec4 approved_art = texture(module_texture, UV);
	ALBEDO = approved_art.rgb;
	ALPHA = approved_art.a;
	ALPHA_SCISSOR_THRESHOLD = 0.05;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("module_texture", module_art)
	material.set_shader_parameter("height_texture", MODULE_DEPTH)
	material.set_shader_parameter("height_scale", 0.62)
	module.material_override = material
	module.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	module.set_meta("module_kind", module_kind)
	parent.add_child(module)
	return module


func _add_tower_platforms() -> void:
	var platforms_root := Node3D.new()
	platforms_root.name = "TowerPlatforms"
	static_props.add_child(platforms_root)
	for marker in TravessiaDefinition.tower_markers():
		var structure_id: StringName = marker.id
		var anchor := Node3D.new()
		anchor.name = String(structure_id).to_pascal_case()
		anchor.position = marker.position + Vector3(0, 0.012, 0)
		anchor.set_meta("structure_id", structure_id)
		platforms_root.add_child(anchor)
		var platform_art := Sprite3D.new()
		platform_art.name = "PlatformArt"
		var platform_texture := AtlasTexture.new()
		platform_texture.atlas = TOWER_PLATFORM_ART
		platform_texture.region = TOWER_PLATFORM_REGION
		platform_art.texture = platform_texture
		platform_art.pixel_size = TOWER_PLATFORM_WIDTH / TOWER_PLATFORM_REGION.size.x
		platform_art.rotation.x = -PI * 0.5
		platform_art.shaded = false
		platform_art.double_sided = true
		platform_art.modulate = Color(0.78, 0.79, 0.70, 1.0)
		platform_art.texture_filter = \
			BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		anchor.add_child(platform_art)
		tower_platforms[structure_id] = anchor


func get_tower_platform(structure_id: StringName) -> Node3D:
	return tower_platforms.get(structure_id) as Node3D


func move_tower_platform(structure_id: StringName, at_position: Vector3) -> bool:
	var platform := get_tower_platform(structure_id)
	if platform == null:
		return false
	platform.position = Vector3(at_position.x, 0.012, at_position.z)
	return true


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("102619")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9d5bd")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)


func _material(color: Color, roughness := 0.88) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _add_plane(node_name: String, size: Vector2, color: Color,
		at_position: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := PlaneMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = at_position
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _add_box(node_name: String, size: Vector3, color: Color,
		at_position: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color, 0.72)
	node.position = at_position
	add_child(node)
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


func _add_boundary(parent: Node3D, node_name: String, at_position: Vector3,
		size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at_position
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
	bridge.position = Vector3(0, 0.004, gate_edge_z)
	dragon_access.add_child(bridge)
	var growth_direction := signf(island_entry_z - gate_edge_z)
	var blended_island_entry := island_entry_z \
		+ growth_direction * DRAGON_BRIDGE_ISLAND_OVERLAP
	var bridge_length := absf(blended_island_entry - gate_edge_z)
	var start_scale := NORTH_BRIDGE_START_SCALE \
		if node_name == "NorthBridge" else 1.0
	bridge.configure(bridge_length, growth_direction, DRAGON_BRIDGE_WIDTH,
		start_scale, 1.0)
	bridge.reveal(duration)
	return bridge
