class_name HeroBot
extends CharacterBody3D

## Roster hero controlled by AI (Lyra, Nix, Sol). Owns its Q/R kit, a small
## decision layer (fight, retreat, dragon, lane) and waypoint navigation.

signal defeated(hero: HeroBot, killer_team: int)
signal ability_cast(hero: HeroBot, slot: StringName)

const ROUTE_REFRESH := 0.5
const ROUTE_REACH := 0.35
const HERO_SIGHT := 5.5
const UNIT_SIGHT := 4.6
const LANE_EMPTY_SIGHT := 7.0
const TOWER_HOLD_MARGIN := 0.7

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
var ranged := false
var projectile_speed := 9.0

var kit: Dictionary = {}
var q_cooldown_left := 0.0
var r_cooldown_left := 0.0
var empower_left := 0.0
var empower_bonus := 0.0
var haste_left := 0.0
var haste_pct := 0.0
var stun_left := 0.0
var slow_left := 0.0
var slow_factor := 1.0
var stun_marker: MeshInstance3D

var mode: StringName = &"lane"
var lane_idle_time := 0.0
var route: Array = []
var route_goal := Vector2.INF
var route_timer := 0.0
var dash_target: Node3D
var dash_time_left := 0.0
var dash_damage := 0.0
var dash_execute_pct := 0.0
var rules := TravessiaDefinition.match_rules()
var kills := 0
var deaths := 0
var damage_dealt := 0.0

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
	ranged = data.get("ranged", false)
	projectile_speed = data.get("projectile_speed", 9.0)
	kit = TravessiaDefinition.hero_kits().get(hero_id, {})
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


func health_ratio() -> float:
	return health / maxf(max_health, 1.0)


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
		deaths += 1
		respawn_left = 4.0
		velocity = Vector3.ZERO
		dash_target = null
		visual_model.trigger_death()
		nameplate.visible = false
		health_fill.visible = false
		health_backdrop.visible = false
		collision.set_deferred("disabled", true)
		_set_stun_marker(false)
		if get_parent() != null:
			Vfx.burst(get_parent(), global_position + Vector3(0, 1.0, 0),
				CombatWorld.team_color(team), 24, 3.5, 0.18, 0.6)
			Vfx.dust(get_parent(), global_position, 12, 0.4, 1.4)
		defeated.emit(self, last_damage_team)
		_finish_death_visual()


func heal(amount: float) -> void:
	if is_defeated or amount <= 0.0:
		return
	health = minf(max_health, health + amount)
	_update_health_bar()


func apply_stun(seconds: float) -> void:
	if is_defeated:
		return
	stun_left = maxf(stun_left, seconds)
	dash_target = null
	_set_stun_marker(true)


func apply_slow(factor: float, seconds: float) -> void:
	if is_defeated:
		return
	slow_factor = minf(slow_factor if slow_left > 0.0 else 1.0, factor)
	slow_left = maxf(slow_left, seconds)


func apply_haste(pct: float, seconds: float) -> void:
	if is_defeated:
		return
	haste_pct = maxf(haste_pct if haste_left > 0.0 else 0.0, pct)
	haste_left = maxf(haste_left, seconds)


func is_stunned() -> bool:
	return stun_left > 0.0


func _current_move_speed() -> float:
	return move_speed * (slow_factor if slow_left > 0.0 else 1.0)


func _current_attack_interval() -> float:
	return attack_interval / (1.0 + (haste_pct if haste_left > 0.0 else 0.0))


func _set_stun_marker(visible_now: bool) -> void:
	if stun_marker == null:
		if not visible_now:
			return
		stun_marker = MeshInstance3D.new()
		stun_marker.name = "StunMarker"
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.24
		mesh.outer_radius = 0.33
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
		stun_marker.position.y = 2.55
		add_child(stun_marker)
	stun_marker.visible = visible_now


