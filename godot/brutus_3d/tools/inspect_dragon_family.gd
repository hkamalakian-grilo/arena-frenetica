extends SceneTree

const MODELS := {
	"dragon": "res://assets/dragon/dragon_3d.glb",
	"egg": "res://assets/dragon/dragon_egg_3d.glb",
}


func _initialize() -> void:
	for label in MODELS:
		var scene := load(MODELS[label]) as PackedScene
		assert(scene != null, "%s model must import" % label)
		var instance := scene.instantiate()
		root.add_child(instance)
		var player := instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert(player != null, "%s needs an AnimationPlayer" % label)
		var clips := Array(player.get_animation_list())
		var mesh_count := instance.find_children("*", "MeshInstance3D", true, false).size()
		print("DRAGON_FAMILY_MODEL ", label, " meshes=", mesh_count, " clips=", clips)
		instance.queue_free()
	quit()
