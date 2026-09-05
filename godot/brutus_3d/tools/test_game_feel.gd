extends SceneTree

## Game-feel contract: aim assist, input buffering, ability cancels, crowd
## control, hitstop, floating damage numbers, hurt flash and procedural audio.


func _initialize() -> void:
	call_deferred("_run")


func _spawn_enemy_minion(game: Node, at_position: Vector3) -> ArenaActor:
	var data := TravessiaDefinition.minion(1, at_position.x)
	data.position = at_position
	var actor: ArenaActor = game.call("_spawn_actor", data, at_position)
	# A harmless dummy: retaliation would put Brutus into the hurt state and
	# make action timing assertions ambiguous.
	actor.attack_damage = 0.0
	return actor


func _run() -> void:
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null, "main.tscn must load")
	var game := scene.instantiate()
	root.add_child(game)
	Engine.time_scale = 1.0
	await process_frame
	var brutus := game.get_node("Brutus") as BrutusController
	assert(brutus != null, "Brutus controller missing")

	# Presentation and audio layers exist and are wired.
	var sfx := game.get_node("ArenaSfx") as ArenaSfx
	assert(sfx != null and sfx.is_in_group("arena_sfx"), "Procedural SFX node missing")
	for clip in [&"swing", &"hit", &"q_charge", &"q_impact", &"r_throw", &"r_impact",
			&"r_catch", &"hurt", &"kill", &"death", &"tower_shot", &"tower_down",
			&"stun", &"dragon"]:
		assert(sfx.has_clip(clip), "SFX library is missing %s" % clip)
		var stream := sfx.streams[clip] as AudioStreamWAV
		assert(stream.data.size() > 1000, "SFX clip %s is empty" % clip)
	var feedback := game.get_node("CombatFeedback") as CombatFeedback
	assert(feedback != null, "Combat feedback node missing")
	assert(game.get_node_or_null("HUD/HurtFlash") is ColorRect, "Hurt flash overlay missing")

	# Isolate from the live match so bots and waves cannot interfere.
	game.match_over = false
	for actor in get_nodes_in_group("arena_actors"):
		actor.queue_free()
	await process_frame
	var lane := Vector3(TravessiaDefinition.LANE_X[0], 0.0, 6.0)
	brutus.global_position = lane
	brutus.last_direction = Vector3(0, 0, -1)
	brutus.velocity = Vector3.ZERO
	await physics_frame

	# 1. Aim assist: an enemy 35 degrees off the facing direction still gets hit.
	var offset := Vector3(sin(deg_to_rad(35.0)), 0.0, -cos(deg_to_rad(35.0))) * 1.5
	var minion := _spawn_enemy_minion(game, lane + offset)
	await physics_frame
	var health_before := minion.health
	brutus.request_attack()
	assert(brutus.last_assist_target == minion, "Aim assist did not pick the off-axis enemy")
	var aimed := Vector2(brutus.attack_direction.x, brutus.attack_direction.z)
	var toward := Vector2(offset.x, offset.z).normalized()
	assert(aimed.angle_to(toward) < 0.05, "Attack direction did not turn toward the target")
	for _frame in range(30):
		await physics_frame
	assert(minion.health < health_before, "Assisted basic attack did not land damage")
	assert(feedback.hitstop_active or Engine.time_scale == 1.0,
		"Hitstop state must be coherent after a landed hit")
	var number_found := false
	for child in game.get_children():
		if child is Label3D and child.name == "DamageNumber":
			number_found = true
			break
	assert(number_found, "Landed hit did not spawn a floating damage number")
	for _frame in range(60):
		await physics_frame
	assert(brutus.action_state.is_empty(), "Attack did not finish")
	assert(is_equal_approx(Engine.time_scale, 1.0),
		"Hitstop did not restore the base time scale")

	# 2. Aim assist is a soft cone: an enemy behind Brutus is ignored.
	minion.global_position = lane + Vector3(0.0, 0.0, 1.6)
	await physics_frame
	var direction_before := brutus.last_direction
	brutus.request_attack()
	assert(brutus.last_assist_target == null, "Aim assist must not snap to targets behind")
	assert(brutus.attack_direction.is_equal_approx(direction_before.normalized()),
		"Attack must keep the facing direction when nothing is inside the cone")
	for _frame in range(90):
		await physics_frame
	assert(brutus.action_state.is_empty(), "Second attack did not finish")

	# 3. Input buffer: Q pressed during the attack wind-up fires afterwards.
	brutus.q_cooldown_left = 0.0
	brutus.request_attack()
	await physics_frame
	brutus.request_q()
	assert(brutus.buffered_action == &"q", "Q during attack wind-up must be buffered")
	assert(brutus.action_state != &"q", "Q must not interrupt the wind-up")
	var started_q := false
	for _frame in range(60):
		await physics_frame
		if brutus.action_state == &"q":
			started_q = true
			break
	assert(started_q, "Buffered Q did not fire after the basic attack")
	assert(brutus.buffered_action.is_empty(), "Buffer must clear once consumed")
	for _frame in range(80):
		await physics_frame
	assert(brutus.action_state.is_empty(), "Q did not finish")

	# 4. Hurt never eats a command.
	brutus.take_damage(40.0)
	assert(brutus.action_state == &"hurt", "Hurt reaction expected")
	brutus.request_attack()
	assert(brutus.action_state == &"attack" or brutus.action_state == &"attack_alt",
		"Attack must interrupt the hurt recoil immediately")
	for _frame in range(90):
		await physics_frame

	# 5. Investida stuns; the stunned minion stops moving and is marked.
	minion.global_position = lane + Vector3(0.0, 0.0, -3.0)
	minion.health = minion.max_health
	minion.objective = null
	brutus.last_direction = Vector3(0, 0, -1)
	brutus.q_cooldown_left = 0.0
	brutus.request_q()
	assert(brutus.action_state == &"q", "Q did not start")
	var stunned := false
	for _frame in range(80):
		await physics_frame
		if minion.is_stunned():
			stunned = true
			break
	assert(stunned, "Investida hit did not stun the minion")
	assert(minion.stun_marker != null and minion.stun_marker.visible,
		"Stunned minion must display its marker")
	assert(minion.velocity.is_zero_approx(), "Stunned minion must not move")
	for _frame in range(80):
		await physics_frame
	assert(not minion.is_stunned(), "Stun must expire")
	assert(not minion.stun_marker.visible, "Stun marker must hide when the stun ends")

	# 6. Shield slows; towers ignore crowd control.
	minion.apply_slow(0.5, 1.0)
	assert(is_equal_approx(minion.call("_current_move_speed"), minion.move_speed * 0.5),
		"Slow did not halve the minion speed")
	var tower_data := {"kind": &"tower", "team": 1, "health": 500.0, "attack_damage": 0.0,
		"attack_range": 0.0, "attack_interval": 1.0, "color": Color.WHITE}
	var tower: ArenaActor = game.call("_spawn_actor", tower_data, lane + Vector3(3.0, 0, -4.0))
	tower.apply_stun(1.0)
	assert(not tower.is_stunned(), "Structures must ignore stuns")

	# 7. Hero bots also respect crowd control and clear it on revive.
	var hero := HeroBot.new()
	hero.position = lane + Vector3(0.0, 0.0, -5.0)
	game.add_child(hero)
	hero.configure(TravessiaDefinition.hero_bots()[1])
	hero.apply_stun(0.5)
	assert(hero.is_stunned(), "Hero bot stun failed")
	hero.call("_revive")
	assert(not hero.is_stunned(), "Revive must clear crowd control")

	# 8. Player damage feedback: red flash and a red number.
	var flash := game.get_node("HUD/HurtFlash") as ColorRect
	assert(flash.material is ShaderMaterial, "Hurt flash must be an edge vignette shader")
	brutus.take_damage(120.0)
	assert(feedback.flash_strength > 0.1, "Taking damage must flash the screen edges")
	await create_timer(0.6, true, false, true).timeout
	assert(feedback.flash_strength < 0.05, "Hurt flash must fade out quickly")

	# 9. Hitstop restores the time scale it found, not a hard-coded one.
	Engine.time_scale = 0.5
	feedback.request_hitstop(0.05)
	assert(Engine.time_scale < 0.5, "Hitstop did not slow the game")
	await create_timer(0.25, true, false, true).timeout
	assert(is_equal_approx(Engine.time_scale, 0.5), "Hitstop must restore the prior pace")
	Engine.time_scale = 1.0

	print("GAME_FEEL_OK aim_assist=true buffer=true stun=true hitstop=true sfx=",
		sfx.streams.size())
	quit()
