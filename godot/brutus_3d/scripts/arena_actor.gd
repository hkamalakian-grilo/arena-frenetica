class_name ArenaActor
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal defeated(actor: ArenaActor)

var actor_kind: StringName = &"minion"
var team := 0
var max_health := 100.0
var health := 100.0
var move_speed := 0.0
var attack_damage := 0.0
var attack_range := 1.0
var attack_interval := 1.0
var lane_x := 0.0
var is_defeated := false
var is_protected := false
var attack_timer := 0.0
var objective: Node3D

var health_fill: MeshInstance3D
var health_backdrop: MeshInstance3D
var actor_art: Sprite3D
var actor_model: StylizedActor3D
var body_color := Color.WHITE


func configure(data: Dictionary) -> void:
	actor_kind = data.get("kind", &"minion")
	team = data.get("team", 0)
	max_health = data.get("health", 100.0)
	health = max_health
	move_speed = data.get("move_speed", 0.0)
	attack_damage = data.get("attack_damage", 0.0)
	attack_range = data.get("attack_range", 1.0)
	attack_interval = data.get("attack_interval", 1.0)
	lane_x = data.get("lane_x", global_position.x)
	body_color = data.get("color", Color.WHITE)
	name = "%s_Team%d" % [String(actor_kind).capitalize(), team]
	add_to_group("arena_actors")
	add_to_group("damageable")
	collision_layer = 2
	collision_mask = 1
	_build_visual()
	_build_collision()


func get_team() -> int:
	return team


func is_targetable() -> bool:
	return not is_defeated


func take_damage(amount: float) -> void:
	if is_defeated or is_protected or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	if actor_model != null:
		actor_model.trigger_hurt()
	_flash_damage()
	_update_health_bar()
	health_changed.emit(health, max_health)
	if health <= 0.0:
		is_defeated = true
		velocity = Vector3.ZERO
		defeated.emit(self)
		queue_free()


func set_protected(value: bool) -> void:
	is_protected = value
	if actor_art != null:
		actor_art.modulate = Color(0.72, 0.78, 0.86, 1.0) if value else Color.WHITE


func get_is_protected() -> bool:
	return is_protected


func _physics_process(delta: float) -> void:
	if is_defeated:
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	if actor_kind == &"minion":
		_process_minion()
		actor_model.update_motion(delta, velocity.normalized(),
			clampf(velocity.length() / maxf(move_speed, 0.01), 0.0, 1.0))
	elif actor_kind == &"tower" or actor_kind == &"dragon":
		_process_guardian()


func _process_minion() -> void:
	if not _valid_target(objective) or not _is_structure(objective):
		objective = _find_lane_objective()
	if objective == null:
		velocity = Vector3.ZERO
		return
	var z_distance := objective.global_position.z - global_position.z
	if absf(z_distance) > attack_range:
		# Canonical lane rule: no chasing, curves or lateral combat movement.
		global_position.x = lane_x
		velocity = Vector3(0.0, 0.0, signf(z_distance) * move_speed)
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		_try_attack(objective)


func _process_guardian() -> void:
	if not _valid_target(objective) or _planar_distance(objective) > attack_range:
		objective = _find_nearest_enemy(attack_range)
	if objective != null:
		_try_attack(objective)


func _try_attack(target: Node3D) -> void:
	if attack_damage <= 0.0 or attack_timer > 0.0 or not _valid_target(target):
		return
	var target_actor := target as ArenaActor
	var target_distance := _planar_distance(target)
	if actor_kind == &"minion" and target_actor != null and target_actor.actor_kind == &"base":
		# Bases span the two lane exits visually; minions keep their straight X
		# coordinate and connect when they reach the base's Z line.
		target_distance = absf(target.global_position.z - global_position.z)
	if target_distance > attack_range + 0.1:
		return
	attack_timer = attack_interval
	if actor_model != null:
		actor_model.trigger_attack()
	if actor_kind == &"tower":
		_launch_tower_projectile(target)
	else:
		target.call("take_damage", attack_damage)


func _launch_tower_projectile(target: Node3D) -> void:
	var projectile := MeshInstance3D.new()
	projectile.name = "TowerProjectile"
	var mesh := SphereMesh.new()
	mesh.radius = 0.13
	mesh.height = 0.26
	projectile.mesh = mesh
	var color := Color("56cfff") if team == 0 else Color("ff4c5c")
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.8
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	projectile.material_override = material
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3(0, 2.45, 0)
	var target_position := target.global_position + Vector3(0, 0.75, 0)
	var tween := projectile.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(projectile, "global_position", target_position, 0.28)
	await tween.finished
	if _valid_target(target):
		target.call("take_damage", attack_damage)
	if is_instance_valid(projectile):
		projectile.queue_free()


func _find_lane_objective() -> Node3D:
	var enemy_team := 1 - team
	var closest_tower: ArenaActor
	var closest_tower_distance := INF
	var enemy_base: ArenaActor
	for node in get_tree().get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor == null or actor.is_defeated or actor.team != enemy_team:
			continue
		if actor.actor_kind == &"tower" and absf(actor.global_position.x - lane_x) < 1.2:
			var distance := absf(actor.global_position.z - global_position.z)
			if distance < closest_tower_distance:
				closest_tower_distance = distance
				closest_tower = actor
		elif actor.actor_kind == &"base":
			enemy_base = actor
	return closest_tower if closest_tower != null else enemy_base


