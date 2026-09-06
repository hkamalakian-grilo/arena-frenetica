class_name BrutusController
extends CharacterBody3D

signal ability_impact(kind: StringName, world_position: Vector3)
signal action_started(kind: StringName)
signal shield_returned
signal health_changed(current: float, maximum: float)
signal defeated

@export var move_speed := 3.0
@export var acceleration := 18.0
@export var braking := 24.0
@export var turn_speed := 20.0
@export var attack_lunge_speed := 4.6
@export var walk_stride_distance := 1.35
@export var run_stride_distance := 2.25
@export var max_health := 1800.0
@export var q_cooldown := 7.0
@export var q_dash_speed := 10.5
@export var r_cooldown := 35.0
@export var movement_collision_radius := 0.34
## Soft aim assist: attacks and Investida turn toward the best enemy inside
## this range/cone so touch players do not whiff by a few degrees.
@export var attack_assist_range := 2.4
@export var attack_assist_cone_degrees := 110.0
@export var q_assist_range := 6.5
@export var q_assist_cone_degrees := 70.0
## Inputs pressed during another action are kept alive for this long and fire
## as soon as the current action can be left.
@export var input_buffer_time := 0.35

const BRUTUS_SCENE := preload("res://assets/brutus/brutus.glb")
const SHIELD_SCENE := preload("res://assets/brutus/brutus_shield.glb")

var virtual_input := Vector2.ZERO
var visual_root: Node3D
var animation_player: AnimationPlayer
var shield_hand_mesh: MeshInstance3D
var speed_ratio := 0.0
var movement_input_strength := 0.0
var locomotion_animation: StringName = &""
var action_state: StringName = &""
var action_elapsed := 0.0
var attack_combo_index := 0
var attack_has_impacted := false
var attack_queued := false
var attack_direction := Vector3(0, 0, 1)
var health := 1800.0
var is_defeated := false
var last_damage_team := -1
var q_cooldown_left := 0.0
var r_cooldown_left := 0.0
var q_direction := Vector3(0, 0, 1)
var last_direction := Vector3(0, 0, 1)
var q_trail_timer := 0.0
var r_has_impacted := false
var active_effects: Array[Dictionary] = []
var shield_projectile: Node3D
var shield_projectile_age := 0.0
var shield_projectile_direction := Vector3.ZERO
var shield_projectile_start := Vector3.ZERO
var shield_projectile_target := Vector3.ZERO
var shield_projectile_reached_end := false
var shield_trail_timer := 0.0
var movement_map: TravessiaMap
var buffered_action: StringName = &""
var buffered_aim := Vector3.ZERO
var buffer_left := 0.0
var last_assist_target: Node3D
var aim_preview_kind: StringName = &""
var aim_preview_direction := Vector3(0, 0, -1)
var q_contact_done := false
var q_contact_radius := 1.15
var run_dust_distance := 0.0
var concealed := false
var reveal_left := 0.0
var team_ring_material: StandardMaterial3D


func is_concealed() -> bool:
	return concealed


func reveal(seconds := TravessiaDefinition.BUSH_REVEAL_SECONDS) -> void:
	reveal_left = maxf(reveal_left, seconds)


func _update_concealment(delta: float) -> void:
	reveal_left = maxf(0.0, reveal_left - delta)
	var in_bush := TravessiaDefinition.is_in_bush(Vector2(global_position.x, global_position.z))
	var next := in_bush and reveal_left <= 0.0 and not is_defeated
	if next == concealed:
		return
	concealed = next
	if team_ring_material != null:
		# Green ring tells the player "you are hidden"; blue when exposed.
		team_ring_material.albedo_color = Color(0.45, 1.0, 0.5, 0.9) if concealed \
			else Color(0.18, 0.78, 1.0, 0.88)
		team_ring_material.emission = Color("6cff7a") if concealed else Color("38cfff")


