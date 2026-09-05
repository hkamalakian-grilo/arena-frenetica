class_name ArenaActor
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal defeated(actor: ArenaActor)

const MINION_UNIT_AGGRO_RANGE := 4.5
## Allied minions keep this much lane distance so a wave forms a column
## instead of one stacked pile that hits a single enemy four times at once.
const MINION_COLUMN_SPACING := 0.62
## Melee minion hits land after a short swing so simultaneous trades resolve
## fairly regardless of scene-tree processing order.
const MINION_HIT_DELAY := 0.28
const DRAGON_3D_SCENE := preload("res://assets/dragon/dragon_3d.glb")
const DRAGON_EGG_3D_SCENE := preload("res://assets/dragon/dragon_egg_3d.glb")

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
var last_damage_team := -1
var attack_timer := 0.0
var objective: Node3D
var stun_left := 0.0
var slow_left := 0.0
var slow_factor := 1.0
var stun_marker: MeshInstance3D
var is_reinforced := false

var health_fill: MeshInstance3D
var health_backdrop: MeshInstance3D
var actor_art: Sprite3D
var actor_model: StylizedActor3D
var egg_root: Node3D
var creature_model: Node3D
var creature_animation: AnimationPlayer
var protection_ring: MeshInstance3D
var egg_time := 0.0
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
	is_reinforced = data.get("reinforced", false)
	name = "%s_Team%d" % [String(actor_kind).capitalize(), team]
	add_to_group("arena_actors")
	if actor_kind != &"dragon_egg":
		add_to_group("damageable")
	collision_layer = 2
	collision_mask = 1
	_build_visual()
	_build_collision()
	if is_reinforced and actor_model != null:
		actor_model.model_root.scale *= 1.18


func health_ratio() -> float:
	return health / maxf(max_health, 1.0)


func heal(amount: float) -> void:
	if is_defeated or amount <= 0.0 or actor_kind == &"dragon_egg":
		return
	health = minf(max_health, health + amount)
	_update_health_bar()
	health_changed.emit(health, max_health)


func get_team() -> int:
	return team


func is_targetable() -> bool:
	return not is_defeated and actor_kind != &"dragon_egg"


func take_damage(amount: float, source_team: int = -1) -> void:
	if is_defeated or is_protected or actor_kind == &"dragon_egg" or amount <= 0.0:
		return
	last_damage_team = source_team
	health = maxf(0.0, health - amount)
	if health > 0.0:
		if actor_model != null:
			actor_model.trigger_hurt()
		elif actor_kind == &"dragon":
			_play_creature_animation(&"hurt")
	_flash_damage()
	_update_health_bar()
	health_changed.emit(health, max_health)
	if health <= 0.0:
		is_defeated = true
		velocity = Vector3.ZERO
		collision_layer = 0
		collision_mask = 0
		defeated.emit(self)
		if actor_kind == &"dragon":
			if health_fill != null:
				health_fill.visible = false
			if health_backdrop != null:
				health_backdrop.visible = false
			_play_creature_animation(&"death", 0.06, 2.0)
			_finish_dragon_death()
		elif actor_kind == &"minion" and actor_model != null:
			if health_fill != null:
				health_fill.visible = false
			if health_backdrop != null:
				health_backdrop.visible = false
			actor_model.trigger_death()
			_finish_minion_death()
		else:
			queue_free()


## Crowd control from Brutus. Structures ignore it; the dragon only briefly.
func apply_stun(seconds: float) -> void:
	if is_defeated or actor_kind == &"tower" or actor_kind == &"base" \
			or actor_kind == &"dragon_egg":
		return
	if actor_kind == &"dragon":
		seconds *= 0.4
	stun_left = maxf(stun_left, seconds)
	_set_stun_marker(true)


