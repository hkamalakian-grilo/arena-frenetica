extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null, "main.tscn must load")
	var game := scene.instantiate()
	root.add_child(game)
	assert(is_equal_approx(Engine.time_scale, 0.50),
		"The playable Alpha must run at the canonical 50% pace")
	# Functional checks use normal time so their frame budgets remain deterministic.
	Engine.time_scale = 1.0
	await process_frame
	await physics_frame

	var brutus := game.get_node("Brutus") as BrutusController
	assert(brutus != null, "Integrated Brutus is missing")
	assert(brutus.health == brutus.max_health, "Brutus must start at full health")
	assert(is_equal_approx(brutus.visual_root.scale.x, 0.72),
		"Brutus visual must remain proportional to the full-map camera")
	assert(game.get_node("HUD/BrutusHealth") != null, "Match health HUD is missing")
	assert(not game.get_node("HUD/Title").visible and not game.get_node("HUD/Hint").visible \
		and not game.get_node("HUD/Speed").visible,
		"Clean mobile HUD must hide instructional text during play")
	assert(game.get_node("TravessiaMap") is TravessiaMap, "Canonical Travessia map is missing")
	assert(game.get_node("TravessiaMap/ArenaBounds").get_child_count() == 4,
		"Travessia must contain four arena boundaries")
	assert(game.get_node("CameraRig/Camera3D").size >= 34.0,
		"Portrait camera must frame the complete Travessia map")
	assert(not game.follow_player_camera,
		"Complete-map presentation must not follow and crop around Brutus")
	assert(game.get_node("TravessiaMap/MapArt") is MeshInstance3D,
		"Travessia must use the approved clean map artwork")
	assert(TravessiaDefinition.structures().size() == 6,
		"Travessia data must define two bases and four towers")
	assert(TravessiaDefinition.LANE_X.size() == 2, "Travessia must define two lanes")
	assert(TravessiaDefinition.tower_markers().size() == 4,
		"Travessia must define four pixel-measured tower platforms")
	assert(TravessiaDefinition.main_tower_markers().size() == 2,
		"Travessia must define two pixel-measured main-tower platforms")
	assert(get_nodes_in_group("hero_bots").size() == 3,
		"The match must include Sol, Lyra and Nix alongside Brutus")
	for hero_node in get_nodes_in_group("hero_bots"):
		var hero := hero_node as HeroBot
		assert(hero != null and hero.visual_model is StylizedActor3D,
			"Every roster bot must use a real 3D model")
		assert(hero.find_children("*", "Sprite3D", true, false).is_empty(),
			"Roster heroes must not fall back to camera-facing sprites")

	var actors := get_nodes_in_group("arena_actors")
	assert(actors.size() >= 11, "Travessia must start with bases, towers, dragon and a wave")
	var enemy_tower: ArenaActor
	var enemy_base: ArenaActor
	var blue_minion: ArenaActor
	for node in actors:
		var actor := node as ArenaActor
		if actor == null:
			continue
		if actor.team == 1 and actor.actor_kind == &"tower" and enemy_tower == null:
			enemy_tower = actor
		elif actor.team == 1 and actor.actor_kind == &"base":
			enemy_base = actor
		elif actor.team == 0 and actor.actor_kind == &"minion" and blue_minion == null:
			blue_minion = actor
	assert(enemy_tower != null and enemy_base != null, "Enemy structures are missing")
	assert(blue_minion != null, "Initial blue minion is missing")
	assert(blue_minion.actor_model is StylizedActor3D,
		"Minions must use the reusable 3D actor model")
	assert(blue_minion.find_children("*", "MeshInstance3D", true, false).size() >= 8,
		"Minion 3D model is incomplete")

	brutus.global_position = Vector3(100.0, 0.0, 100.0)
	await physics_frame
	assert(absf(brutus.global_position.x) <= TravessiaDefinition.PLAYABLE_HALF_EXTENTS.x \
		and absf(brutus.global_position.z) <= TravessiaDefinition.PLAYABLE_HALF_EXTENTS.y,
		"Brutus escaped the canonical playable area")
	brutus.global_position = TravessiaDefinition.PLAYER_SPAWN
	assert(enemy_base.get_is_protected(), "Enemy base must start protected by both towers")

	var lane_x := blue_minion.global_position.x
	var start_z := blue_minion.global_position.z
	for _frame in range(45):
		await physics_frame
	assert(is_equal_approx(blue_minion.global_position.x, lane_x), "Minion left its straight lane")
	assert(blue_minion.global_position.z < start_z, "Blue minion did not advance toward the enemy tower")
	assert(blue_minion.objective != null, "Minion did not acquire a structure objective")
	var objective_actor := blue_minion.objective as ArenaActor
	assert(objective_actor != null and objective_actor.actor_kind == &"tower",
		"Minion must focus the lane tower before the base")

	# Tower damage is represented by a travelling projectile instead of an
	# invisible instant health subtraction.
	blue_minion.global_position = enemy_tower.global_position + Vector3(0, 0, 2.0)
	enemy_tower.objective = blue_minion
	enemy_tower.attack_timer = 0.0
	var minion_health_before_shot := blue_minion.health
	enemy_tower.call("_process_guardian")
	assert(game.find_child("TowerProjectile", true, false) != null,
		"Tower did not create a visible projectile")
	assert(blue_minion.health == minion_health_before_shot,
		"Tower damage landed before its projectile arrived")
	for _frame in range(20):
		await physics_frame
	assert(blue_minion.health < minion_health_before_shot,
		"Tower projectile did not damage its target on arrival")

	var tower_health := enemy_tower.health
	game.call("_damage_enemies", enemy_tower.global_position, 1.5, 100.0)
	assert(enemy_tower.health == tower_health - 100.0, "Brutus combat damage did not reach structures")

	var protected_base_health := enemy_base.health
	enemy_base.take_damage(100.0)
	assert(enemy_base.health == protected_base_health, "Protected base received damage")
	enemy_tower.take_damage(enemy_tower.max_health)
	await process_frame
	assert(not enemy_base.get_is_protected(), "Base did not open after the first tower fell")
	enemy_base.take_damage(enemy_base.max_health)
	await process_frame
	assert(game.match_over, "Destroying the enemy base did not finish the match")
	assert(game.status_label.text == "VITORIA!", "Victory announcement is missing")
	print("ARENA_MATCH_OK actors=", actors.size(), " straight_lane=true combat=true victory=true")
	quit()
