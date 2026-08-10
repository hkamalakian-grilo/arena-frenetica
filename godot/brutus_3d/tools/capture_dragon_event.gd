extends SceneTree

const OUTPUT := "res://tools/travessia_dragon_bridge_capture.png"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(720, 1280)
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null, "main.tscn must load for dragon-event capture")
	var game := scene.instantiate()
	root.add_child(game)
	for _frame in range(8):
		await process_frame
	game.call("_hatch_dragon")
	await create_timer(3.2, true, false, true).timeout
	var image := root.get_texture().get_image()
	assert(image.save_png(OUTPUT) == OK,
		"Could not save dragon bridge capture")
	print("DRAGON_BRIDGE_CAPTURE_OK ", OUTPUT)
	quit()
