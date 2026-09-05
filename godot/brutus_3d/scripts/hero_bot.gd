class_name HeroBot
extends CharacterBody3D

## Lightweight 3D roster actor used by Lyra, Nix and Sol.

signal defeated(hero: HeroBot, killer_team: int)

var hero_id: StringName
var display_name := "Hero"
var team := 0
var lane_x := 0.0
var max_health := 800.0
var health := 800.0
var move_speed := 2.5
var attack_damage := 60.0
var attack_range := 2.8
var attack_interval := 0.8
var attack_timer := 0.0
var respawn_left := 0.0
var is_defeated := false
var last_damage_team := -1
var damage_multiplier := 1.0
var spawn_position := Vector3.ZERO
var objective: Node3D

var visual_model: StylizedActor3D
var nameplate: Label3D
var collision: CollisionShape3D
var health_fill: MeshInstance3D
var health_backdrop: MeshInstance3D
var facing_direction := Vector3(0, 0, -1)
var movement_map: TravessiaMap


func configure(data: Dictionary) -> void:
	hero_id = data.hero
	display_name = data.name
	team = data.team
	lane_x = data.lane_x
	max_health = data.health
	health = max_health
	move_speed = data.move_speed
	attack_damage = data.attack_damage
	attack_range = data.attack_range
	attack_interval = data.attack_interval
	spawn_position = global_position
	name = "%s_Team%d" % [display_name, team]
	add_to_group("arena_actors")
	add_to_group("hero_bots")
	add_to_group("damageable")
	collision_layer = 2
	collision_mask = 1
	_build_visual()
	_build_collision()
	_build_health_bar()
	_update_nameplate()


func get_team() -> int:
	return team


func is_targetable() -> bool:
	return not is_defeated


func take_damage(amount: float, source_team: int = -1) -> void:
	if is_defeated or amount <= 0.0:
		return
	last_damage_team = source_team
	health = maxf(0.0, health - amount)
	visual_model.trigger_hurt()
	_update_nameplate()
	_update_health_bar()
	if health <= 0.0:
		is_defeated = true
		respawn_left = 4.0
		velocity = Vector3.ZERO
		visual_model.trigger_death()
		nameplate.visible = false
		health_fill.visible = false
		health_backdrop.visible = false
		collision.set_deferred("disabled", true)
		defeated.emit(self, last_damage_team)
		_finish_death_visual()


func _physics_process(delta: float) -> void:
	if is_defeated:
		respawn_left -= delta / maxf(Engine.time_scale, 0.001)
		if respawn_left <= 0.0:
			_revive()
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	var priority_unit := _nearest_enemy_unit(4.6)
	if priority_unit != null:
		objective = priority_unit
	elif not _valid_target(objective) or not _is_structure(objective):
		objective = _choose_objective()
	if objective == null:
		velocity = Vector3.ZERO
		visual_model.update_motion(delta, facing_direction, 0.0)
		return
	var offset := objective.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > attack_range:
		var direction := offset.normalized()
		facing_direction = direction
		velocity = direction * move_speed
		var previous_position := global_position
		move_and_slide()
		_constrain_to_walkable_area(previous_position)
		visual_model.update_motion(delta, facing_direction, 1.0)
	else:
		velocity = Vector3.ZERO
		if distance > 0.01:
			facing_direction = offset.normalized()
		visual_model.face_direction(facing_direction)
		_try_attack(objective)
		visual_model.update_motion(delta, facing_direction, 0.0)


func _choose_objective() -> Node3D:
	var nearby_hero := _nearest_enemy_hero(5.5)
	if nearby_hero != null:
		return nearby_hero
	var nearby_unit := _nearest_enemy_unit(4.6)
	if nearby_unit != null:
		return nearby_unit
	var enemy_team := 1 - team
	var tower: ArenaActor
	var tower_distance := INF
	var enemy_base: ArenaActor
	for node in get_tree().get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor == null or actor.team != enemy_team or actor.is_defeated:
			continue
		if actor.actor_kind == &"tower" and absf(actor.global_position.x - lane_x) < 1.2:
			var distance := absf(actor.global_position.z - global_position.z)
			if distance < tower_distance:
				tower_distance = distance
				tower = actor
		elif actor.actor_kind == &"base":
			enemy_base = actor
	return tower if tower != null else enemy_base


