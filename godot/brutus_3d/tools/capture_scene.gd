extends SceneTree

const DEFAULT_OUTPUT := "res://tools/travessia_capture.png"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var width := 720
	var height := 1280
	var output := DEFAULT_OUTPUT
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		width = maxi(1, int(args[0]))
		height = maxi(1, int(args[1]))
	if args.size() >= 3:
		output = args[2]
	root.size = Vector2i(width, height)
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null, "main.tscn must load for visual capture")
	var game := scene.instantiate()
	root.add_child(game)
	for _frame in range(8):
		await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(output)
	assert(error == OK, "Could not save visual capture")
	print("TRAVESSIA_CAPTURE_OK ", output, " ", image.get_width(), "x", image.get_height())
	quit()