func _enemy_within(radius: float) -> bool:
	for node in get_tree().get_nodes_in_group("damageable"):
		var candidate := node as Node3D
		if candidate == null or candidate == self or not candidate.has_method("get_team"):
			continue
		if int(candidate.call("get_team")) == get_team():
			continue
		if candidate.has_method("is_targetable") and not bool(candidate.call("is_targetable")):
			continue
		var actor := candidate as ArenaActor
		if actor != null and (actor.actor_kind == &"tower" or actor.actor_kind == &"base"):
			continue
		if Vector2(global_position.x, global_position.z).distance_to(
				Vector2(candidate.global_position.x, candidate.global_position.z)) <= radius:
			return true
	return false


func _ready() -> void:
	health = max_health
	add_to_group("damageable")
	# Todos os atores moveis ocupam a camada 2, mas consultam apenas a camada 1
	# do mapa. Assim herois e minions se atravessam sem empurrar ou bloquear.
	collision_layer = 2
	collision_mask = 1
	_ensure_input_actions()
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	visual_root.scale = Vector3.ONE * 0.56
	add_child(visual_root)
	var model := BRUTUS_SCENE.instantiate()
	model.name = "BrutusModel"
	visual_root.add_child(model)
	_tune_model_materials(model)
	_add_team_ring()
	animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	shield_hand_mesh = model.find_child("BrutusShieldMesh", true, false) as MeshInstance3D
	assert(animation_player != null, "Brutus GLB must contain an AnimationPlayer")
	assert(shield_hand_mesh != null, "Brutus GLB must contain a detachable shield mesh")
	_set_loop(&"idle", true)
	_set_loop(&"walk", true)
	_set_loop(&"run", true)
	animation_player.animation_finished.connect(_on_animation_finished)
	_play_locomotion(&"idle", 0.0)


func _process(delta: float) -> void:
	_update_effects(delta)
	_update_shield_projectile(delta)
	_update_aim_preview()


func set_virtual_input(next_value: Vector2) -> void:
	virtual_input = next_value


func request_attack() -> void:
	if animation_player == null or is_defeated:
		return
	if _is_attack_state():
		if action_elapsed >= 0.16:
			attack_queued = true
		return
	if not _is_free_for_action():
		_buffer(&"attack")
		return
	_start_attack()


func _start_attack() -> void:
	var clip: StringName = &"attack" if attack_combo_index == 0 else &"attack_alt"
	attack_combo_index = (attack_combo_index + 1) % 2
	attack_direction = _assisted_direction(last_direction.normalized(),
		attack_assist_range, attack_assist_cone_degrees)
	attack_has_impacted = false
	_begin_action(clip)
	animation_player.play(clip, 0.05)
	action_started.emit(&"attack")


## `aim` is a manual world direction (hold-and-drag or mouse). When zero, the
## cast is a quick cast: facing direction with soft aim assist.
func request_q(aim: Vector3 = Vector3.ZERO) -> void:
	if is_defeated or q_cooldown_left > 0.0:
		return
	if not _is_free_for_action() and not _can_cancel_into_ability():
		_buffer(&"q", aim)
		return
	attack_queued = false
	q_direction = _resolve_cast_direction(aim)
	last_direction = q_direction
	q_cooldown_left = q_cooldown
	q_trail_timer = 0.0
	q_contact_done = false
	_begin_action(&"q")
	animation_player.play(&"q", 0.08)
	action_started.emit(&"q")


func request_r(aim: Vector3 = Vector3.ZERO) -> void:
	if is_defeated or r_cooldown_left > 0.0 or shield_projectile != null:
		return
	if not _is_free_for_action() and not _can_cancel_into_ability():
		_buffer(&"r", aim)
		return
	attack_queued = false
	last_direction = _resolve_cast_direction(aim)
	r_cooldown_left = r_cooldown
	r_has_impacted = false
	_begin_action(&"ultimate")
	animation_player.play(&"ultimate", 0.10)
	action_started.emit(&"r")


