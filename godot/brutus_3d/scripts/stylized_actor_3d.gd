class_name StylizedActor3D
extends Node3D

## Reusable lightweight 3D presentation for roster bots and minions.
## Front is -Z, matching Brutus and the canonical movement convention.

var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var body_root: Node3D
var motion_time := 0.0
var attack_left := 0.0
var hurt_left := 0.0
var base_scale := Vector3.ONE


func configure(actor_kind: StringName, variant: StringName, team: int) -> void:
	name = "Stylized3D"
	body_root = Node3D.new()
	body_root.name = "BodyRoot"
	add_child(body_root)
	if actor_kind == &"minion":
		_build_minion(team)
		scale = Vector3.ONE * 0.92
	elif variant == &"sol":
		_build_sol()
		scale = Vector3.ONE * 1.26
	elif variant == &"lyra":
		_build_lyra()
		scale = Vector3.ONE * 1.26
	else:
		_build_nix()
		scale = Vector3.ONE * 1.26
	base_scale = scale


func update_motion(delta: float, direction: Vector3, speed_ratio: float) -> void:
	attack_left = maxf(0.0, attack_left - delta)
	hurt_left = maxf(0.0, hurt_left - delta)
	var moving := speed_ratio > 0.05
	if moving:
		motion_time += delta * lerpf(5.0, 8.0, clampf(speed_ratio, 0.0, 1.0))
		rotation.y = atan2(-direction.x, -direction.z)
	else:
		motion_time += delta * 2.0
	var stride := sin(motion_time) * (0.52 if moving else 0.04)
	var bob := absf(sin(motion_time)) * (0.055 if moving else 0.018)
	body_root.position.y = bob
	if left_leg != null:
		left_leg.rotation.x = stride
	if right_leg != null:
		right_leg.rotation.x = -stride
	if attack_left > 0.0:
		var attack_phase := 1.0 - attack_left / 0.28
		var swing := sin(attack_phase * PI) * -1.25
		if right_arm != null:
			right_arm.rotation.x = swing
		if left_arm != null:
			left_arm.rotation.x = -stride * 0.25
	else:
		if left_arm != null:
			left_arm.rotation.x = -stride * 0.72
		if right_arm != null:
			right_arm.rotation.x = stride * 0.72
	var hurt_scale := 0.93 if hurt_left > 0.0 else 1.0
	scale = base_scale * hurt_scale


func trigger_attack() -> void:
	attack_left = 0.28


func trigger_hurt() -> void:
	hurt_left = 0.12


func face_direction(direction: Vector3) -> void:
	if direction.length_squared() > 0.001:
		rotation.y = atan2(-direction.x, -direction.z)


func _build_sol() -> void:
	var white := Color("f4ead1")
	var gold := Color("e5a72c")
	var glow := Color("ffd85a")
	_add_cylinder(body_root, "Robe", 0.42, 0.22, 0.90, white, Vector3(0, 0.72, 0))
	_add_cylinder(body_root, "RobeGold", 0.46, 0.40, 0.14, gold, Vector3(0, 0.32, 0), true)
	_add_sphere(body_root, "Head", 0.25, Color("f1c49e"), Vector3(0, 1.48, 0))
	_add_sphere(body_root, "Hood", 0.32, gold, Vector3(0, 1.53, 0.05), Vector3(1.0, 1.05, 0.88))
	_add_sphere(body_root, "Face", 0.215, Color("f6d2ad"), Vector3(0, 1.47, -0.14), Vector3(0.86, 0.90, 0.45))
	_add_sphere(body_root, "ShoulderL", 0.18, gold, Vector3(-0.36, 1.34, 0), Vector3(1.35, 0.65, 1.0))
	_add_sphere(body_root, "ShoulderR", 0.18, gold, Vector3(0.36, 1.34, 0), Vector3(1.35, 0.65, 1.0))
	_add_sphere(body_root, "Halo", 0.08, glow, Vector3(0, 2.02, 0))
	_add_box(body_root, "HaloRayX", Vector3(0.62, 0.035, 0.035), glow, Vector3(0, 2.02, 0), true)
	_add_box(body_root, "HaloRayZ", Vector3(0.035, 0.035, 0.62), glow, Vector3(0, 2.02, 0), true)
	_build_limbs(white, gold, 0.46, 0.64)
	# Staff follows the left hand.
	_add_cylinder(left_arm, "Staff", 0.035, 0.035, 1.38, Color("8d5a25"), Vector3(-0.02, -0.72, -0.03))
	_add_sphere(left_arm, "StaffOrb", 0.17, glow, Vector3(-0.02, -1.42, -0.03))
	_add_sphere(right_arm, "LightOrb", 0.13, glow, Vector3(0, -0.72, -0.10))


