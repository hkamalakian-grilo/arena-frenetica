extends SceneTree

const OUTPUT := "res://tools/travessia_capture.png"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(720, 1280)
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null, "main.tscn must load for visual capture")
	var game := scene.instantiate()
	root.add_child(game)
	for _frame in range(8):
		await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT)
	assert(error == OK, "Could not save visual capture")
	print("TRAVESSIA_CAPTURE_OK ", OUTPUT, " ", image.get_width(), "x", image.get_height())
	quit()