func _resolve_cast_direction(aim: Vector3) -> Vector3:
	var manual := Vector3(aim.x, 0.0, aim.z)
	if manual.length_squared() > 0.01:
		last_assist_target = null
		return manual.normalized()
	return _assisted_direction(last_direction.normalized(), q_assist_range, q_assist_cone_degrees)


func health_ratio() -> float:
	return health / maxf(max_health, 1.0)


func heal(amount: float) -> void:
	if is_defeated or amount <= 0.0:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


## Aim indicator state read by the HUD (AimIndicator) while the player holds
## an ability button. `kind` is &"q" (dash lane) or &"r" (shield line).
func show_aim_preview(kind: StringName, direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.001:
		flat = last_direction
	aim_preview_kind = kind
	aim_preview_direction = flat.normalized()


func hide_aim_preview() -> void:
	aim_preview_kind = &""


func is_aim_preview_visible() -> bool:
	return not aim_preview_kind.is_empty()


## Ground length and width of the indicator strip for a kind, in world units.
func aim_preview_extent(kind: StringName) -> Vector2:
	if kind == &"q":
		return Vector2(1.1, q_dash_speed * 0.5 + 0.6)
	return Vector2(0.9, 5.8)


func _update_aim_preview() -> void:
	pass


## World direction from Brutus to the mouse cursor on the ground plane, or
## zero when there is no camera / the cursor is on top of him.
func mouse_world_direction() -> Vector3:
	var viewport := get_viewport()
	if viewport == null:
		return Vector3.ZERO
	var camera := viewport.get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var mouse := viewport.get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	if absf(normal.y) < 0.0001:
		return Vector3.ZERO
	var t := -origin.y / normal.y
	if t < 0.0:
		return Vector3.ZERO
	var point := origin + normal * t
	var direction := point - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length() > 0.3 else Vector3.ZERO


func _is_free_for_action() -> bool:
	# The hurt recoil is readable but must never eat a player command.
	return action_state.is_empty() or action_state == &"hurt"


func _can_cancel_into_ability() -> bool:
	# After a basic hit has landed, Q/R may cut the recovery so combos feel
	# snappy; abilities themselves are never interrupted by another ability.
	return _is_attack_state() and attack_has_impacted


func _buffer(kind: StringName, aim: Vector3 = Vector3.ZERO) -> void:
	buffered_action = kind
	buffered_aim = aim
	buffer_left = input_buffer_time


func _flush_buffer() -> void:
	if buffered_action.is_empty():
		return
	var kind := buffered_action
	var aim := buffered_aim
	buffered_action = &""
	buffered_aim = Vector3.ZERO
	buffer_left = 0.0
	match kind:
		&"attack":
			request_attack()
		&"q":
			request_q(aim)
		&"r":
			request_r(aim)


## Returns the direction toward the best enemy within range and cone, or the
## fallback when nothing worth turning toward exists.
func _assisted_direction(fallback: Vector3, max_range: float, cone_degrees: float) -> Vector3:
	last_assist_target = null
	if fallback.length_squared() < 0.001 or not is_inside_tree():
		return fallback
	var half_cone := deg_to_rad(cone_degrees * 0.5)
	var origin := Vector2(global_position.x, global_position.z)
	var forward := Vector2(fallback.x, fallback.z).normalized()
	var best: Node3D
	var best_score := INF
	for node in get_tree().get_nodes_in_group("damageable"):
		var candidate := node as Node3D
		if candidate == null or candidate == self or not candidate.has_method("get_team"):
			continue
		if int(candidate.call("get_team")) == get_team():
			continue
		if not CombatWorld.is_valid_target(candidate, self):
			continue
		var offset := Vector2(candidate.global_position.x, candidate.global_position.z) - origin
		var distance := offset.length()
		if distance < 0.05 or distance > max_range:
			continue
		var angle := absf(forward.angle_to(offset / distance))
		if angle > half_cone:
			continue
		# Prefer close targets, then those already in front. Units beat
		# structures so a fight near a tower still aims at the fighter.
		var score := distance + angle * 1.6
		var actor := candidate as ArenaActor
		if actor != null and (actor.actor_kind == &"tower" or actor.actor_kind == &"base"):
			score += 1.5
		if score < best_score:
			best_score = score
			best = candidate
	if best == null:
		return fallback
	last_assist_target = best
	var direction := best.global_position - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.001 else fallback


func _begin_action(next_state: StringName) -> void:
	if next_state != &"hurt":
		reveal()
	action_state = next_state
	action_elapsed = 0.0
	locomotion_animation = &""
	animation_player.speed_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		request_attack()
	elif event.is_action_pressed("ability_q"):
		# Keyboard: aim at the mouse cursor like the HTML build; fall back to
		# quick cast with assist when the cursor is unavailable.
		request_q(mouse_world_direction())
	elif event.is_action_pressed("ability_r"):
		request_r(mouse_world_direction())


func _physics_process(delta: float) -> void:
	if is_defeated:
		velocity = Vector3.ZERO
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_update_concealment(delta)
	q_cooldown_left = maxf(0.0, q_cooldown_left - real_delta)
	r_cooldown_left = maxf(0.0, r_cooldown_left - real_delta)
	action_elapsed += delta if not action_state.is_empty() else 0.0
	if buffer_left > 0.0:
		buffer_left -= real_delta
		if buffer_left <= 0.0:
			buffered_action = &""
		elif _is_free_for_action() or _can_cancel_into_ability():
			_flush_buffer()

	if _is_attack_state():
		_process_attack(delta)
	elif action_state == &"q":
		_process_charge(delta)
	elif action_state == &"ultimate":
		_process_ultimate(delta)
	else:
		_process_locomotion(delta)
		if action_state == &"hurt" and action_elapsed >= 0.18 and movement_input_strength > 0.08:
			action_state = &""
			locomotion_animation = &""

	_apply_gravity(delta)
	var previous_position := global_position
	move_and_slide()
	_constrain_to_walkable_area(previous_position)
	_update_speed_ratio()
	_update_locomotion_animation()


func get_team() -> int:
	return 0


func is_targetable() -> bool:
	return not is_defeated


func take_damage(amount: float, source_team: int = -1) -> void:
	if is_defeated or amount <= 0.0:
		return
	last_damage_team = source_team
	reveal()
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		is_defeated = true
		virtual_input = Vector2.ZERO
		action_state = &""
		velocity = Vector3.ZERO
		if animation_player != null:
			animation_player.play(&"death", 0.12)
		defeated.emit()
	elif animation_player != null and action_state.is_empty():
		# A readable, short full-body recoil. Abilities keep their authored pose;
		# ordinary locomotion can be visually interrupted without stopping motion.
		_begin_action(&"hurt")
		animation_player.play(&"hurt", 0.05)


func revive(at_position: Vector3) -> void:
	global_position = at_position
	health = max_health
	is_defeated = false
	last_damage_team = -1
	attack_queued = false
	buffered_action = &""
	buffer_left = 0.0
	action_state = &""
	velocity = Vector3.ZERO
	health_changed.emit(health, max_health)
	_play_locomotion(&"idle", 0.0)


func _add_team_ring() -> void:
	var ring := MeshInstance3D.new()
	ring.name = "PlayerTeamRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.48
	mesh.outer_radius = 0.58
	mesh.rings = 32
	mesh.ring_segments = 8
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.78, 1.0, 0.88)
	material.emission_enabled = true
	material.emission = Color("38cfff")
	material.emission_energy_multiplier = 0.55
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = material
	ring.position.y = 0.055
	team_ring_material = material
	add_child(ring)