func _build_lyra() -> void:
	var green := Color("2f7c35")
	var dark_green := Color("1f502c")
	var leather := Color("704524")
	var gold := Color("c59a42")
	_add_capsule(body_root, "Torso", 0.29, 0.78, green, Vector3(0, 1.05, 0))
	_add_cylinder(body_root, "Cape", 0.38, 0.23, 0.80, dark_green, Vector3(0, 0.92, 0.16))
	_add_sphere(body_root, "Head", 0.24, Color("efc29b"), Vector3(0, 1.60, 0))
	_add_sphere(body_root, "Hood", 0.30, green, Vector3(0, 1.66, 0.06), Vector3(1.0, 1.08, 0.90))
	_add_sphere(body_root, "Face", 0.20, Color("f3c9a5"), Vector3(0, 1.58, -0.15), Vector3(0.88, 0.92, 0.48))
	_add_sphere(body_root, "ShoulderL", 0.17, gold, Vector3(-0.36, 1.35, 0), Vector3(1.35, 0.62, 1.0))
	_add_sphere(body_root, "ShoulderR", 0.17, gold, Vector3(0.36, 1.35, 0), Vector3(1.35, 0.62, 1.0))
	_add_box(body_root, "Belt", Vector3(0.62, 0.11, 0.34), leather, Vector3(0, 0.80, 0), true)
	_build_limbs(green, leather, 0.47, 0.66)
	# Stylized bow: three wooden segments attached to the left hand.
	var bow := Node3D.new()
	bow.name = "Bow"
	bow.position = Vector3(0, -0.55, -0.08)
	left_arm.add_child(bow)
	_add_box(bow, "BowCenter", Vector3(0.05, 0.62, 0.05), leather, Vector3.ZERO)
	var upper := _add_box(bow, "BowUpper", Vector3(0.05, 0.48, 0.05), gold, Vector3(0.12, 0.48, 0))
	upper.rotation.z = -0.42
	var lower := _add_box(bow, "BowLower", Vector3(0.05, 0.48, 0.05), gold, Vector3(-0.12, -0.48, 0))
	lower.rotation.z = -0.42
	_add_box(right_arm, "Arrow", Vector3(0.035, 0.035, 0.95), Color("b8a06a"), Vector3(0, -0.62, -0.38))


func _build_nix() -> void:
	var black := Color("20202b")
	var purple := Color("6530a0")
	var violet := Color("9b55df")
	var gold := Color("b08a48")
	_add_capsule(body_root, "Torso", 0.31, 0.80, black, Vector3(0, 1.03, 0))
	_add_cylinder(body_root, "TornCape", 0.40, 0.22, 0.78, purple.darkened(0.18), Vector3(0, 0.91, 0.18))
	_add_sphere(body_root, "Hood", 0.32, purple, Vector3(0, 1.60, 0.04), Vector3(1.0, 1.08, 0.92))
	_add_sphere(body_root, "VoidFace", 0.21, Color("11101a"), Vector3(0, 1.56, -0.15), Vector3(0.88, 0.86, 0.45))
	_add_sphere(body_root, "Eye", 0.055, violet, Vector3(0, 1.59, -0.30), Vector3(1.35, 0.55, 0.30), true)
	_add_box(body_root, "Belt", Vector3(0.64, 0.12, 0.35), gold, Vector3(0, 0.80, 0), true)
	_add_sphere(body_root, "ShoulderL", 0.20, purple, Vector3(-0.39, 1.36, 0), Vector3(1.45, 0.60, 1.0))
	_add_sphere(body_root, "ShoulderR", 0.20, purple, Vector3(0.39, 1.36, 0), Vector3(1.45, 0.60, 1.0))
	_build_limbs(black, purple, 0.49, 0.66)
	_add_dagger(left_arm, violet, gold, Vector3(0, -0.67, -0.08))
	_add_dagger(right_arm, violet, gold, Vector3(0, -0.67, -0.08))


