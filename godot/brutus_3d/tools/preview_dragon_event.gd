extends SceneTree

## Manual visual preview for the complete egg-to-dragon transition.
## Run with:
## godot --path godot/brutus_3d --script res://tools/preview_dragon_event.gd


func _initialize() -> void:
	call_deferred("_run_preview")


func _run_preview() -> void:
	root.size = Vector2i(720, 1280)
	var scene := load("res://main.tscn") as PackedScene
	while true:
		var game := scene.instantiate()
		root.add_child(game)
		await create_timer(2.0, true, false, true).timeout
		game.match_time = float(game.match_rules.match_duration) \
			- float(game.match_rules.dragon_hatch_remaining)
		game.call("_hatch_dragon")
		await create_timer(5.0, true, false, true).timeout
		game.queue_free()
		await process_frame