func _tune_model_materials(model: Node) -> void:
	# Cartoon look: hard lighting steps plus a dark silhouette. The model is
	# scaled by 0.56, so the outline width is given in model units.
	ToonStyle.apply(model, 0.045)
	ToonStyle.add_blob_shadow(self, 1.35)


func _process_locomotion(delta: float) -> void:
	var input_vector := _movement_vector()
	var direction := Vector3(input_vector.x, 0.0, input_vector.y)
	movement_input_strength = clampf(input_vector.length(), 0.0, 1.0)
	if direction.length_squared() > 0.001:
		last_direction = direction.normalized()
		_face_direction(last_direction, delta)

	var target_velocity := direction * move_speed
	var response := acceleration if direction.length_squared() > 0.001 else braking
	velocity.x = move_toward(velocity.x, target_velocity.x, response * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, response * delta)


func _movement_vector() -> Vector2:
	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var input_vector := virtual_input if virtual_input.length() > keyboard.length() else keyboard
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	return input_vector


func _constrain_to_walkable_area(previous_position: Vector3) -> void:
	var desired_position := global_position
	var constrained := TravessiaDefinition.constrain_walkable_motion(
		previous_position, desired_position, _dragon_access_is_open(),
		movement_collision_radius)
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


func _is_attack_state() -> bool:
	return action_state == &"attack" or action_state == &"attack_alt"


