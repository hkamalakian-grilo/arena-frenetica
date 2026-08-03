extends SceneTree

func _initialize() -> void:
	var packed := load("res://assets/brutus/brutus.glb") as PackedScene
	assert(packed != null, "brutus.glb was not imported as a PackedScene")
	var model := packed.instantiate()
	root.add_child(model)
	_print_tree(model, "")
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert(not players.is_empty(), "The imported Brutus has no AnimationPlayer")
	for player: AnimationPlayer in players:
		print("ANIMATIONS=", player.get_animation_list())
		assert(player.has_animation("idle"), "Missing idle animation")
		assert(player.has_animation("walk"), "Missing walk animation")
		assert(player.has_animation("run"), "Missing run animation")
		assert(player.has_animation("attack"), "Missing attack animation")
		assert(player.has_animation("attack_alt"), "Missing alternate basic attack animation")
		assert(player.has_animation("hurt"), "Missing damage reaction animation")
		assert(player.has_animation("death"), "Missing death animation")
		assert(player.has_animation("q"), "Missing Q/Investida animation")
		assert(player.has_animation("ultimate"), "Missing R/Escudo Bumerangue animation")
	print("BRUTUS_IMPORT_OK")
	quit()

func _print_tree(node: Node, indent: String) -> void:
	print(indent, node.name, " <", node.get_class(), ">")
	for child in node.get_children():
		_print_tree(child, indent + "  ")
