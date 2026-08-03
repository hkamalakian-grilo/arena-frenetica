class_name BrutusController
extends CharacterBody3D

signal ability_impact(kind: StringName, world_position: Vector3)
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


func _ready() -> void:
	health = max_health
	add_to_group("damageable")
	_ensure_input_actions()
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	visual_root.scale = Vector3.ONE * 0.72
	add_child(visual_root)
	var model := BRUTUS_SCENE.instantiate()
	model.name = "BrutusModel"
	visual_root.add_child(model)
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


func set_virtual_input(next_value: Vector2) -> void:
	virtual_input = next_value


func request_attack() -> void:
	if animation_player == null or is_defeated:
		return
	if _is_attack_state():
		if action_elapsed >= 0.16:
			attack_queued = true
		return
	if not action_state.is_empty():
		return
	_start_attack()


func _start_attack() -> void:
	var clip: StringName = &"attack" if attack_combo_index == 0 else &"attack_alt"
	attack_combo_index = (attack_combo_index + 1) % 2
	attack_direction = last_direction.normalized()
	attack_has_impacted = false
	_begin_action(clip)
	animation_player.play(clip, 0.05)


func request_q() -> void:
	if is_defeated or not action_state.is_empty() or q_cooldown_left > 0.0:
		return
	q_direction = last_direction.normalized()
	q_cooldown_left = q_cooldown
	q_trail_timer = 0.0
	_begin_action(&"q")
	animation_player.play(&"q", 0.08)


func request_r() -> void:
	if is_defeated or not action_state.is_empty() or r_cooldown_left > 0.0 or shield_projectile != null:
		return
	r_cooldown_left = r_cooldown
	r_has_impacted = false
	_begin_action(&"ultimate")
	animation_player.play(&"ultimate", 0.10)


func _begin_action(next_state: StringName) -> void:
	action_state = next_state
	action_elapsed = 0.0
	locomotion_animation = &""
	animation_player.speed_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		request_attack()
	elif event.is_action_pressed("ability_q"):
		request_q()
	elif event.is_action_pressed("ability_r"):
		request_r()


func _physics_process(delta: float) -> void:
	if is_defeated:
		velocity = Vector3.ZERO
		return
	q_cooldown_left = maxf(0.0, q_cooldown_left - delta)
	r_cooldown_left = maxf(0.0, r_cooldown_left - delta)
	action_elapsed += delta if not action_state.is_empty() else 0.0

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
	move_and_slide()
	_clamp_to_playable_area()
	_update_speed_ratio()
	_update_locomotion_animation()


func get_team() -> int:
	return 0


func is_targetable() -> bool:
	return not is_defeated


func take_damage(amount: float) -> void:
	if is_defeated or amount <= 0.0:
		return
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
	attack_queued = false
	action_state = &""
	velocity = Vector3.ZERO
	health_changed.emit(health, max_health)
	_play_locomotion(&"idle", 0.0)


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


func _clamp_to_playable_area() -> void:
	# Collision walls remain useful for sliding, while this hard guard also stops
	# authored lunges and dash motion from ever crossing the painted arena.
	global_position.x = clampf(global_position.x,
		-TravessiaDefinition.PLAYABLE_HALF_EXTENTS.x,
		TravessiaDefinition.PLAYABLE_HALF_EXTENTS.x)
	global_position.z = clampf(global_position.z,
		-TravessiaDefinition.PLAYABLE_HALF_EXTENTS.y,
		TravessiaDefinition.PLAYABLE_HALF_EXTENTS.y)


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
		_spawn_ring(impact_position, Color(1.0, 0.72, 0.18, 0.78), 0.24, 0.78, 0.20, 0.0)
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
		q_trail_timer -= delta
		if q_trail_timer <= 0.0:
			q_trail_timer = 0.075
			_spawn_ring(global_position + Vector3(0, 0.08, 0), Color(1.0, 0.48, 0.08, 0.48),
				0.30, 0.72, 0.32, 0.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, braking * 1.4 * delta)
		velocity.z = move_toward(velocity.z, 0.0, braking * 1.4 * delta)
	if action_elapsed >= 0.70 and action_elapsed - delta < 0.70:
		_spawn_ring(global_position + Vector3(0, 0.10, 0), Color(1.0, 0.72, 0.18, 0.82),
			0.45, 1.35, 0.34, 0.0)
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
	get_parent().add_child(shield_projectile)
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
				Color(1.0, 0.62, 0.10, 0.82), 0.30, 1.25, 0.34, 0.0)
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
			return
	shield_trail_timer -= delta
	if shield_trail_timer <= 0.0:
		shield_trail_timer = 0.07
		_spawn_ring(shield_projectile.global_position - Vector3(0, 1.45, 0),
			Color(1.0, 0.48, 0.08, 0.34), 0.16, 0.42, 0.22, 0.0)


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