func apply_slow(factor: float, seconds: float) -> void:
	if is_defeated or actor_kind != &"minion" and actor_kind != &"dragon":
		return
	slow_factor = minf(slow_factor if slow_left > 0.0 else 1.0, factor)
	slow_left = maxf(slow_left, seconds)


func is_stunned() -> bool:
	return stun_left > 0.0


func _tick_crowd_control(delta: float) -> void:
	if stun_left > 0.0:
		stun_left = maxf(0.0, stun_left - delta)
		if stun_left <= 0.0:
			_set_stun_marker(false)
	if slow_left > 0.0:
		slow_left = maxf(0.0, slow_left - delta)
		if slow_left <= 0.0:
			slow_factor = 1.0


func _current_move_speed() -> float:
	return move_speed * (slow_factor if slow_left > 0.0 else 1.0)


func _set_stun_marker(visible_now: bool) -> void:
	if stun_marker == null:
		if not visible_now:
			return
		stun_marker = MeshInstance3D.new()
		stun_marker.name = "StunMarker"
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.22
		mesh.outer_radius = 0.30
		mesh.rings = 20
		mesh.ring_segments = 6
		stun_marker.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.86, 0.25, 0.95)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.8, 0.2)
		material.emission_energy_multiplier = 1.2
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		stun_marker.material_override = material
		stun_marker.position.y = 1.55 if actor_kind == &"minion" else 3.2
		add_child(stun_marker)
	stun_marker.visible = visible_now


func set_protected(value: bool) -> void:
	is_protected = value
	if actor_art != null:
		actor_art.modulate = Color(0.72, 0.78, 0.86, 1.0) if value else Color.WHITE
	if protection_ring != null:
		protection_ring.visible = value


func get_is_protected() -> bool:
	return is_protected


func _physics_process(delta: float) -> void:
	if is_defeated:
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	_tick_crowd_control(delta)
	if stun_left > 0.0:
		velocity = Vector3.ZERO
		if stun_marker != null:
			stun_marker.rotation.y += delta * 9.0
		if actor_model != null:
			actor_model.update_motion(delta, Vector3.ZERO, 0.0)
		return
	if actor_kind == &"minion":
		_process_minion()
		actor_model.update_motion(delta, velocity.normalized(),
			clampf(velocity.length() / maxf(move_speed, 0.01), 0.0, 1.0))
	elif actor_kind == &"tower" or actor_kind == &"dragon":
		_process_guardian()


func _process_minion() -> void:
	# Unidades inimigas proximas sempre interrompem o foco na estrutura. Como o
	# minion nao sai do eixo da lane, so escolhemos alvos que ele consegue atingir.
	var nearby_unit := _find_nearest_enemy_unit(MINION_UNIT_AGGRO_RANGE)
	if nearby_unit != null:
		objective = nearby_unit
	elif not _valid_target(objective) or not _is_structure(objective):
		objective = _find_lane_objective()
	if objective == null:
		velocity = Vector3.ZERO
		return
	var z_distance := objective.global_position.z - global_position.z
	if absf(z_distance) > attack_range:
		# Canonical lane rule: no chasing, curves or lateral combat movement.
		global_position.x = lane_x
		var advance := signf(z_distance)
		if _ally_blocking_column(advance):
			velocity = Vector3.ZERO
			return
		velocity = Vector3(0.0, 0.0, advance * _current_move_speed())
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		_try_attack(objective)


## True when an allied minion of this lane stands just ahead in the direction
## of travel. The follower waits, so the wave advances as a column.
func _ally_blocking_column(advance: float) -> bool:
	for node in get_tree().get_nodes_in_group("arena_actors"):
		var ally := node as ArenaActor
		if ally == null or ally == self or ally.is_defeated or ally.team != team \
				or ally.actor_kind != &"minion" or absf(ally.lane_x - lane_x) > 0.1:
			continue
		var gap := (ally.global_position.z - global_position.z) * advance
		if gap > 0.0 and gap < MINION_COLUMN_SPACING:
			return true
	return false