func _physics_process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if is_defeated:
		respawn_left -= real_delta
		if respawn_left <= 0.0:
			_revive()
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	q_cooldown_left = maxf(0.0, q_cooldown_left - real_delta)
	r_cooldown_left = maxf(0.0, r_cooldown_left - real_delta)
	empower_left = maxf(0.0, empower_left - delta)
	if haste_left > 0.0:
		haste_left = maxf(0.0, haste_left - delta)
	if slow_left > 0.0:
		slow_left = maxf(0.0, slow_left - delta)
		if slow_left <= 0.0:
			slow_factor = 1.0
	if stun_left > 0.0:
		stun_left = maxf(0.0, stun_left - delta)
		if stun_left <= 0.0:
			_set_stun_marker(false)
		else:
			velocity = Vector3.ZERO
			stun_marker.rotation.y += delta * 9.0
			visual_model.update_motion(delta, facing_direction, 0.0)
			return
	_apply_fountain(delta)
	if dash_target != null:
		_process_dash(delta)
		return
	_decide(delta)
	if objective == null:
		velocity = Vector3.ZERO
		visual_model.update_motion(delta, facing_direction, 0.0)
		return
	if mode == &"retreat":
		_move_toward_point(_spawn_point(), delta)
		return
	var goal := _goal_point_for(objective)
	var distance := CombatWorld.planar_to(self, Vector3(goal.x, 0.0, goal.y))
	var wants_range := attack_range if _is_attackable(objective) else 0.6
	if distance > wants_range:
		_move_toward_point(goal, delta)
		return
	velocity = Vector3.ZERO
	var offset := objective.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() > 0.001:
		facing_direction = offset.normalized()
	visual_model.face_direction(facing_direction)
	if _is_attackable(objective):
		if not _try_cast(objective):
			_try_attack(objective)
	visual_model.update_motion(delta, facing_direction, 0.0)


# ---------------------------------------------------------------------------
# Decision layer
# ---------------------------------------------------------------------------

func _decide(delta: float) -> void:
	var ratio := health_ratio()
	if mode == &"retreat":
		if ratio >= float(rules.bot_retreat_exit_hp_pct):
			mode = &"lane"
		else:
			objective = self
			return
	elif ratio < float(rules.bot_retreat_hp_pct):
		mode = &"retreat"
		objective = self
		route = []
		return
	var previous := objective
	objective = _choose_objective(delta)
	if objective != previous:
		route = []


func _choose_objective(delta: float) -> Node3D:
	# A tower that is almost down is worth more than anything else on the map:
	# below 25% it beats even a duel, below 45% it beats farming minions.
	var weak_tower := _weak_enemy_tower(0.45)
	var can_finish := weak_tower != null \
		and health_ratio() >= float(rules.bot_dive_min_hp_pct) * 0.75
	if can_finish and weak_tower.health_ratio() < 0.25:
		return _commit_to_tower(weak_tower)
	var enemy_hero := _nearest_enemy_hero(HERO_SIGHT)
	if enemy_hero != null and not _is_tower_dive(enemy_hero):
		lane_idle_time = 0.0
		mode = &"fight"
		return enemy_hero
	if can_finish:
		return _commit_to_tower(weak_tower)
	var unit := _nearest_enemy_unit(UNIT_SIGHT)
	if unit != null and not _is_tower_dive(unit):
		lane_idle_time = 0.0
		mode = &"fight"
		return unit
	var dragon := CombatWorld.find_dragon(get_tree())
	if dragon != null and _dragon_access_is_open() \
			and health_ratio() >= float(rules.bot_dragon_min_hp_pct):
		mode = &"dragon"
		return dragon
	if _nearest_enemy_any(LANE_EMPTY_SIGHT) == null:
		lane_idle_time += delta
		if lane_idle_time >= float(rules.bot_rotate_empty_lane_seconds):
			_rotate_to_pressured_lane()
			lane_idle_time = 0.0
	else:
		lane_idle_time = 0.0
	mode = &"lane"
	return _lane_structure()