func _process_attack(delta: float) -> void:
	_face_direction(attack_direction, delta * 1.8)
	# Short planted step: enough translation to connect body and fist without
	# turning the basic attack into another dash ability.
	if action_elapsed >= 0.08 and action_elapsed <= 0.31:
		velocity.x = attack_direction.x * attack_lunge_speed
		velocity.z = attack_direction.z * attack_lunge_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, braking * 1.8 * delta)
		velocity.z = move_toward(velocity.z, 0.0, braking * 1.8 * delta)
	if action_elapsed >= 0.30 and not attack_has_impacted:
		attack_has_impacted = true
		var impact_position := global_position + attack_direction * 0.82 + Vector3(0, 0.10, 0)
		Vfx.slash(get_parent(), global_position + attack_direction * 0.55, attack_direction,
			Color(1.0, 0.78, 0.35))
		ability_impact.emit(&"attack", impact_position)
	if attack_has_impacted and not attack_queued and action_elapsed >= 0.34 and _movement_vector().length() > 0.08:
		action_state = &""
		locomotion_animation = &""
		_process_locomotion(delta)


func _process_charge(delta: float) -> void:
	_face_direction(q_direction, delta * 2.0)
	# 0.20 s de antecipação; depois Brutus atravessa cerca de 5 m atrás do escudo.
	if action_elapsed >= 0.20 and action_elapsed <= 0.70:
		velocity.x = q_direction.x * q_dash_speed
		velocity.z = q_direction.z * q_dash_speed
		# Charging through an enemy connects on contact; the shield does not
		# wait for the end of the run to knock people over.
		if not q_contact_done and _enemy_within(q_contact_radius):
			q_contact_done = true
			ability_impact.emit(&"q", global_position)
		q_trail_timer -= delta
		if q_trail_timer <= 0.0:
			q_trail_timer = 0.075
			Vfx.dust(get_parent(), global_position - q_direction * 0.3, 6, 0.34, 1.6)
			Vfx.burst(get_parent(), global_position + Vector3(0, 0.9, 0), Color(1.0, 0.55, 0.15, 0.9),
				4, 1.2, 0.14, 0.25, true, 0.0, -q_direction, 40.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, braking * 1.4 * delta)
		velocity.z = move_toward(velocity.z, 0.0, braking * 1.4 * delta)
	if action_elapsed >= 0.70 and action_elapsed - delta < 0.70:
		_spawn_ring(global_position + Vector3(0, 0.10, 0), Color(1.0, 0.72, 0.18, 0.82),
			0.45, 1.35, 0.34, 0.0)
		Vfx.dust(get_parent(), global_position, 14, 0.42, 2.4)
		Vfx.burst(get_parent(), global_position + Vector3(0, 0.6, 0), Color(1.0, 0.7, 0.25),
			18, 3.5, 0.15, 0.45)
		ability_impact.emit(&"q", global_position)