func _build_minion(team: int) -> void:
	var team_color := Color("348fca") if team == 0 else Color("c94d58")
	var dark := team_color.darkened(0.36)
	var steel := Color("9ca7ae")
	_add_capsule(body_root, "Torso", 0.31, 0.72, dark, Vector3(0, 0.95, 0))
	_add_sphere(body_root, "Head", 0.27, Color("c99d77"), Vector3(0, 1.46, 0))
	_add_cylinder(body_root, "Helmet", 0.31, 0.22, 0.25, team_color, Vector3(0, 1.62, 0))
	_add_box(body_root, "HelmetCrest", Vector3(0.10, 0.32, 0.38), team_color.lightened(0.12), Vector3(0, 1.83, 0))
	_build_limbs(dark, steel, 0.40, 0.56)
	_add_box(left_arm, "Shield", Vector3(0.43, 0.52, 0.10), team_color, Vector3(0, -0.54, -0.12), true)
	_add_box(right_arm, "Sword", Vector3(0.08, 0.72, 0.10), steel, Vector3(0, -0.75, -0.05), true)


func _build_limbs(arm_color: Color, boot_color: Color, arm_length: float, leg_length: float) -> void:
	left_arm = _limb_pivot("LeftArm", Vector3(-0.36, 1.35, 0), arm_length, arm_color)
	right_arm = _limb_pivot("RightArm", Vector3(0.36, 1.35, 0), arm_length, arm_color)
	left_leg = _limb_pivot("LeftLeg", Vector3(-0.18, 0.73, 0), leg_length, boot_color, 0.13)
	right_leg = _limb_pivot("RightLeg", Vector3(0.18, 0.73, 0), leg_length, boot_color, 0.13)


func _limb_pivot(node_name: String, at: Vector3, length: float, color: Color,
		radius: float = 0.11) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = at
	body_root.add_child(pivot)
	_add_capsule(pivot, "Limb", radius, length, color, Vector3(0, -length * 0.5, 0))
	return pivot


func _add_dagger(parent: Node3D, blade_color: Color, hilt_color: Color, at: Vector3) -> void:
	_add_box(parent, "DaggerBlade", Vector3(0.16, 0.08, 0.64), blade_color,
		at + Vector3(0, 0.12, -0.28), true)
	_add_box(parent, "DaggerHilt", Vector3(0.34, 0.08, 0.12), hilt_color,
		at + Vector3(0, 0.12, 0.04), true)


func _add_sphere(parent: Node3D, node_name: String, radius: float, color: Color,
		at: Vector3, stretch: Vector3 = Vector3.ONE, emission: bool = false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _mesh_instance(parent, node_name, mesh, color, at, stretch, emission)


func _add_capsule(parent: Node3D, node_name: String, radius: float, height: float,
		color: Color, at: Vector3) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return _mesh_instance(parent, node_name, mesh, color, at)


func _add_cylinder(parent: Node3D, node_name: String, bottom_radius: float,
		top_radius: float, height: float, color: Color, at: Vector3,
		metallic: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	return _mesh_instance(parent, node_name, mesh, color, at, Vector3.ONE, false, metallic)


func _add_box(parent: Node3D, node_name: String, size: Vector3, color: Color,
		at: Vector3, metallic: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh_instance(parent, node_name, mesh, color, at, Vector3.ONE, false, metallic)


func _mesh_instance(parent: Node3D, node_name: String, mesh: PrimitiveMesh,
		color: Color, at: Vector3, stretch: Vector3 = Vector3.ONE,
		emission: bool = false, metallic: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.scale = stretch
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	material.metallic = 0.38 if metallic else 0.02
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.2
	instance.material_override = material
	parent.add_child(instance)
	return instance
