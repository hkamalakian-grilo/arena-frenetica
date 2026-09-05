extends SceneTree

## Captures a frame with damage numbers, a stunned enemy and the hurt flash so
## the feedback layer can be reviewed without a device.

const OUTPUT := "res://tools/travessia_game_feel_capture.png"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(720, 1280)
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null, "main.tscn must load for the game-feel capture")
	var game := scene.instantiate()
	root.add_child(game)
	Engine.time_scale = 1.0
	for _frame in range(8):
		await process_frame
	var brutus := game.get_node("Brutus") as BrutusController
	var lane := Vector3(TravessiaDefinition.LANE_X[0], 0.0, 4.0)
	brutus.global_position = lane
	brutus.last_direction = Vector3(0, 0, -1)
	for index in range(3):
		var data := TravessiaDefinition.minion(1, lane.x)
		var at := lane + Vector3(-0.6 + 0.6 * index, 0.0, -1.4 - 0.5 * index)
		data.position = at
		var minion: ArenaActor = game.call("_spawn_actor", data, at)
		minion.attack_damage = 0.0
	await physics_frame
	brutus.request_q()
	for _frame in range(48):
		await physics_frame
	brutus.take_damage(260.0)
	# Show the manual-aim preview, a radial cooldown and the advantage line.
	brutus.show_aim_preview(&"r", Vector3(0.4, 0.0, -1.0))
	var r_button := game.get_node("HUD/RButton") as AbilityButton
	r_button.call("_press", 1, Vector2(50, 50))
	r_button.call("_drag", Vector2(90, -60))
	game.team_towers_destroyed = [1, 0]
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	assert(image.save_png(OUTPUT) == OK, "Could not save game-feel capture")
	print("GAME_FEEL_CAPTURE_OK ", OUTPUT)
	quit()
