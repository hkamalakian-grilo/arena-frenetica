extends SceneTree

## Captures the whole-map view (minimap tap / Tab) for reviewing the block map.

const OUTPUT := "res://tools/travessia_full_map_capture.png"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(720, 1280)
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	Engine.time_scale = 1.0
	for _frame in range(8):
		await process_frame
	game.set_full_map_view(true)
	await create_timer(0.7, true, false, true).timeout
	var image := root.get_texture().get_image()
	assert(image.save_png(OUTPUT) == OK, "Could not save full-map capture")
	print("FULL_MAP_CAPTURE_OK ", OUTPUT)
	quit()
