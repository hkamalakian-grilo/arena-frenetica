class_name HeroBot
extends CharacterBody3D

## Lightweight 3D roster actor used by Lyra, Nix and Sol.

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
var spawn_position := Vector3.ZERO
var objective: Node3D

var visual_model: StylizedActor3D
var nameplate: Label3D
var collision: CollisionShape3D
var facing_direction := Vector3(0, 0, -1)


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
	_update_nameplate()


func get_team() -> int:
	return team


func is_targetable() -> bool:
	return not is_defeated


func take_damage(amount: float) -> void:
	if is_defeated or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	visual_model.trigger_hurt()
	_update_nameplate()
	if health <= 0.0:
		is_defeated = true
		respawn_left = 4.0
		velocity = Vector3.ZERO
		visual_model.visible = false
		nameplate.visible = false
		collision.set_deferred("disabled", true)


func _physics_process(delta: float) -> void:
	if is_defeated:
		respawn_left -= delta
		if respawn_left <= 0.0:
			_revive()
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	if not _valid_target(objective):
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
		move_and_slide()
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
	target.call("take_damage", attack_damage)


func _valid_target(candidate) -> bool:
	return is_instance_valid(candidate) and candidate.has_method("get_team") \
		and candidate.has_method("is_targetable") and bool(candidate.call("is_targetable")) \
		and candidate.has_method("take_damage") and int(candidate.call("get_team")) != team


func _planar_distance(candidate: Node3D) -> float:
	return Vector2(global_position.x, global_position.z).distance_to(
		Vector2(candidate.global_position.x, candidate.global_position.z)
	)


func _revive() -> void:
	global_position = spawn_position
	health = max_health
	is_defeated = false
	objective = null
	visual_model.visible = true
	nameplate.visible = false
	collision.set_deferred("disabled", false)
	_update_nameplate()


func _build_visual() -> void:
	visual_model = StylizedActor3D.new()
	add_child(visual_model)
	visual_model.configure(&"hero", hero_id, team)

	nameplate = Label3D.new()
	nameplate.name = "Nameplate"
	nameplate.position.y = 2.55
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