## Pick the lane where the enemy is pushing hardest (closest enemy minion to
## our own core), falling back to the lane whose enemy tower still stands.
func _rotate_to_pressured_lane() -> void:
	var own_core_z := 12.6 if team == 0 else -13.6
	var best_lane := lane_x
	var best_score := -INF
	for candidate_lane in TravessiaDefinition.LANE_X:
		var score := 0.0
		for node in get_tree().get_nodes_in_group("arena_actors"):
			var actor := node as ArenaActor
			if actor == null or actor.is_defeated or actor.team != 1 - team:
				continue
			if actor.actor_kind == &"minion" and absf(actor.lane_x - candidate_lane) < 0.1:
				score += 10.0 - absf(actor.global_position.z - own_core_z) * 0.3
			elif actor.actor_kind == &"tower" \
					and absf(actor.global_position.x - candidate_lane) < 1.2:
				score += 2.0
		if absf(candidate_lane - lane_x) < 0.1:
			score -= 1.0
		if score > best_score:
			best_score = score
			best_lane = candidate_lane
	lane_x = best_lane


func _lane_structure() -> Node3D:
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
	if tower == null and enemy_base != null and enemy_base.get_is_protected():
		# Our lane is open but the core is still shielded: help the other lane.
		for candidate_lane in TravessiaDefinition.LANE_X:
			if absf(candidate_lane - lane_x) > 0.1:
				lane_x = candidate_lane
		return _lane_structure_no_rotate()
	return tower if tower != null else enemy_base


func _commit_to_tower(tower: ArenaActor) -> Node3D:
	lane_idle_time = 0.0
	mode = &"lane"
	lane_x = TravessiaDefinition.LANE_X[0] if tower.global_position.x < 0.0 \
		else TravessiaDefinition.LANE_X[1]
	return tower


func _weak_enemy_tower(below_ratio: float) -> ArenaActor:
	var best: ArenaActor
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor == null or actor.is_defeated or actor.team != 1 - team:
			continue
		if actor.actor_kind != &"tower" and actor.actor_kind != &"base":
			continue
		if actor.actor_kind == &"base" and actor.get_is_protected():
			continue
		if actor.health_ratio() >= below_ratio:
			continue
		var distance := CombatWorld.planar(self, actor)
		if distance < best_distance:
			best_distance = distance
			best = actor
	return best


func _lane_structure_no_rotate() -> Node3D:
	var enemy_team := 1 - team
	var tower: ArenaActor
	var enemy_base: ArenaActor
	for node in get_tree().get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor == null or actor.team != enemy_team or actor.is_defeated:
			continue
		if actor.actor_kind == &"tower" and absf(actor.global_position.x - lane_x) < 1.2:
			tower = actor
		elif actor.actor_kind == &"base":
			enemy_base = actor
	return tower if tower != null else enemy_base


## Where to stand for a given objective. Structures are approached only when
## allied minions are already tanking them; otherwise the bot holds just
## outside tower range and waits for the next wave.
func _goal_point_for(target: Node3D) -> Vector2:
	var target_point := Vector2(target.global_position.x, target.global_position.z)
	if target == self:
		return _spawn_point()
	if CombatWorld.is_structure(target) and not _structure_is_open(target):
		var self_point := Vector2(global_position.x, global_position.z)
		var away := (self_point - target_point)
		if away.length_squared() < 0.001:
			away = Vector2(0.0, 1.0 if team == 0 else -1.0)
		var hold_distance := float(rules.tower_attack_range) + TOWER_HOLD_MARGIN
		return target_point + away.normalized() * hold_distance
	return target_point


func _is_attackable(target: Node3D) -> bool:
	if target == self or not CombatWorld.is_valid_target(target):
		return false
	if CombatWorld.is_structure(target) and not _structure_is_open(target):
		return false
	return true


## A structure may be attacked when allied minions are tanking it or when it
## is nearly down and worth finishing.
func _structure_is_open(target: Node3D) -> bool:
	if _allied_minions_near(target, 3.2):
		return true
	return _ratio_of(target) < 0.45


func _allied_minions_near(target: Node3D, radius: float) -> bool:
	for node in get_tree().get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor != null and actor.actor_kind == &"minion" and actor.team == team \
				and not actor.is_defeated and CombatWorld.planar(actor, target) <= radius:
			return true
	return false