func _process_guardian() -> void:
	if not _valid_target(objective) or _planar_distance(objective) > attack_range:
		objective = null
	if actor_kind == &"tower":
		# Classic tower aggro: minions absorb the fire first, so a hero can
		# push with a wave; once the wave is gone, the hero takes the shots.
		var current := objective as ArenaActor
		if current == null or current.actor_kind != &"minion":
			var minion := _find_nearest_enemy_minion(attack_range)
			if minion != null:
				objective = minion
	if objective == null:
		objective = _find_nearest_enemy(attack_range)
	if objective != null:
		_try_attack(objective)


func _find_nearest_enemy_minion(max_distance: float) -> Node3D:
	var closest: Node3D
	var closest_distance := max_distance
	for node in get_tree().get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor == null or actor == self or actor.actor_kind != &"minion" \
				or actor.team == team or not _valid_target(actor):
			continue
		var distance := _planar_distance(actor)
		if distance < closest_distance:
			closest_distance = distance
			closest = actor
	return closest


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
	elif actor_kind == &"dragon":
		_play_creature_animation(&"attack")
	if actor_kind == &"tower":
		get_tree().call_group("arena_sfx", "play", &"tower_shot", -8.0, 0.08)
		_launch_tower_projectile(target)
	elif actor_kind == &"minion":
		_schedule_melee_hit(target, attack_damage, team)
	else:
		target.call("take_damage", attack_damage, team)


## The hit resolves after the swing even if this minion dies meanwhile, so two
## minions trading blows both connect instead of the first-processed winning.
func _schedule_melee_hit(target: Node3D, amount: float, source_team: int) -> void:
	var timer := get_tree().create_timer(MINION_HIT_DELAY, false)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(target) and target.has_method("is_targetable") \
				and bool(target.call("is_targetable")):
			target.call("take_damage", amount, source_team))


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
		target.call("take_damage", attack_damage, team)
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


func _find_nearest_enemy_unit(max_distance: float) -> Node3D:
	var closest: Node3D
	var closest_distance := max_distance
	for node in get_tree().get_nodes_in_group("damageable"):
		var candidate := node as Node3D
		if candidate == null or candidate == self or not _valid_target(candidate):
			continue
		if int(candidate.call("get_team")) != 1 - team or _is_structure(candidate):
			continue
		var candidate_actor := candidate as ArenaActor
		if candidate_actor != null and candidate_actor.actor_kind != &"minion":
			continue
		# O deslocamento continua reto. Alvos fora desta largura pertencem a
		# outra lane ou exigiriam que o minion perseguisse lateralmente.
		if absf(candidate.global_position.x - lane_x) > attack_range + 0.05:
			continue
		var distance := _planar_distance(candidate)
		if distance < closest_distance:
			closest_distance = distance
			closest = candidate
	return closest


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
			else "res://assets/structures/tower_crystal_red_v1.png", 0.00355, 1.24)
	elif actor_kind == &"base":
		# A fortaleza ocupa o circulo completo, como as torres laterais. O mapa
		# pintado tem perspectiva assimetrica, portanto cada extremidade usa seu
		# proprio pivo visual sem mover o marcador ou a colisao de gameplay.
		_add_ground_shadow(3.55)
		var main_tower_art_y := 1.62 if team == 0 else 1.45
		_add_art_sprite("res://assets/structures/main_tower_core_blue_v2.png" if team == 0 \
			else "res://assets/structures/main_tower_core_red_v2.png", 0.0047,
			main_tower_art_y)
	elif actor_kind == &"dragon":
		_build_dragon_3d()
	elif actor_kind == &"dragon_egg":
		_build_dragon_egg()
	if actor_kind != &"dragon_egg":
		_build_health_bar()
	if actor_kind == &"base":
		_build_protection_ring()


