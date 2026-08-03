extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null, "main.tscn must load")
	var game := scene.instantiate()
	root.add_child(game)
	assert(is_equal_approx(Engine.time_scale, 0.50),
		"The playable Alpha must run at the canonical 50% pace")
	# Ability checks use normal time so their frame budgets remain deterministic.
	Engine.time_scale = 1.0
	await process_frame
	var brutus := game.get_node("Brutus") as BrutusController
	assert(brutus != null, "Brutus controller missing")

	# Ability animation checks must not depend on the live match simulation.
	# Otherwise bots, towers and wave spawns can damage Brutus mid-assertion.
	game.match_over = true
	for actor in get_nodes_in_group("arena_actors"):
		actor.queue_free()
	await process_frame

	brutus.set_virtual_input(Vector2(0, -0.45))
	for _frame in range(24):
		await physics_frame
	assert(brutus.locomotion_animation == &"walk", "Partial analog input must walk")
	var partial_cadence := brutus.animation_player.speed_scale
	brutus.set_virtual_input(Vector2(0, -0.65))
	for _frame in range(24):
		await physics_frame
	assert(brutus.animation_player.speed_scale > partial_cadence,
		"Walk cadence must increase with distance travelled")
	brutus.set_virtual_input(Vector2(0, -1.0))
	for _frame in range(24):
		await physics_frame
	assert(brutus.locomotion_animation == &"run", "Full analog input must run")
	brutus.set_virtual_input(Vector2.ZERO)
	for _frame in range(20):
		await physics_frame

	brutus.request_attack()
	assert(brutus.action_state == &"attack", "First basic hit did not start")
	for _frame in range(12):
		await physics_frame
	brutus.request_attack()
	assert(brutus.attack_queued, "Second basic hit was not queued")
	for _frame in range(100):
		await physics_frame
	assert(brutus.action_state.is_empty(), "Basic two-hit chain did not finish")
	assert(brutus.attack_has_impacted, "Basic attack impact did not fire")
	assert(brutus.attack_combo_index == 0, "Basic attack combo did not alternate clips")

	var health_before_hurt := brutus.health
	brutus.set_virtual_input(Vector2(0, -0.45))
	brutus.take_damage(75.0)
	assert(brutus.health == health_before_hurt - 75.0, "Damage did not reduce Brutus health")
	assert(brutus.action_state == &"hurt", "Non-lethal damage did not play the hurt reaction")
	for _frame in range(20):
		await physics_frame
	assert(brutus.action_state.is_empty(), "Moving hurt reaction did not return to locomotion")
	assert(brutus.locomotion_animation == &"walk", "Hurt recovery did not resume the walk cycle")
	brutus.set_virtual_input(Vector2.ZERO)
	for _frame in range(20):
		await physics_frame

	brutus.request_q()
	assert(brutus.action_state == &"q", "Q did not start")
	for _frame in range(80):
		await physics_frame
	assert(brutus.action_state.is_empty(), "Q did not finish")
	assert(brutus.q_cooldown_left > 0.0, "Q cooldown was not applied")

	brutus.request_r()
	assert(brutus.action_state == &"ultimate", "Ultimate did not start")
	brutus.set_virtual_input(Vector2(0, -1.0))
	for _frame in range(80):
		await physics_frame
	assert(brutus.r_has_impacted, "Ultimate impact did not fire")
	assert(brutus.shield_projectile != null, "Thrown shield projectile was not created")
	assert(not brutus.active_effects.is_empty(), "Ultimate visual effects were not spawned")
	assert(brutus.action_state.is_empty(), "Movement did not cancel the post-release ultimate backswing")
	assert(brutus.locomotion_animation == &"run", "Ultimate recovery did not resume running")
	brutus.set_virtual_input(Vector2.ZERO)
	for _frame in range(70):
		await physics_frame
	assert(brutus.action_state != &"ultimate", "Ultimate did not finish")
	assert(brutus.shield_projectile == null, "Thrown shield did not return")
	assert(brutus.shield_hand_mesh.visible, "Hand shield was not restored")
	print("BRUTUS_ABILITIES_OK")
	quit()