## Chasing a hero under a standing enemy tower is only worth it with minions
## tanking and plenty of health.
func _is_tower_dive(target: Node3D) -> bool:
	for node in get_tree().get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor == null or actor.is_defeated or actor.team != 1 - team:
			continue
		if actor.actor_kind != &"tower" and actor.actor_kind != &"base":
			continue
		if CombatWorld.planar(actor, target) <= float(rules.tower_attack_range):
			if health_ratio() < float(rules.bot_dive_min_hp_pct):
				return true
			if not _allied_minions_near(actor, 3.2):
				return true
	return false


func _spawn_point() -> Vector2:
	return Vector2(spawn_position.x, spawn_position.z)


func _apply_fountain(delta: float) -> void:
	if health >= max_health:
		return
	var core_z := 12.639 if team == 0 else -13.6257
	var distance := Vector2(global_position.x, global_position.z).distance_to(Vector2(0.0, core_z))
	if distance <= float(rules.fountain_radius):
		heal(max_health * float(rules.fountain_heal_pct_per_second) * delta)


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

func _move_toward_point(goal: Vector2, delta: float) -> void:
	route_timer -= delta
	var here := Vector2(global_position.x, global_position.z)
	var stale := not route.is_empty() \
		and not TravessiaNav.line_is_walkable(here, route[0], _dragon_access_is_open(), 0.42)
	if route.is_empty() or stale or route_timer <= 0.0 or goal.distance_to(route_goal) > 0.5:
		route = TravessiaNav.route(here, goal, _dragon_access_is_open(), 0.42)
		route_goal = goal
		route_timer = ROUTE_REFRESH
	while route.size() > 1 and Vector2(global_position.x, global_position.z) \
			.distance_to(route[0]) <= ROUTE_REACH:
		route.remove_at(0)
	var next_point: Vector2 = route[0] if not route.is_empty() else goal
	var direction := Vector3(next_point.x, 0.0, next_point.y) - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0004:
		velocity = Vector3.ZERO
		visual_model.update_motion(delta, facing_direction, 0.0)
		return
	direction = direction.normalized()
	facing_direction = direction
	velocity = direction * _current_move_speed()
	var previous_position := global_position
	move_and_slide()
	_constrain_to_walkable_area(previous_position)
	visual_model.update_motion(delta, facing_direction, 1.0)


func _process_dash(delta: float) -> void:
	dash_time_left -= delta
	if not CombatWorld.is_valid_target(dash_target) or dash_time_left <= 0.0:
		dash_target = null
		return
	var offset := dash_target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= 0.95:
		var target_ratio := _ratio_of(dash_target)
		var amount := dash_damage * damage_multiplier
		if target_ratio < dash_execute_pct:
			amount *= 2.0
			CombatWorld.report_text(get_tree(), dash_target.global_position + Vector3(0, 0.8, 0),
				"EXECUÇÃO", Color(1.0, 0.35, 0.55))
		_deal(dash_target, amount)
		CombatWorld.play_sfx(get_tree(), &"q_impact", -2.0)
		dash_target = null
		return
	facing_direction = offset / distance
	velocity = facing_direction * float(kit.r.get("dash_speed", 5.5))
	var previous_position := global_position
	move_and_slide()
	_constrain_to_walkable_area(previous_position)
	visual_model.face_direction(facing_direction)
	visual_model.update_motion(delta, facing_direction, 1.0)


# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

func _try_attack(target: Node3D) -> void:
	if attack_timer > 0.0 or not CombatWorld.is_valid_target(target):
		return
	if CombatWorld.planar(self, target) > attack_range + 0.1:
		return
	attack_timer = _current_attack_interval()
	visual_model.trigger_attack()
	var amount := attack_damage * damage_multiplier
	if empower_left > 0.0:
		amount += empower_bonus
		empower_left = 0.0
	if ranged:
		_spawn_projectile({
			"speed": projectile_speed, "range": attack_range + 2.0, "width": 0.22,
			"damage": amount, "homing_target": target, "hits_structures": true,
			"color": _hero_color(),
		})
	else:
		_deal(target, amount)


