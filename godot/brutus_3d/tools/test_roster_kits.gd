extends SceneTree

## Contract for the roster kits, bot decisions, navigation, wave fairness,
## the readable tiebreak and the touch ability buttons.


func _initialize() -> void:
	call_deferred("_run")


func _spawn_bot(game: Node, hero: StringName, team: int, at_position: Vector3) -> HeroBot:
	var data: Dictionary
	for candidate in TravessiaDefinition.hero_bots():
		if candidate.hero == hero:
			data = candidate.duplicate()
	data.team = team
	data.position = at_position
	var bot := HeroBot.new()
	bot.position = at_position
	game.add_child(bot)
	bot.configure(data)
	return bot


func _spawn_minion(game: Node, team: int, at_position: Vector3, harmless := true) -> ArenaActor:
	var data := TravessiaDefinition.minion(team, at_position.x)
	data.position = at_position
	var actor: ArenaActor = game.call("_spawn_actor", data, at_position)
	if harmless:
		actor.attack_damage = 0.0
	return actor


func _count(game: Node, type_name: String) -> int:
	var total := 0
	for child in game.get_children():
		if child.get_class() == "Node3D" and child.get_script() != null \
				and child.get_script().get_global_name() == type_name:
			total += 1
	return total


func _run() -> void:
	# --- Pure navigation checks (no scene) ---
	var direct := TravessiaNav.route(Vector2(-5.35, 6.0), Vector2(-5.35, -6.0), false)
	assert(direct.size() == 1, "Straight lane travel must not need waypoints")
	var cross := TravessiaNav.route(Vector2(-5.35, -7.0), Vector2(5.35, -7.0), false)
	assert(cross.size() >= 3, "Lane-to-lane travel must route through the base openings")
	for point in cross:
		assert(TravessiaDefinition.is_walkable(point, false, 0.42),
			"Every route point must be walkable: %s" % str(point))
	var to_dragon_closed := TravessiaNav.waypoint_path(&"blue_core", &"dragon_island", false)
	assert(to_dragon_closed.is_empty(), "The island must be unreachable before the bridges open")
	var to_dragon_open := TravessiaNav.waypoint_path(&"blue_core", &"dragon_island", true)
	assert(to_dragon_open.size() >= 4 and to_dragon_open[-1] == &"dragon_island",
		"The island must be reachable after the bridges open")
	var waypoints := TravessiaDefinition.nav_waypoints()
	var all_edges: Array = TravessiaDefinition.nav_edges().duplicate()
	all_edges.append_array(TravessiaDefinition.nav_dragon_edges())
	for edge in all_edges:
		assert(TravessiaNav.line_is_walkable(waypoints[edge[0]], waypoints[edge[1]], true, 0.42),
			"Nav edge %s -> %s must be walkable for a hero body" % [edge[0], edge[1]])

	var scene := load("res://main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	Engine.time_scale = 1.0
	await process_frame
	var brutus := game.get_node("Brutus") as BrutusController
	var rules: Dictionary = game.match_rules
	assert(is_equal_approx(float(rules.dragon_team_damage_bonus), 1.30) \
		and is_equal_approx(float(rules.dragon_buff_duration), 45.0),
		"Dragon reward must be +30% for 45 s as documented")

	# Real bots have kits and use the shared helpers.
	for node in get_nodes_in_group("hero_bots"):
		var bot := node as HeroBot
		assert(not bot.kit.is_empty(), "%s must load a Q/R kit" % bot.display_name)
	# Isolate.
	for actor in get_nodes_in_group("arena_actors"):
		actor.queue_free()
	await process_frame
	brutus.global_position = Vector3(-5.35, 0.0, 6.0)
	brutus.velocity = Vector3.ZERO

	# --- Lyra: piercing arrow hits two minions in a line and the rain slows ---
	var lyra := _spawn_bot(game, &"lyra", 1, Vector3(-5.35, 0.0, -2.0))
	var first := _spawn_minion(game, 0, Vector3(-5.35, 0.0, 0.5))
	var second := _spawn_minion(game, 0, Vector3(-5.35, 0.0, 2.0))
	first.objective = null
	second.objective = null
	await physics_frame
	assert(lyra.request_q(first), "Lyra Q must fire at a target in range")
	assert(lyra.q_cooldown_left > 0.0, "Lyra Q cooldown was not applied")
	var pierce_hits := 0
	for _frame in range(60):
		await physics_frame
		if first.health < first.max_health and second.health < second.max_health:
			pierce_hits = 2
			break
	assert(pierce_hits == 2, "Flecha Perfurante must pierce through both minions")
	assert(lyra.request_r(second), "Lyra R must place a zone on the target")
	var zone := game.find_child("AbilityZone", true, false) as AbilityZone
	assert(zone != null and zone.slow_factor < 1.0, "Chuva de Flechas zone missing or not slowing")
	var second_health := second.health
	for _frame in range(70):
		await physics_frame
	assert(second.health < second_health, "Zone ticks did not damage the minion inside")
	assert(second.slow_left > 0.0 or second.is_defeated, "Zone must slow the minion inside")
	lyra.queue_free()
	first.queue_free()
	second.queue_free()
	await process_frame

	# --- Nix: blink closes distance, empowered hit, execute on low target ---
	var nix := _spawn_bot(game, &"nix", 1, Vector3(-5.35, 0.0, -1.0))
	var victim := _spawn_bot(game, &"sol", 0, Vector3(-5.35, 0.0, 2.6))
	victim.objective = null
	await physics_frame
	var before_blink := nix.global_position
	assert(nix.request_q(victim), "Nix Q must blink toward the target")
	assert(nix.global_position.distance_to(before_blink) > 1.0, "Passo Sombrio did not move Nix")
	assert(nix.empower_left > 0.0, "Passo Sombrio must empower the next hit")
	victim.health = victim.max_health * 0.2
	assert(nix.request_r(victim), "Nix R must dash at a hero in range")
	var executed := false
	for _frame in range(90):
		await physics_frame
		if victim.is_defeated:
			executed = true
			break
	assert(executed, "Execução below 35%% must kill a wounded hero")
	nix.queue_free()
	victim.queue_free()
	await process_frame

	# --- Sol: orb heals the wounded ally, zone heals and hastens ---
	var sol := _spawn_bot(game, &"sol", 0, Vector3(-5.35, 0.0, 4.5))
	brutus.global_position = Vector3(-5.35, 0.0, 2.0)
	brutus.health = 600.0
	await physics_frame
	assert(sol.request_q(brutus), "Sol Q must target a wounded ally")
	var healed := false
	for _frame in range(60):
		await physics_frame
		if brutus.health > 600.0:
			healed = true
			break
	assert(healed, "Orbe Solar did not heal Brutus")
	sol.health = sol.max_health * 0.4
	assert(sol.request_r(), "Sol R must open a zone under herself")
	var sol_health := sol.health
	for _frame in range(60):
		await physics_frame
	assert(sol.health > sol_health, "Zona Radiante did not heal Sol")
	assert(sol.haste_left > 0.0, "Zona Radiante did not hasten Sol")
	brutus.health = brutus.max_health

	# --- Ranged basic attacks travel as projectiles ---
	var dummy := _spawn_minion(game, 1, Vector3(-5.35, 0.0, 2.5))
	dummy.objective = null
	sol.objective = dummy
	sol.attack_timer = 0.0
	var dummy_health := dummy.health
	sol.call("_try_attack", dummy)
	assert(is_equal_approx(dummy.health, dummy_health), "Ranged hit must not be instant")
	var projectile_seen := game.find_child("AbilityProjectile", true, false) != null
	assert(projectile_seen, "Ranged basic attack must spawn a projectile")
	for _frame in range(60):
		await physics_frame
	assert(dummy.health < dummy_health, "Ranged projectile did not land")
	dummy.queue_free()
	sol.queue_free()
	await process_frame

	# --- Bot decisions: retreat, fountain, dragon, tower dive guard ---
	brutus.global_position = TravessiaDefinition.PLAYER_SPAWN
	brutus.velocity = Vector3.ZERO
	var bot := _spawn_bot(game, &"lyra", 1, Vector3(-5.35, 0.0, -4.0))
	bot.health = bot.max_health * 0.2
	bot.call("_decide", 0.016)
	assert(bot.mode == &"retreat", "A bot at 20%% health must retreat")
	bot.global_position = Vector3(0.0, 0.0, -12.5)
	var low := bot.health
	bot.call("_apply_fountain", 1.0)
	assert(bot.health > low, "Fountain must heal a bot near its own core")
	bot.health = bot.max_health
	bot.call("_decide", 0.016)
	assert(bot.mode != &"retreat", "A healed bot must leave retreat")

	var dragon_data := TravessiaDefinition.dragon_definition()
	var dragon: ArenaActor = game.call("_spawn_actor", dragon_data, dragon_data.position)
	dragon.attack_damage = 0.0
	game.arena_map.open_dragon_access(0.4)
	await create_timer(1.2, true, false, true).timeout
	assert(game.arena_map.is_dragon_access_open(), "Dragon bridges must open for the bot test")
	bot.global_position = Vector3(-5.0, 0.0, -9.6)
	bot.call("_decide", 0.016)
	assert(bot.objective == dragon, "A healthy bot must contest the dragon once it is reachable")
	assert(bot.mode == &"dragon", "Dragon mode expected")
	var reached := false
	for _frame in range(1000):
		await physics_frame
		if CombatWorld.planar(bot, dragon) <= bot.attack_range + 0.2:
			reached = true
			break
	assert(reached, "Bot did not navigate to the dragon island")
	for _frame in range(60):
		await physics_frame
	assert(dragon.health < dragon.max_health, "Bot at the island did not attack the dragon")
	dragon.take_damage(dragon.max_health, 1)
	await process_frame

	var tower_data := {"kind": &"tower", "team": 0, "health": 1500.0, "attack_damage": 125.0,
		"attack_range": 4.5, "attack_interval": 1.0, "color": Color.WHITE}
	var tower: ArenaActor = game.call("_spawn_actor", tower_data, Vector3(-5.35, 0.0, 8.0))
	tower.attack_damage = 0.0
	brutus.global_position = Vector3(-5.35, 0.0, 6.0)
	bot.global_position = Vector3(-5.35, 0.0, 2.0)
	bot.health = bot.max_health
	bot.mode = &"lane"
	bot.call("_decide", 0.016)
	assert(bot.objective != brutus, "Bot must not dive a hero standing under a tower")
	assert(not bot.call("_is_attackable", tower), "Bot must not hit a tower without minions")
	var hold: Vector2 = bot.call("_goal_point_for", tower)
	assert(hold.distance_to(Vector2(-5.35, 8.0)) > 4.5, "Bot must hold outside tower range")
	tower.health = tower.max_health * 0.3
	assert(bot.call("_is_attackable", tower), "Bot must finish a tower below 45%")
	tower.health = tower.max_health
	# Towers shoot minions before heroes so a wave can tank for its hero.
	var tank := _spawn_minion(game, 1, Vector3(-5.35, 0.0, 5.5))
	bot.global_position = Vector3(-5.35, 0.0, 6.2)
	tower.objective = null
	tower.call("_process_guardian")
	assert(tower.objective == tank, "Tower must target the minion before the hero")
	tank.take_damage(tank.max_health, 0)
	await process_frame
	tower.objective = null
	tower.call("_process_guardian")
	assert(tower.objective == bot, "Tower must fall back to the hero once minions are gone")
	tower.queue_free()
	bot.queue_free()
	await process_frame

	# --- Bushes: a hero inside a camp is hidden until revealed ---
	var scout := _spawn_bot(game, &"lyra", 1, Vector3(2.47, 0.0, 3.6))
	scout.objective = null
	brutus.global_position = Vector3(2.47, 0.0, 6.81)
	brutus.reveal_left = 0.0
	for _frame in range(3):
		await physics_frame
	assert(brutus.is_concealed(), "Brutus inside a camp must be concealed")
	assert(scout.call("_nearest_enemy_hero", 5.5) == null,
		"A bot 3 m away must not see a hero hidden in a bush")
	scout.global_position = Vector3(2.47, 0.0, 5.6)
	assert(scout.call("_nearest_enemy_hero", 5.5) == brutus,
		"A bot within reveal distance must see the hidden hero")
	scout.global_position = Vector3(2.47, 0.0, 3.6)
	brutus.request_attack()
	await physics_frame
	assert(not brutus.is_concealed(), "Attacking must reveal Brutus")
	assert(scout.call("_nearest_enemy_hero", 5.5) == brutus, "Revealed hero must be targetable")
	for _frame in range(120):
		await physics_frame
	brutus.action_state = &""
	scout.queue_free()
	await process_frame
	brutus.global_position = Vector3(-5.35, 0.0, 6.0)

	# --- Minion column and fair trades ---
	var leader := _spawn_minion(game, 0, Vector3(-5.35, 0.0, 4.0), false)
	var follower := _spawn_minion(game, 0, Vector3(-5.35, 0.0, 4.3), false)
	var enemy := _spawn_minion(game, 1, Vector3(-5.35, 0.0, 0.5), false)
	enemy.attack_damage = 0.0
	leader.attack_damage = 0.0
	follower.attack_damage = 0.0
	for _frame in range(45):
		await physics_frame
	var gap := absf(leader.global_position.z - follower.global_position.z)
	assert(gap >= ArenaActor.MINION_COLUMN_SPACING - 0.05,
		"Allied minions must keep column spacing instead of stacking (gap %.2f)" % gap)
	enemy.global_position = leader.global_position + Vector3(0, 0, -1.0)
	enemy.health = 20.0
	leader.health = 20.0
	enemy.attack_damage = 26.0
	leader.attack_damage = 26.0
	enemy.attack_timer = 0.0
	leader.attack_timer = 0.0
	enemy.objective = leader
	leader.objective = enemy
	enemy.call("_try_attack", leader)
	leader.call("_try_attack", enemy)
	assert(enemy.health == 20.0 and leader.health == 20.0, "Minion hits must be delayed swings")
	await create_timer(0.5).timeout
	assert(enemy.is_defeated and leader.is_defeated, "Simultaneous trades must land for both minions")
	follower.queue_free()
	await process_frame

	# --- Tiebreak cascade and HUD ---
	game.team_towers_destroyed = [1, 0]
	var verdict: Dictionary = game.call("_team_advantage")
	assert(int(verdict.winner) == 0 and verdict.stage == &"towers", "Towers must decide first")
	game.team_towers_destroyed = [1, 1]
	game.team_kills = [2, 9]
	verdict = game.call("_team_advantage")
	assert(verdict.stage == &"core" or verdict.stage == &"kills",
		"Equal towers must fall through to core health or kills")
	game.team_kills = [0, 0]
	game.call("_update_match_label")
	assert(game.get_node("HUD/Advantage") is Label, "Advantage label must exist in the HUD")
	assert(game.get_node("HUD/MatchStatus").text.contains("%"),
		"Match status must show both main tower health percentages")

	# --- Dragon buff is temporary and reinforces two waves ---
	game.team_towers_destroyed = [0, 0]
	game.call("_apply_dragon_reward", 0)
	assert(game.dragon_buff_team == 0 and game.dragon_buff_left > 44.0, "Dragon buff timer missing")
	assert(int(game.reinforced_waves_left[0]) == 2, "Two reinforced waves expected")
	var boosted: ArenaActor = game.call("_spawn_minion", 0, TravessiaDefinition.LANE_X[0])
	assert(boosted.is_reinforced and boosted.max_health > 240.0, "Reinforced minion expected")
	game.dragon_buff_left = 0.01
	game.call("_tick_dragon_buff", 0.1)
	assert(game.dragon_buff_team == -1 and is_equal_approx(float(game.team_damage_multiplier[0]), 1.0),
		"Dragon buff must expire and reset the multiplier")
	boosted.queue_free()

	# --- Touch buttons: tap = quick cast, drag = aimed cast, drag back = cancel ---
	var q_button := game.get_node("HUD/QButton") as AbilityButton
	assert(q_button != null, "Q must be an AbilityButton")
	var quick := [0]
	var aimed := []
	var cancelled := [0]
	q_button.quick_cast.connect(func() -> void: quick[0] += 1)
	q_button.aim_cast.connect(func(direction: Vector2) -> void: aimed.append(direction))
	q_button.aim_cancelled.connect(func() -> void: cancelled[0] += 1)
	q_button.call("_press", 3, Vector2(50, 50))
	q_button.call("_release", Vector2(52, 51))
	assert(quick[0] == 1, "Tap must quick cast")
	q_button.call("_press", 3, Vector2(50, 50))
	q_button.call("_drag", Vector2(50, -80))
	assert(q_button.is_aiming(), "Dragging past the threshold must enter aim mode")
	q_button.call("_release", Vector2(50, -80))
	assert(aimed.size() == 1 and aimed[0].y < -0.9, "Releasing upward must cast north")
	q_button.call("_press", 3, Vector2(50, 50))
	q_button.call("_drag", Vector2(200, 50))
	q_button.call("_release", Vector2(55, 50))
	assert(cancelled[0] == 1, "Dragging back onto the button must cancel")
	q_button.set_cooldown(3.5, 7.0)
	assert(q_button.cooldown_ratio < 1.0 and is_equal_approx(q_button.cooldown_left, 3.5),
		"Cooldown fill and remaining time")
	assert(q_button.icon_texture != null, "Ability buttons must show the painted skill icons")
	brutus.q_cooldown_left = 0.0
	brutus.action_state = &""
	brutus.request_q(Vector3(1, 0, 0))
	assert(brutus.q_direction.is_equal_approx(Vector3(1, 0, 0)), "Manual aim must override assist")
	brutus.show_aim_preview(&"q", Vector3(0, 0, -1))
	assert(brutus.is_aim_preview_visible(), "Aim preview must appear")
	var indicator := game.get_node("HUD/AimIndicator") as AimIndicator
	assert(indicator != null and indicator.strip_points(brutus).size() == 4,
		"HUD aim indicator must project the strip corners")
	brutus.hide_aim_preview()
	assert(not brutus.is_aim_preview_visible(), "Aim preview must hide")
	var joystick := game.get_node("HUD/VirtualJoystick") as FreneticJoystick
	joystick.call("_begin", Vector2(300, 300))
	assert(joystick.active and joystick.base_center == Vector2(300, 300), "Joystick must float to the touch")
	joystick.call("_release")

	# Whole-map view on demand: tapping the minimap zooms out and back.
	var camera := game.get_node("CameraRig/Camera3D") as Camera3D
	var map_panel := game.get_node("HUD/Minimap") as Minimap
	map_panel.tapped.emit()
	await create_timer(0.6, true, false, true).timeout
	assert(game.full_map_view and is_equal_approx(camera.size, 37.0),
		"Tapping the minimap must zoom out to the whole map")
	assert(game.get_node("CameraRig").global_position.length() < 0.8,
		"Whole-map view must centre the camera rig")
	map_panel.tapped.emit()
	await create_timer(0.6, true, false, true).timeout
	assert(not game.full_map_view and is_equal_approx(camera.size, 14.0),
		"Tapping again must return to the close camera")
	var r_button := game.get_node("HUD/RButton") as Control
	assert(r_button.offset_left >= -122.0, "R button must sit clear of the blue right tower")
	print("ROSTER_KITS_OK lyra=true nix=true sol=true bots=true nav=true minions=true hud=true buttons=true")
	quit()