func _build_protection_ring() -> void:
	protection_ring = MeshInstance3D.new()
	protection_ring.name = "ProtectionRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.62
	mesh.outer_radius = 1.78
	mesh.rings = 48
	mesh.ring_segments = 10
	protection_ring.mesh = mesh
	var color := Color("4ed7ff") if team == 0 else Color("ff6076")
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.76)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.65
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	protection_ring.material_override = material
	protection_ring.position.y = 0.08
	protection_ring.visible = false
	add_child(protection_ring)


func _build_dragon_egg() -> void:
	egg_root = Node3D.new()
	egg_root.name = "DragonEggVisual"
	add_child(egg_root)
	_add_ground_shadow(2.30)
	creature_model = DRAGON_EGG_3D_SCENE.instantiate()
	creature_model.name = "DragonEgg3D"
	creature_model.scale = Vector3.ONE * 1.28
	egg_root.add_child(creature_model)
	_configure_creature_animation()
	_play_creature_animation(&"idle")


func _build_dragon_3d() -> void:
	_add_ground_shadow(2.75)
	creature_model = DRAGON_3D_SCENE.instantiate()
	creature_model.name = "Dragon3D"
	creature_model.scale = Vector3.ONE * 0.74
	add_child(creature_model)
	_configure_creature_animation()
	_play_creature_animation(&"idle")


func _configure_creature_animation() -> void:
	ToonStyle.apply(creature_model, 0.04)
	creature_animation = creature_model.find_child(
		"AnimationPlayer", true, false) as AnimationPlayer
	if creature_animation == null:
		return
	if creature_animation.has_animation(&"idle"):
		creature_animation.get_animation(&"idle").loop_mode = Animation.LOOP_LINEAR
	if not creature_animation.animation_finished.is_connected(
		_on_creature_animation_finished):
		creature_animation.animation_finished.connect(_on_creature_animation_finished)


func _play_creature_animation(clip_name: StringName, blend := 0.08,
		speed_scale := 1.0) -> void:
	if creature_animation != null and creature_animation.has_animation(clip_name):
		creature_animation.speed_scale = speed_scale
		creature_animation.play(clip_name, blend)


func _on_creature_animation_finished(clip_name: StringName) -> void:
	if clip_name != &"death" and clip_name != &"hatch" and not is_defeated:
		_play_creature_animation(&"idle", 0.12)


func play_hatch() -> void:
	if actor_kind == &"dragon_egg":
		# The match runs at 50% pace, but the event needs to finish before the
		# dragon replaces the egg 0.86 real second later.
		_play_creature_animation(&"hatch", 0.04, 4.0)


func play_spawn() -> void:
	if actor_kind == &"dragon":
		_play_creature_animation(&"roar", 0.06, 2.0)


func _finish_dragon_death() -> void:
	var duration := 1.4
	if creature_animation != null and creature_animation.has_animation(&"death"):
		duration = creature_animation.get_animation(&"death").length
	await get_tree().create_timer(duration, true, false, true).timeout
	if is_instance_valid(self):
		queue_free()


func _finish_minion_death() -> void:
	await get_tree().create_timer(
		actor_model.death_duration(), true, false, true).timeout
	if is_instance_valid(self):
		queue_free()


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
	elif actor_kind == &"dragon_egg":
		shape.radius = 0.58
		shape.height = 1.75
		collision.position.y = 0.88
	else:
		shape.radius = 0.78 if actor_kind == &"tower" else 1.45
		shape.height = 1.8 if actor_kind == &"tower" else 2.8
		collision.position.y = shape.height * 0.5
	collision.shape = shape
	add_child(collision)


func _build_health_bar() -> void:
	var width := 0.92 if actor_kind == &"minion" else 2.05
	var height := 1.62 if actor_kind == &"minion" else 3.35
	if actor_kind == &"minion":
		height = 2.08
	if actor_kind == &"base":
		width = 2.75
		height = 4.45
	if actor_kind == &"dragon":
		width = 3.0
		height = 3.85
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