func _process_ultimate(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, braking * 1.8 * delta)
	velocity.z = move_toward(velocity.z, 0.0, braking * 1.8 * delta)
	# Solta o escudo logo após a antecipação do giro de tronco.
	if action_elapsed >= 0.58 and not r_has_impacted:
		r_has_impacted = true
		_launch_shield()
	if r_has_impacted and action_elapsed >= 0.72 and _movement_vector().length() > 0.08:
		action_state = &""
		locomotion_animation = &""
		_process_locomotion(delta)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.5


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(direction.x, direction.z)
	visual_root.rotation.y = lerp_angle(
		visual_root.rotation.y,
		target_yaw,
		1.0 - exp(-turn_speed * delta)
	)


func _update_speed_ratio() -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	speed_ratio = clamp(planar_speed / move_speed, 0.0, 1.0)
	# Small dust puffs under a running stride.
	if action_state.is_empty() and speed_ratio > 0.6 and movement_input_strength >= 0.72:
		run_dust_distance += planar_speed * get_physics_process_delta_time()
		if run_dust_distance >= 0.85:
			run_dust_distance = 0.0
			Vfx.dust(get_parent(), global_position - last_direction * 0.25, 4, 0.22, 0.8)


func _update_locomotion_animation() -> void:
	if not action_state.is_empty():
		return
	if speed_ratio > 0.08:
		if movement_input_strength >= 0.72:
			_play_locomotion(&"run", 0.13)
			_match_locomotion_to_distance(&"run", run_stride_distance)
		else:
			_play_locomotion(&"walk", 0.16)
			_match_locomotion_to_distance(&"walk", walk_stride_distance)
	else:
		_play_locomotion(&"idle", 0.20)
		animation_player.speed_scale = 1.0


func _match_locomotion_to_distance(name: StringName, stride_distance: float) -> void:
	var animation := animation_player.get_animation(name)
	if animation == null or stride_distance <= 0.0:
		animation_player.speed_scale = 1.0
		return
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	# cycles/s = metres/s / metres/cycle; speed_scale converts that cadence to
	# the authored clip length. This prevents foot skating at low analog input.
	animation_player.speed_scale = clampf(
		planar_speed * animation.length / stride_distance,
		0.32,
		1.22
	)


func _play_locomotion(name: StringName, blend_time: float) -> void:
	if locomotion_animation == name and animation_player.is_playing():
		return
	locomotion_animation = name
	animation_player.play(name, blend_time)


