extends SceneTree

const MODELS := {
	"lyra": "res://assets/roster/lyra.glb",
	"nix": "res://assets/roster/nix.glb",
	"sol": "res://assets/roster/sol.glb",
	"minion_blue": "res://assets/roster/minion_blue.glb",
	"minion_red": "res://assets/roster/minion_red.glb",
}
const HERO_CLIPS := [&"idle", &"run", &"attack", &"q", &"ultimate", &"hurt", &"death"]
const MINION_CLIPS := [&"idle", &"run", &"attack", &"hurt", &"death"]


func _initialize() -> void:
	var errors := 0
	for model_name in MODELS:
		var scene := load(MODELS[model_name]) as PackedScene
		if scene == null:
			push_error("%s model must import" % model_name)
			errors += 1
			continue
		var instance := scene.instantiate()
		root.add_child(instance)
		var player := instance.find_child(
			"AnimationPlayer", true, false) as AnimationPlayer
		if player == null:
			push_error("%s needs an AnimationPlayer" % model_name)
			errors += 1
			instance.queue_free()
			continue
		var expected := MINION_CLIPS if String(model_name).begins_with("minion") \
			else HERO_CLIPS
		for clip_name in expected:
			if not player.has_animation(clip_name):
				push_error("%s is missing %s" % [model_name, clip_name])
				errors += 1
		var meshes := instance.find_children(
			"*", "MeshInstance3D", true, false).size()
		if meshes < 18:
			push_error("%s needs a complete 3D assembly; got %d meshes" \
				% [model_name, meshes])
			errors += 1
		print("ROSTER_MODEL ", model_name, " meshes=", meshes,
			" clips=", Array(player.get_animation_list()))
		instance.queue_free()
	print("ROSTER_FAMILY_IMPORT_OK" if errors == 0 \
		else "ROSTER_FAMILY_IMPORT_FAILED errors=%d" % errors)
	quit()