func _find_nearest_enemy(max_distance: float) -> Node3D:
	var closest: Node3D
	var closest_distance := max_distance
	for node in get_tree().get_nodes_in_group("damageable"):
		var candidate := node as Node3D
		if candidate == null or candidate == self or not _valid_target(candidate):
			continue
		var candidate_team := int(candidate.call("get_team"))
		if candidate_team == team:
			continue
		# Lane structures do not aggro the neutral dragon. The dragon can attack
		# either team when they enter its pit.
		if actor_kind == &"tower" and candidate_team == 2:
			continue
		var distance := _planar_distance(candidate)
		if distance < closest_distance:
			closest_distance = distance
			closest = candidate
	return closest


func _valid_target(candidate) -> bool:
	# A referência pode continuar armazenada por um frame depois de queue_free().
	# Um parâmetro tipado rejeita o objeto liberado antes mesmo de esta guarda rodar.
	return is_instance_valid(candidate) and candidate.has_method("is_targetable") \
		and bool(candidate.call("is_targetable")) and candidate.has_method("take_damage")


func _is_structure(candidate: Node) -> bool:
	var actor := candidate as ArenaActor
	return actor != null and (actor.actor_kind == &"tower" or actor.actor_kind == &"base")


func _planar_distance(candidate: Node3D) -> float:
	return Vector2(global_position.x, global_position.z).distance_to(
		Vector2(candidate.global_position.x, candidate.global_position.z)
	)


func _build_visual() -> void:
	if actor_kind == &"minion":
		actor_model = StylizedActor3D.new()
		add_child(actor_model)
		actor_model.configure(&"minion", &"soldier", team)
	elif actor_kind == &"tower":
		_add_art_sprite("res://assets/structures/tower_crystal_blue_v1.png" if team == 0 \
			else "res://assets/structures/tower_crystal_red_v1.png", 0.0032, 1.08)
	elif actor_kind == &"base":
		_add_ground_shadow(3.45)
		_add_art_sprite("res://assets/structures/main_tower_core_blue_v2.png" if team == 0 \
			else "res://assets/structures/main_tower_core_red_v2.png", 0.0043, 1.68)
	elif actor_kind == &"dragon":
		_add_art_sprite("res://assets/dragon/dragon_purple_v2.png", 0.0030, 1.55)
	_build_health_bar()


func _add_art_sprite(texture_path: String, pixel_size: float, y_position: float) -> Sprite3D:
	var art := Sprite3D.new()
	art.name = "ActorArt"
	art.texture = load(texture_path) as Texture2D
	art.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	art.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	art.pixel_size = pixel_size
	art.position.y = y_position
	add_child(art)
	actor_art = art
	return art


func _add_ground_shadow(size: float) -> void:
	var shadow := MeshInstance3D.new()
	shadow.name = "GroundContactShadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	shadow.mesh = plane
	shadow.position.y = 0.035
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float alpha = (1.0 - smoothstep(0.08, 1.0, dot(centered, centered))) * 0.17;
	ALBEDO = vec3(0.10, 0.065, 0.025);
	ALPHA = alpha;
}
"""
	material.shader = shader
	shadow.material_override = material
	add_child(shadow)


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	if actor_kind == &"minion":
		shape.radius = 0.32
		shape.height = 0.92
		collision.position.y = 0.46
	elif actor_kind == &"dragon":
		shape.radius = 0.92
		shape.height = 2.15
		collision.position.y = 1.08
	else:
		shape.radius = 0.78 if actor_kind == &"tower" else 1.45
		shape.height = 1.8 if actor_kind == &"tower" else 2.8
		collision.position.y = shape.height * 0.5
	collision.shape = shape
	add_child(collision)


func _build_health_bar() -> void:
	var width := 1.05 if actor_kind == &"minion" else 2.05
	var height := 1.35 if actor_kind == &"minion" else 3.35
	if actor_kind == &"base":
		width = 2.75
		height = 4.15
	if actor_kind == &"dragon":
		width = 3.0
		height = 3.25
	health_backdrop = _add_billboard_bar("HealthBackdrop", Vector2(width + 0.16, 0.24),
		Color(0.035, 0.055, 0.045, 0.94), Vector3(0, height, 0), 1)
	health_fill = _add_billboard_bar("HealthFill", Vector2(width, 0.14),
		_team_health_color(), Vector3(0, height, 0), 2)
	health_fill.set_meta("bar_width", width)


func _add_billboard_bar(node_name: String, size: Vector2, color: Color,
		position: Vector3, priority: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := QuadMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.render_priority = priority
	node.material_override = material
	node.position = position
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _update_health_bar() -> void:
	if health_fill == null:
		return
	var ratio := clampf(health / max_health, 0.0, 1.0)
	var width := float(health_fill.get_meta("bar_width"))
	health_fill.scale.x = ratio
	health_fill.position.x = -(1.0 - ratio) * width * 0.5


func _flash_damage() -> void:
	if actor_art == null or is_defeated:
		return
	actor_art.modulate = Color(1.0, 0.45, 0.38, 1.0)
	var tween := actor_art.create_tween()
	tween.tween_property(actor_art, "modulate",
		Color(0.72, 0.78, 0.86, 1.0) if is_protected else Color.WHITE, 0.16)


func _team_health_color() -> Color:
	if team == 0:
		return Color("4ed7ff")
	if team == 1:
		return Color("ff526b")
	return Color("f6b84a")


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.68
	return material


func _add_box(node_name: String, size: Vector3, color: Color, position: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = position
	add_child(node)
	return node


func _add_cylinder(node_name: String, radius: float, height: float, color: Color,
		position: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.84
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = position
	add_child(node)
	return node


func _add_capsule(node_name: String, radius: float, height: float, color: Color,
		position: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = position
	add_child(node)
	return node