func _nearest_enemy_unit(max_distance: float) -> Node3D:
	var closest: Node3D
	var closest_distance := max_distance
	for node in get_tree().get_nodes_in_group("damageable"):
		var candidate := node as Node3D
		if candidate == null or candidate == self or not _valid_target(candidate):
			continue
		var actor := candidate as ArenaActor
		if actor == null or actor.actor_kind != &"minion":
			continue
		if absf(candidate.global_position.x - lane_x) > attack_range + 0.65:
			continue
		var distance := _planar_distance(candidate)
		if distance < closest_distance:
			closest_distance = distance
			closest = candidate
	return closest


func _nearest_enemy_hero(max_distance: float) -> Node3D:
	var closest: Node3D
	var closest_distance := max_distance
	for node in get_tree().get_nodes_in_group("damageable"):
		var candidate := node as Node3D
		if candidate == null or candidate == self or not _valid_target(candidate):
			continue
		if int(candidate.call("get_team")) == team:
			continue
		if candidate is ArenaActor:
			continue
		var distance := _planar_distance(candidate)
		if distance < closest_distance:
			closest_distance = distance
			closest = candidate
	return closest


func _try_attack(target: Node3D) -> void:
	if attack_timer > 0.0 or not _valid_target(target):
		return
	if _planar_distance(target) > attack_range + 0.1:
		return
	attack_timer = attack_interval
	visual_model.trigger_attack()
	target.call("take_damage", attack_damage * damage_multiplier, team)


func _valid_target(candidate) -> bool:
	return is_instance_valid(candidate) and candidate.has_method("get_team") \
		and candidate.has_method("is_targetable") and bool(candidate.call("is_targetable")) \
		and candidate.has_method("take_damage") and int(candidate.call("get_team")) != team


func _is_structure(candidate: Node) -> bool:
	var actor := candidate as ArenaActor
	return actor != null and (actor.actor_kind == &"tower" or actor.actor_kind == &"base")


func _planar_distance(candidate: Node3D) -> float:
	return Vector2(global_position.x, global_position.z).distance_to(
		Vector2(candidate.global_position.x, candidate.global_position.z)
	)


func _revive() -> void:
	global_position = spawn_position
	health = max_health
	is_defeated = false
	last_damage_team = -1
	objective = null
	visual_model.revive()
	nameplate.visible = false
	health_fill.visible = true
	health_backdrop.visible = true
	collision.set_deferred("disabled", false)
	_update_nameplate()
	_update_health_bar()


func _finish_death_visual() -> void:
	await get_tree().create_timer(
		visual_model.death_duration(), true, false, true).timeout
	if is_defeated and is_instance_valid(visual_model):
		visual_model.visible = false


func _constrain_to_walkable_area(previous_position: Vector3) -> void:
	var desired_position := global_position
	var constrained := TravessiaDefinition.constrain_walkable_motion(
		previous_position, desired_position, _dragon_access_is_open(), 0.42)
	if not is_equal_approx(constrained.x, desired_position.x):
		velocity.x = 0.0
	if not is_equal_approx(constrained.z, desired_position.z):
		velocity.z = 0.0
	global_position = constrained


func _dragon_access_is_open() -> bool:
	if not is_instance_valid(movement_map):
		movement_map = get_tree().get_first_node_in_group(
			"travessia_map") as TravessiaMap
	return movement_map != null and movement_map.is_dragon_access_open()


func _build_visual() -> void:
	visual_model = StylizedActor3D.new()
	add_child(visual_model)
	visual_model.configure(&"hero", hero_id, team)

	nameplate = Label3D.new()
	nameplate.name = "Nameplate"
	nameplate.position.y = 3.15
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.font_size = 48
	nameplate.outline_size = 12
	nameplate.pixel_size = 0.004
	nameplate.modulate = Color("67d8ff") if team == 0 else Color("ff7181")
	nameplate.visible = false
	add_child(nameplate)


func _build_collision() -> void:
	collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.55
	collision.shape = shape
	collision.position.y = 0.78
	add_child(collision)


func _update_nameplate() -> void:
	if nameplate != null:
		# Text labels are intentionally disabled in the clean mobile HUD. The
		# display name remains available to future targeted/score interfaces.
		nameplate.text = ""


func _build_health_bar() -> void:
	health_backdrop = _add_billboard_bar("HealthBackdrop", Vector2(1.42, 0.22),
		Color(0.025, 0.045, 0.035, 0.94), Vector3(0, 3.02, 0), 1)
	health_fill = _add_billboard_bar("HealthFill", Vector2(1.28, 0.13),
		Color("4ed7ff") if team == 0 else Color("ff526b"),
		Vector3(0, 3.02, 0), 2)
	health_fill.set_meta("bar_width", 1.28)


func _add_billboard_bar(node_name: String, size: Vector2, color: Color,
		at_position: Vector3, priority: int) -> MeshInstance3D:
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
	node.position = at_position
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
