extends SceneTree

const OUTPUT := "res://tools/travessia_roster_showcase.png"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(720, 1280)
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _frame in range(8):
		await process_frame
	# Frame the line-up with a fixed close camera instead of following Brutus.
	game.follow_player_camera = false
	game.get_node("CameraRig").global_position = Vector3(0, 0, -0.4)
	var camera := game.get_node("CameraRig/Camera3D") as Camera3D
	camera.size = 9.0
	if is_instance_valid(game.dragon_egg):
		game.dragon_egg.queue_free()
	var showcase := [
		Vector3(-2.15, 0, 0.8), Vector3(-0.72, 0, 0.8),
		Vector3(0.72, 0, 0.8), Vector3(2.15, 0, 0.8),
	]
	game.brutus.global_position = showcase[0]
	game.brutus.set_physics_process(false)
	for index in range(game.hero_bots.size()):
		var hero: HeroBot = game.hero_bots[index]
		hero.global_position = showcase[index + 1]
		hero.set_physics_process(false)
		hero.visual_model.face_direction(Vector3(0, 0, -1))
	var minion_index := 0
	for node in get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor == null or actor.actor_kind != &"minion" or minion_index >= 2:
			continue
		actor.global_position = Vector3(-0.9 + minion_index * 1.8, 0, -1.5)
		actor.set_physics_process(false)
		actor.actor_model.face_direction(Vector3(0, 0, -1))
		minion_index += 1
	for _frame in range(5):
		await process_frame
	game.get_node("CameraRig").global_position = Vector3(0, 0, -0.4)
	camera.size = 9.0
	await process_frame
	var image := root.get_texture().get_image()
	assert(image.save_png(OUTPUT) == OK, "Could not save roster showcase")
	print("ROSTER_SHOWCASE_OK ", OUTPUT)
	quit()
