class_name TravessiaMap
extends Node3D

## Builds only the current greybox presentation of Travessia.
## Gameplay positions live in TravessiaDefinition, so this node can later be
## replaced by authored terrain, vegetation and props without rewriting rules.

const MAP_ART := preload("res://assets/maps/travessia_clean_v1.png")


func build() -> void:
	name = "TravessiaMap"
	_build_environment()
	_add_map_art()
	_add_floor_collision()
	_add_boundary_collisions()


func _add_map_art() -> void:
	var map_art := MeshInstance3D.new()
	map_art.name = "MapArt"
	var mesh := PlaneMesh.new()
	mesh.size = TravessiaDefinition.MAP_SIZE
	map_art.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_texture = MAP_ART
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	map_art.material_override = material
	map_art.position.y = 0.002
	map_art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(map_art)


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