func _deal(target: Node3D, amount: float) -> void:
	if not CombatWorld.is_valid_target(target):
		return
	target.call("take_damage", amount, team)
	damage_dealt += amount
	CombatWorld.report_damage(get_tree(), target.global_position, amount,
		Color(1.0, 0.86, 0.45) if team == 0 else Color(1.0, 0.55, 0.5))


func _try_cast(target: Node3D) -> bool:
	if kit.is_empty():
		return false
	match hero_id:
		&"lyra":
			return _cast_lyra(target)
		&"nix":
			return _cast_nix(target)
		&"sol":
			return _cast_sol(target)
	return false


## Public entry points so tests and a future player controller can cast.
func request_q(target: Node3D = null) -> bool:
	if is_defeated or q_cooldown_left > 0.0 or kit.is_empty():
		return false
	var chosen := target if target != null else objective
	match hero_id:
		&"lyra":
			return _lyra_q(chosen)
		&"nix":
			return _nix_q(chosen)
		&"sol":
			return _sol_q(chosen)
	return false


func request_r(target: Node3D = null) -> bool:
	if is_defeated or r_cooldown_left > 0.0 or kit.is_empty():
		return false
	var chosen := target if target != null else objective
	match hero_id:
		&"lyra":
			return _lyra_r(chosen)
		&"nix":
			return _nix_r(chosen)
		&"sol":
			return _sol_r(chosen)
	return false


func _cast_lyra(target: Node3D) -> bool:
	if r_cooldown_left <= 0.0 and CombatWorld.is_hero(target):
		var target_ratio := _ratio_of(target)
		var crowd := CombatWorld.enemies_near(get_tree(), target.global_position, 2.0, team, false)
		if target_ratio < 0.6 or crowd.size() >= 2:
			if _lyra_r(target):
				return true
	if q_cooldown_left <= 0.0 and CombatWorld.planar(self, target) <= float(kit.q.range) * 0.9:
		return _lyra_q(target)
	return false


func _lyra_q(target: Node3D) -> bool:
	if target == null or q_cooldown_left > 0.0:
		return false
	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = facing_direction
	q_cooldown_left = float(kit.q.cooldown)
	facing_direction = direction.normalized()
	visual_model.face_direction(facing_direction)
	visual_model.trigger_q()
	_spawn_projectile({
		"direction": facing_direction, "speed": float(kit.q.speed), "range": float(kit.q.range),
		"width": float(kit.q.width), "damage": float(kit.q.damage) * damage_multiplier,
		"pierce": bool(kit.q.pierce), "hits_structures": false, "color": Color(0.55, 1.0, 0.6),
	})
	CombatWorld.play_sfx(get_tree(), &"r_throw", -6.0)
	ability_cast.emit(self, &"q")
	return true


func _lyra_r(target: Node3D) -> bool:
	if target == null or r_cooldown_left > 0.0:
		return false
	if CombatWorld.planar(self, target) > float(kit.r.cast_range):
		return false
	r_cooldown_left = float(kit.r.cooldown)
	visual_model.trigger_ultimate()
	_spawn_zone(target.global_position, {
		"radius": float(kit.r.radius), "duration": float(kit.r.duration),
		"tick": float(kit.r.tick), "delay": float(kit.r.delay),
		"damage_per_second": float(kit.r.damage_per_second) * damage_multiplier,
		"slow": float(kit.r.slow), "color": Color(0.6, 1.0, 0.55),
	})
	CombatWorld.play_sfx(get_tree(), &"stun", -4.0)
	ability_cast.emit(self, &"r")
	return true


func _cast_nix(target: Node3D) -> bool:
	if not CombatWorld.is_hero(target):
		return false
	var distance := CombatWorld.planar(self, target)
	var target_ratio := _ratio_of(target)
	if r_cooldown_left <= 0.0 and target_ratio <= 0.45 and distance <= float(kit.r.range):
		return _nix_r(target)
	if q_cooldown_left <= 0.0 and distance > attack_range and distance <= float(kit.q.blink) + attack_range:
		return _nix_q(target)
	return false


