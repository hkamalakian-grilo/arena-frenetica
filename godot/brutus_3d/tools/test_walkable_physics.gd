extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(TravessiaDefinition.is_walkable(Vector2(-5.35, 0.0)),
		"The western lane bridge must be walkable")
	assert(TravessiaDefinition.is_walkable(Vector2(5.35, 0.0)),
		"The eastern lane bridge must be walkable")
	assert(TravessiaDefinition.is_walkable(Vector2(-1.5, 12.2)),
		"The allied base must be walkable")
	assert(TravessiaDefinition.is_walkable(Vector2(0.0, 7.0)),
		"The central approach must be walkable")
	assert(TravessiaDefinition.is_walkable(Vector2(0.0, -10.45)),
		"The northern base must connect to the middle lane")
	assert(TravessiaDefinition.is_walkable(Vector2(0.0, 10.45)),
		"The southern base must connect to the middle lane")
	assert(TravessiaDefinition.is_walkable(Vector2(0.0, -4.0)),
		"The middle lane must reach the northern river gate")
	assert(TravessiaDefinition.is_walkable(Vector2(0.0, 4.0)),
		"The middle lane must reach the southern river gate")
	assert(not TravessiaDefinition.is_walkable(Vector2(0.0, -15.20)),
		"The northern base wall must block movement")
	assert(not TravessiaDefinition.is_walkable(Vector2(0.0, 15.20)),
		"The southern base wall must block movement")
	assert(not TravessiaDefinition.is_walkable(Vector2(-7.20, -11.50)),
		"The curved north-west wall corner must block movement")
	assert(not TravessiaDefinition.is_walkable(Vector2(7.20, 11.50)),
		"The curved south-east wall corner must block movement")
	assert(not TravessiaDefinition.is_walkable(Vector2(0.0, 0.0)),
		"The dragon island must be inaccessible before hatching")
	assert(not TravessiaDefinition.is_walkable(Vector2(3.0, 0.0)),
		"River water outside a bridge must block movement")
	assert(not TravessiaDefinition.is_walkable(Vector2(-4.30, 0.0)),
		"Water immediately beside the western bridge must block movement")
	assert(not TravessiaDefinition.is_walkable(Vector2(3.0, 6.0)),
		"Decorative jungle outside the paths must block movement")
	assert(TravessiaDefinition.is_walkable(Vector2(-4.0, -7.5)),
		"The cleared upper-left jungle corridor must be walkable")
	assert(not TravessiaDefinition.is_walkable(Vector2(-2.60, -7.50)),
		"The camp stone ring must remain outside the cleared corridor")
	assert(not TravessiaDefinition.is_walkable(Vector2(30.0, 30.0)),
		"The exterior of the arena must block movement")

	var lane_start := Vector3(-5.35, 0.0, -2.0)
	var attempted_water := Vector3(-3.0, 0.0, -1.4)
	var lane_slide := TravessiaDefinition.constrain_walkable_motion(
		lane_start, attempted_water)
	assert(TravessiaDefinition.is_walkable(
		Vector2(lane_slide.x, lane_slide.z)),
		"Lane collision resolution returned a blocked point")
	assert(is_equal_approx(lane_slide.x, lane_start.x),
		"Diagonal movement must slide along the lane instead of entering water")
	assert(lane_slide.z > lane_start.z,
		"Lane edge must preserve the valid movement axis")

	var recovered := TravessiaDefinition.constrain_walkable_motion(
		Vector3(100.0, 0.0, 100.0), Vector3(100.0, 0.0, 100.0))
	assert(TravessiaDefinition.is_walkable(Vector2(recovered.x, recovered.z)),
		"An actor outside the arena was not recovered to walkable ground")

	var game := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var brutus := game.get_node("Brutus") as BrutusController
	var arena_map := game.get_node("TravessiaMap") as TravessiaMap
	assert(brutus != null and arena_map != null)

	brutus.global_position = Vector3(-5.35, 0.0, 0.0)
	brutus.set_virtual_input(Vector2(1.0, 0.0))
	for _frame in range(90):
		await physics_frame
	brutus.set_virtual_input(Vector2.ZERO)
	assert(TravessiaDefinition.is_walkable(
		Vector2(brutus.global_position.x, brutus.global_position.z), false,
		brutus.movement_collision_radius),
		"Brutus escaped the western bridge into the river")
	assert(brutus.global_position.x < -4.30,
		"Brutus crossed the physical edge of the western lane")

	brutus.global_position = Vector3(-4.90, 0.0, 0.0)
	brutus.last_direction = Vector3.RIGHT
	brutus.request_q()
	for _frame in range(70):
		await physics_frame
	assert(brutus.global_position.x < -4.80,
		"Brutus charge escaped from the side of the western bridge")
	assert(TravessiaDefinition.is_walkable(
		Vector2(brutus.global_position.x, brutus.global_position.z), false,
		brutus.movement_collision_radius),
		"Bridge ability movement ended over water")

	brutus.global_position = Vector3(-4.45, 0.0, -2.0)
	brutus.q_cooldown_left = 0.0
	brutus.last_direction = Vector3.RIGHT
	brutus.request_q()
	for _frame in range(70):
		await physics_frame
	assert(TravessiaDefinition.is_walkable(
		Vector2(brutus.global_position.x, brutus.global_position.z), false,
		brutus.movement_collision_radius),
		"Brutus charge crossed a lane boundary")
	assert(brutus.global_position.x < -4.30,
		"Ability movement bypassed the lane collision")

	brutus.global_position = Vector3(-6.40, 0.0, -12.0)
	brutus.set_virtual_input(Vector2(-1.0, 0.0))
	for _frame in range(90):
		await physics_frame
	brutus.set_virtual_input(Vector2.ZERO)
	assert(TravessiaDefinition.is_walkable(
		Vector2(brutus.global_position.x, brutus.global_position.z), false,
		brutus.movement_collision_radius),
		"Brutus crossed the curved north-west base wall")

	brutus.global_position = Vector3(-5.35, 0.0, -7.50)
	brutus.set_virtual_input(Vector2(1.0, 0.0))
	for _frame in range(90):
		await physics_frame
	brutus.set_virtual_input(Vector2.ZERO)
	assert(brutus.global_position.x > -4.0,
		"Brutus could not enter the cleared upper-left jungle corridor")
	assert(TravessiaDefinition.is_walkable(
		Vector2(brutus.global_position.x, brutus.global_position.z), false,
		brutus.movement_collision_radius),
		"Brutus left the authored cleared corridor")

	for node in get_nodes_in_group("hero_bots"):
		var bot := node as HeroBot
		assert(bot != null and TravessiaDefinition.is_walkable(
			Vector2(bot.global_position.x, bot.global_position.z)),
			"A hero bot left the physical movement mask")

	brutus.global_position = Vector3(0.0, 0.0, 0.0)
	await physics_frame
	assert(TravessiaDefinition.is_walkable(
		Vector2(brutus.global_position.x, brutus.global_position.z), false,
		brutus.movement_collision_radius),
		"Brutus remained standing in water before the dragon bridge opened")
	assert(not arena_map.is_dragon_access_open(),
		"Dragon access opened before the hatch event")

	game.call("_hatch_dragon")
	await physics_frame
	assert(not arena_map.is_dragon_access_open(),
		"Dragon access opened before the bridge construction finished")
	await create_timer(3.0, true, false, true).timeout
	assert(arena_map.is_dragon_access_open(),
		"Dragon access did not become walkable after bridge construction")
	assert(TravessiaDefinition.is_walkable(Vector2(0.0, -3.0), true),
		"The northern dragon bridge must be walkable after hatching")
	assert(TravessiaDefinition.is_walkable(Vector2.ZERO, true),
		"The dragon island must be walkable after hatching")
	assert(not TravessiaDefinition.is_walkable(Vector2(3.0, 0.0), true),
		"Opening the dragon bridge must not make the whole river walkable")

	print("WALKABLE_PHYSICS_OK lanes=true water_blocked=true bounds=true dragon_gate=true")
	game.queue_free()
	quit()