func _set_loop(name: StringName, enabled: bool) -> void:
	var animation := animation_player.get_animation(name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if enabled else Animation.LOOP_NONE


func _on_animation_finished(name: StringName) -> void:
	if name == action_state:
		if _is_attack_state() and attack_queued:
			attack_queued = false
			_start_attack()
			return
		action_state = &""
		locomotion_animation = &""
		_update_locomotion_animation()


func _launch_shield() -> void:
	shield_hand_mesh.visible = false
	shield_projectile = SHIELD_SCENE.instantiate()
	shield_projectile.name = "ThrownShield"
	ToonStyle.apply(shield_projectile, 0.04)
	get_parent().add_child(shield_projectile)
	Vfx.trail(shield_projectile, Color(0.85, 0.55, 1.0, 0.9), 0.18, 30)
	Vfx.flash(get_parent(), global_position + Vector3(0, 1.4, 0), Color(0.85, 0.6, 1.0, 0.9), 0.9, 0.16)
	shield_projectile_direction = last_direction.normalized()
	var left_offset := Vector3(-shield_projectile_direction.z, 0.0, shield_projectile_direction.x) * 0.72
	shield_projectile_start = global_position + Vector3(0, 1.55, 0) + left_offset
	shield_projectile_target = shield_projectile_start + shield_projectile_direction * 5.8
	shield_projectile.global_position = shield_projectile_start
	shield_projectile_age = 0.0
	shield_projectile_reached_end = false
	shield_trail_timer = 0.0


func _update_shield_projectile(delta: float) -> void:
	if shield_projectile == null:
		return
	shield_projectile_age += delta
	shield_projectile.rotation.y += delta * 22.0
	shield_projectile.rotation.z = sin(shield_projectile_age * 18.0) * 0.10
	var outbound_duration := 0.43
	var return_duration := 0.48
	if shield_projectile_age <= outbound_duration:
		var out_t := clampf(shield_projectile_age / outbound_duration, 0.0, 1.0)
		shield_projectile.global_position = shield_projectile_start.lerp(
			shield_projectile_target, ease(out_t, -0.35)
		)
	else:
		if not shield_projectile_reached_end:
			shield_projectile_reached_end = true
			_spawn_ring(shield_projectile_target - Vector3(0, 1.43, 0),
				Color(0.85, 0.55, 1.0, 0.82), 0.30, 1.25, 0.34, 0.0)
			Vfx.burst(get_parent(), shield_projectile_target, Color(0.9, 0.65, 1.0), 22, 4.0, 0.16, 0.5)
			Vfx.flash(get_parent(), shield_projectile_target, Color(1.0, 0.85, 1.0, 0.95), 1.6, 0.2)
			ability_impact.emit(&"ultimate", shield_projectile_target)
		var return_t := clampf((shield_projectile_age - outbound_duration) / return_duration, 0.0, 1.0)
		var left_offset := Vector3(-last_direction.z, 0.0, last_direction.x) * 0.72
		var return_target := global_position + Vector3(0, 1.55, 0) + left_offset
		shield_projectile.global_position = shield_projectile_target.lerp(
			return_target, ease(return_t, -0.25)
		)
		if return_t >= 1.0:
			shield_projectile.queue_free()
			shield_projectile = null
			shield_hand_mesh.visible = true
			shield_returned.emit()
			return
	shield_trail_timer -= delta
	if shield_trail_timer <= 0.0:
		shield_trail_timer = 0.07
		_spawn_ring(shield_projectile.global_position - Vector3(0, 1.45, 0),
			Color(0.8, 0.5, 1.0, 0.30), 0.16, 0.42, 0.22, 0.0)


func _spawn_ring(world_position: Vector3, color: Color, start_scale: float,
		end_scale: float, duration: float, delay: float) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.82
	mesh.outer_radius = 1.0
	mesh.rings = 32
	mesh.ring_segments = 8
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	ring.material_override = material
	ring.rotation.x = 0.0
	get_parent().add_child(ring)
	ring.global_position = world_position
	ring.scale = Vector3.ONE * start_scale
	active_effects.append({
		"node": ring,
		"material": material,
		"color": color,
		"age": 0.0,
		"duration": duration,
		"delay": delay,
		"start": start_scale,
		"end": end_scale,
	})


func _update_effects(delta: float) -> void:
	for index in range(active_effects.size() - 1, -1, -1):
		var effect := active_effects[index]
		effect["age"] += delta
		var local_age: float = effect["age"] - effect["delay"]
		var node: MeshInstance3D = effect["node"]
		if local_age < 0.0:
			node.visible = false
			continue
		node.visible = true
		var duration: float = effect["duration"]
		var t := clampf(local_age / duration, 0.0, 1.0)
		var radius: float = lerpf(effect["start"], effect["end"], ease(t, -1.6))
		node.scale = Vector3.ONE * radius
		var material: StandardMaterial3D = effect["material"]
		var next_color: Color = effect["color"]
		next_color.a *= 1.0 - t
		material.albedo_color = next_color
		if t >= 1.0:
			node.queue_free()
			active_effects.remove_at(index)


func _ensure_input_actions() -> void:
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("attack", [KEY_SPACE, KEY_ENTER])
	_add_keys("ability_q", [KEY_Q])
	_add_keys("ability_r", [KEY_R])


func _add_keys(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.15)
	for key_code in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key_code
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