func _nix_q(target: Node3D) -> bool:
	if q_cooldown_left > 0.0:
		return false
	var direction := facing_direction
	var blink := float(kit.q.blink)
	if target != null:
		var offset := target.global_position - global_position
		offset.y = 0.0
		if offset.length() > 0.05:
			direction = offset.normalized()
			blink = minf(blink, maxf(0.0, offset.length() - attack_range * 0.7))
	q_cooldown_left = float(kit.q.cooldown)
	var origin := global_position
	var destination := TravessiaDefinition.constrain_walkable_motion(origin,
		origin + direction * blink, _dragon_access_is_open(), 0.42)
	_spawn_blink_puff(origin)
	global_position = destination
	_spawn_blink_puff(destination)
	empower_left = float(kit.q.bonus_window)
	empower_bonus = float(kit.q.bonus_damage)
	facing_direction = direction
	visual_model.face_direction(facing_direction)
	visual_model.trigger_q()
	CombatWorld.play_sfx(get_tree(), &"swing", -4.0)
	ability_cast.emit(self, &"q")
	return true


func _nix_r(target: Node3D) -> bool:
	if target == null or r_cooldown_left > 0.0 or not CombatWorld.is_hero(target):
		return false
	if CombatWorld.planar(self, target) > float(kit.r.range):
		return false
	r_cooldown_left = float(kit.r.cooldown)
	dash_target = target
	dash_time_left = float(kit.r.range) / float(kit.r.dash_speed) + 0.4
	dash_damage = float(kit.r.damage)
	dash_execute_pct = float(kit.r.execute_hp_pct)
	visual_model.trigger_ultimate()
	CombatWorld.play_sfx(get_tree(), &"q_charge", -3.0)
	ability_cast.emit(self, &"r")
	return true


func _cast_sol(target: Node3D) -> bool:
	var wounded := _most_wounded_ally(float(kit.q.range), 0.65)
	if r_cooldown_left <= 0.0:
		var close_ally := _most_wounded_ally(float(kit.r.radius), 0.55)
		var threatened := health_ratio() < 0.5 \
			and not CombatWorld.enemies_near(get_tree(), global_position, 3.5, team, false).is_empty()
		if close_ally != null or threatened:
			if _sol_r(null):
				return true
	if q_cooldown_left <= 0.0:
		if wounded != null:
			return _sol_q(wounded)
		if CombatWorld.planar(self, target) <= float(kit.q.range):
			return _sol_q(target)
	return false


func _sol_q(target: Node3D) -> bool:
	if target == null or q_cooldown_left > 0.0 or not CombatWorld.is_valid_target(target):
		return false
	var is_ally := int(target.call("get_team")) == team
	if is_ally and not CombatWorld.is_hero(target):
		return false
	q_cooldown_left = float(kit.q.cooldown)
	var offset := target.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() > 0.001:
		facing_direction = offset.normalized()
		visual_model.face_direction(facing_direction)
	visual_model.trigger_q()
	_spawn_projectile({
		"speed": float(kit.q.speed), "range": float(kit.q.range) + 1.0,
		"width": float(kit.q.width), "homing_target": target,
		"damage": 0.0 if is_ally else float(kit.q.damage) * damage_multiplier,
		"heal": float(kit.q.heal) if is_ally else 0.0, "color": Color(1.0, 0.86, 0.35),
	})
	CombatWorld.play_sfx(get_tree(), &"r_throw", -8.0)
	ability_cast.emit(self, &"q")
	return true


func _sol_r(_target: Node3D) -> bool:
	if r_cooldown_left > 0.0:
		return false
	r_cooldown_left = float(kit.r.cooldown)
	visual_model.trigger_ultimate()
	_spawn_zone(global_position, {
		"radius": float(kit.r.radius), "duration": float(kit.r.duration),
		"tick": float(kit.r.tick), "delay": float(kit.r.delay),
		"heal_per_second": float(kit.r.heal_per_second), "haste": float(kit.r.haste),
		"color": Color(1.0, 0.82, 0.3),
	})
	CombatWorld.play_sfx(get_tree(), &"kill", -8.0)
	ability_cast.emit(self, &"r")
	return true


func _most_wounded_ally(radius: float, below_ratio: float) -> Node3D:
	var best: Node3D
	var best_ratio := below_ratio
	for ally in CombatWorld.allies_near(get_tree(), global_position, radius, team, true, self):
		var ratio := _ratio_of(ally)
		if ratio < best_ratio:
			best_ratio = ratio
			best = ally
	return best


static func _ratio_of(node: Node) -> float:
	if node != null and node.has_method("health_ratio"):
		return float(node.call("health_ratio"))
	return 1.0


func _spawn_projectile(data: Dictionary) -> AbilityProjectile:
	var projectile := AbilityProjectile.new()
	data["team"] = team
	data["source"] = self
	if not data.has("direction"):
		data["direction"] = facing_direction
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3(0, 1.1, 0) + facing_direction * 0.4
	projectile.configure(data)
	return projectile


func _spawn_zone(at_position: Vector3, data: Dictionary) -> AbilityZone:
	var zone := AbilityZone.new()
	data["team"] = team
	get_parent().add_child(zone)
	zone.global_position = Vector3(at_position.x, 0.0, at_position.z)
	zone.configure(data)
	return zone


func _spawn_blink_puff(at_position: Vector3) -> void:
	var puff := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.55
	mesh.outer_radius = 0.7
	mesh.rings = 24
	mesh.ring_segments = 6
	puff.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.45, 1.0, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material_override = material
	get_parent().add_child(puff)
	puff.global_position = at_position + Vector3(0, 0.08, 0)
	var tween := puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "scale", Vector3.ONE * 1.8, 0.28)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.28)
	tween.chain().tween_callback(puff.queue_free)


func _hero_color() -> Color:
	match hero_id:
		&"lyra":
			return Color(0.55, 1.0, 0.6)
		&"sol":
			return Color(1.0, 0.86, 0.35)
	return Color(0.75, 0.5, 1.0)


# ---------------------------------------------------------------------------
# Perception
# ---------------------------------------------------------------------------

func _nearest_enemy_unit(max_distance: float) -> Node3D:
	var candidates: Array = []
	for node in get_tree().get_nodes_in_group("damageable"):
		var actor := node as ArenaActor
		if actor == null or actor.actor_kind != &"minion" or actor.team == team:
			continue
		if not CombatWorld.is_valid_target(actor):
			continue
		if CombatWorld.planar(self, actor) <= max_distance:
			candidates.append(actor)
	return CombatWorld.nearest(candidates, global_position)


func _nearest_enemy_hero(max_distance: float) -> Node3D:
	var candidates: Array = []
	for node in get_tree().get_nodes_in_group("damageable"):
		if node == self or not CombatWorld.is_hero(node) or not CombatWorld.is_valid_target(node):
			continue
		if int(node.call("get_team")) == team:
			continue
		if CombatWorld.planar(self, node) <= max_distance:
			candidates.append(node)
	return CombatWorld.nearest(candidates, global_position)


func _nearest_enemy_any(max_distance: float) -> Node3D:
	var candidates: Array = []
	for node in get_tree().get_nodes_in_group("damageable"):
		if node == self or not CombatWorld.is_valid_target(node):
			continue
		if int(node.call("get_team")) != 1 - team or CombatWorld.is_structure(node):
			continue
		if CombatWorld.planar(self, node) <= max_distance:
			candidates.append(node)
	return CombatWorld.nearest(candidates, global_position)


func _valid_target(candidate) -> bool:
	return CombatWorld.is_valid_target(candidate) and int(candidate.call("get_team")) != team


func _is_structure(candidate: Node) -> bool:
	return CombatWorld.is_structure(candidate)


func _planar_distance(candidate: Node3D) -> float:
	return CombatWorld.planar(self, candidate)


# ---------------------------------------------------------------------------
# Lifecycle and presentation
# ---------------------------------------------------------------------------

func _revive() -> void:
	global_position = spawn_position
	health = max_health
	is_defeated = false
	last_damage_team = -1
	objective = null
	mode = &"lane"
	route = []
	dash_target = null
	stun_left = 0.0
	slow_left = 0.0
	slow_factor = 1.0
	haste_left = 0.0
	empower_left = 0.0
	_set_stun_marker(false)
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
