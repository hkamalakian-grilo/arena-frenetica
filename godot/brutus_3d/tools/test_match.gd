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
	assert(brutus.collision_layer == 2 and brutus.collision_mask == 1,
		"Brutus must collide only with the map layer")
	assert(is_equal_approx(brutus.visual_root.scale.x, 0.56),
		"Brutus visual must remain proportional to the full-map camera")
	var brutus_shape := game.get_node("Brutus/CollisionShape3D").shape \
		as CapsuleShape3D
	assert(brutus_shape != null and is_equal_approx(brutus_shape.radius, 0.34),
		"Brutus collision capsule must match his reduced presentation")
	assert(game.get_node("HUD/BrutusHealth") != null, "Match health HUD is missing")
	assert(game.get_node("HUD/MatchStatus").text.begins_with("03:00"),
		"Match countdown must start at 03:00")
	assert(not game.get_node("HUD/Title").visible and not game.get_node("HUD/Hint").visible \
		and not game.get_node("HUD/Speed").visible,
		"Clean mobile HUD must hide instructional text during play")
	var q_button := game.get_node("HUD/QButton") as Button
	var q_button_style := q_button.get_theme_stylebox("normal") as StyleBoxFlat
	assert(q_button.offset_left == -260.0 and q_button.offset_right == -134.0,
		"Q button must not overlap the lower main tower")
	assert(q_button_style != null and q_button_style.corner_radius_top_left == 64,
		"Ability controls must use circular backgrounds instead of dark rectangles")
	assert(game.get_node("TravessiaMap") is TravessiaMap, "Canonical Travessia map is missing")
	assert(game.get_node("TravessiaMap/ArenaBounds").get_child_count() == 4,
		"Travessia must contain four arena boundaries")
	assert(is_equal_approx(game.get_node("CameraRig/Camera3D").size, 37.0),
		"Portrait camera must preserve vertical safety around the main towers")
	assert(not game.follow_player_camera,
		"Complete-map presentation must not follow and crop around Brutus")
	var terrain_art := game.get_node(
		"TravessiaMap/TerrainLayer/TerrainArt") as MeshInstance3D
	assert(terrain_art != null, "Travessia 2.5D terrain layer is missing")
	assert(game.get_node("TravessiaMap").uses_canonical_2_5d_art(),
		"Travessia must preserve the approved artwork in its 2.5D presentation")
	var terrain_mesh := terrain_art.mesh as PlaneMesh
	assert(terrain_mesh != null and terrain_mesh.subdivide_width >= 95 \
		and terrain_mesh.subdivide_depth >= 191,
		"Travessia terrain must have enough geometry for authored relief")
	var terrain_material := terrain_art.material_override as ShaderMaterial
	var terrain_texture := terrain_material.get_shader_parameter("terrain_texture") \
		as Texture2D
	var height_texture := terrain_material.get_shader_parameter("height_texture") \
		as Texture2D
	assert(terrain_texture.resource_path.ends_with(
		"travessia_terrain_v6.png"),
		"Travessia 2.5D must keep the approved terrain artwork")
	assert(height_texture.resource_path.ends_with("travessia_depth_v1.png"),
		"Travessia 2.5D must use the aligned authored height map")
	var upper_left_camp := game.get_node(
		"TravessiaMap/StaticProps/JungleModules/UpperLeftCamp") \
		as MeshInstance3D
	assert(upper_left_camp != null,
		"The first separated jungle camp module must exist")
	var camp_material := upper_left_camp.material_override as ShaderMaterial
	var camp_texture := camp_material.get_shader_parameter("module_texture") \
		as Texture2D
	assert(camp_texture.resource_path.ends_with("upper_left_camp_full_v1.png"),
		"The separated camp must use untouched pixels from the approved map")
	var jungle_modules := game.get_node(
		"TravessiaMap/StaticProps/JungleModules") as Node3D
	assert(jungle_modules.get_child_count() == 4,
		"All four jungle camps must be independent 2.5D modules")
	for camp_name in ["UpperLeftCamp", "UpperRightCamp", "LowerLeftCamp",
			"LowerRightCamp"]:
		var camp_module := jungle_modules.get_node(camp_name) as MeshInstance3D
		assert(camp_module != null and camp_module.get_meta("module_kind") \
			== &"jungle_camp", "Every jungle camp must expose a stable module")
	var map_art_modules := game.get_node(
		"TravessiaMap/StaticProps/MapArtModules") as Node3D
	assert(map_art_modules != null and map_art_modules.get_child_count() == 9,
		"Travessia must expose all nine independent environment modules")
	var expected_map_modules := {
		"NorthBoundary": &"boundary",
		"SouthBoundary": &"boundary",
		"WestOuterForest": &"outer_forest",
		"EastOuterForest": &"outer_forest",
		"NorthRiverBank": &"river_bank",
		"SouthRiverBank": &"river_bank",
		"DragonIsland": &"dragon_island",
		"LeftLaneBridge": &"lane_bridge",
		"RightLaneBridge": &"lane_bridge",
	}
	for module_name in expected_map_modules:
		var map_module := map_art_modules.get_node(module_name) as MeshInstance3D
		assert(map_module != null and map_module.get_meta("module_kind") \
			== expected_map_modules[module_name],
			"Every environment section must expose a stable 2.5D module")
	assert(game.get_node("TravessiaMap/StaticProps/TowerPlatforms").get_child_count() == 4,
		"Every lane tower must have an independent movable platform")
	assert(game.get_node("TravessiaMap/DynamicProps") is Node3D,
		"Travessia dynamic-prop layer is missing")
	assert(TravessiaDefinition.structures().size() == 6,
		"Travessia data must define two bases and four towers")
	assert(TravessiaDefinition.LANE_X.size() == 2, "Travessia must define two lanes")
	assert(TravessiaDefinition.tower_markers().size() == 4,
		"Travessia must define four pixel-measured tower platforms")
	assert(TravessiaDefinition.main_tower_markers().size() == 2,
		"Travessia must define two pixel-measured main-tower platforms")
	assert(is_equal_approx(float(game.match_rules.match_duration), 180.0),
		"Canonical match duration must be three minutes")
	assert(is_equal_approx(float(game.match_rules.dragon_hatch_remaining), 60.0),
		"Dragon must hatch with one minute remaining")
	assert(get_nodes_in_group("hero_bots").size() == 3,
		"The match must include Sol, Lyra and Nix alongside Brutus")
	for hero_node in get_nodes_in_group("hero_bots"):
		var hero := hero_node as HeroBot
		assert(hero != null and hero.visual_model is StylizedActor3D,
			"Every roster bot must use a real 3D model")
		assert(hero.collision_layer == 2 and hero.collision_mask == 1,
			"Hero bots must collide only with the map layer")
		assert(hero.find_children("*", "Sprite3D", true, false).is_empty(),
			"Roster heroes must not fall back to camera-facing sprites")

	var actors := get_nodes_in_group("arena_actors")
	assert(actors.size() >= 11, "Travessia must start with bases, towers, egg and a wave")
	var enemy_tower: ArenaActor
	var enemy_base: ArenaActor
	var blue_minion: ArenaActor
	var red_minion: ArenaActor
	var dragon_egg: ArenaActor
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
		elif actor.team == 1 and actor.actor_kind == &"minion" and red_minion == null:
			red_minion = actor
		elif actor.actor_kind == &"dragon_egg":
			dragon_egg = actor
	assert(enemy_tower != null and enemy_base != null, "Enemy structures are missing")
	for actor_node in actors:
		var main_tower := actor_node as ArenaActor
		if main_tower == null or main_tower.actor_kind != &"base":
			continue
		var expected_art_y := 1.62 if main_tower.team == 0 else 1.45
		assert(main_tower.actor_art != null \
			and is_equal_approx(main_tower.actor_art.pixel_size, 0.0047) \
			and is_equal_approx(main_tower.actor_art.position.y, expected_art_y),
			"Both main towers must fit and remain grounded on their circular markers")
		assert(is_equal_approx(main_tower.health_backdrop.position.y, 4.45),
			"Main-tower health bars must follow the corrected visual height")
	assert(enemy_tower.actor_art != null \
		and is_equal_approx(enemy_tower.actor_art.pixel_size, 0.00355) \
		and is_equal_approx(enemy_tower.actor_art.position.y, 1.24),
		"Lane tower art must fill its platform without moving its ground pivot")
	assert(blue_minion != null and red_minion != null, "Initial lane minions are missing")
	assert(blue_minion.collision_layer == 2 and blue_minion.collision_mask == 1,
		"Minions must collide only with the map layer")
	assert((blue_minion.collision_mask & brutus.collision_layer) == 0 \
		and (brutus.collision_mask & blue_minion.collision_layer) == 0,
		"Characters and minions must not physically collide with each other")
	assert(dragon_egg != null, "Dragon egg must be present when the match starts")
	assert(not dragon_egg.is_targetable(), "Dragon egg must not be targetable before hatching")
	assert(dragon_egg.actor_art != null and dragon_egg.actor_art.texture.resource_path \
		.ends_with("dragon_egg_purple_v1.png"),
		"Dragon egg must use the approved transparent authored artwork")
	assert(is_equal_approx(dragon_egg.actor_art.pixel_size, 0.00210),
		"Dragon egg artwork must remain proportional to the central island")
	assert(game.find_children("*", "ArenaActor", true, false).all(
		func(actor: ArenaActor) -> bool: return actor.actor_kind != &"dragon"),
		"Dragon must not exist before the egg hatches")
	assert(blue_minion.actor_model is StylizedActor3D,
		"Minions must use the reusable 3D actor model")
	assert(blue_minion.find_children("*", "MeshInstance3D", true, false).size() >= 8,
		"Minion 3D model is incomplete")

	var enemy_tower_id: StringName = enemy_tower.get_meta("structure_id", &"")
	var enemy_platform: Node3D = game.arena_map.get_tower_platform(enemy_tower_id)
	assert(enemy_tower_id != &"" and enemy_platform != null,
		"Lane tower is not linked to its modular platform")
	var original_tower_position := enemy_tower.global_position
	var moved_tower_position := original_tower_position + Vector3(0.35, 0, 0.25)
	assert(game.move_lane_tower(enemy_tower_id, moved_tower_position),
		"Moving a data-driven lane tower failed")
	assert(enemy_tower.global_position.is_equal_approx(moved_tower_position),
		"Lane tower actor did not move to the requested position")
	assert(is_equal_approx(enemy_platform.position.x, moved_tower_position.x) \
		and is_equal_approx(enemy_platform.position.z, moved_tower_position.z),
		"Tower platform did not move together with its tower")
	assert(game.move_lane_tower(enemy_tower_id, original_tower_position),
		"Lane tower could not be restored after the modularity check")

	game.call("_hatch_dragon")
	await process_frame
	assert(game.dragon_hatched, "Dragon hatch state was not activated")
	assert(not is_instance_valid(dragon_egg), "Dragon egg was not removed after hatching")
	var dragon := game.find_children("*", "ArenaActor", true, false).filter(
		func(actor: ArenaActor) -> bool: return actor.actor_kind == &"dragon")
	assert(dragon.size() == 1, "Exactly one dragon must spawn after hatching")
	assert(game.get_node_or_null(
		"TravessiaMap/DynamicProps/DragonAccessBridges") != null,
		"Central access bridges were not created during the hatch event")
	var open_island_material := game.arena_map.dragon_island_module \
		.material_override as ShaderMaterial
	var open_island_texture := open_island_material.get_shader_parameter(
		"module_texture") as Texture2D
	assert(open_island_texture.resource_path.ends_with(
		"dragon_island_open_full_v1.png"),
		"Dragon hatch must switch the island to its open-entrance layer")
	assert(not game.arena_map.is_dragon_access_open(),
		"Dragon access must remain blocked while the bridges are assembling")
	await create_timer(1.5).timeout
	var north_bridge := game.get_node(
		"TravessiaMap/DynamicProps/DragonAccessBridges/NorthBridge") \
		as ModularBridge3D
	var south_bridge := game.get_node(
		"TravessiaMap/DynamicProps/DragonAccessBridges/SouthBridge") \
		as ModularBridge3D
	assert(north_bridge != null and south_bridge != null,
		"Dragon connections must instantiate the reusable 3D bridge scene")
	assert(north_bridge.get_row_count() == 4 and south_bridge.get_row_count() == 4,
		"Both dragon bridges must preserve the approved four-course masonry")
	for bridge: ModularBridge3D in [north_bridge, south_bridge]:
		assert(bridge.is_fully_revealed(),
			"A modular 3D bridge did not finish assembling toward the dragon")
		assert(bridge.get_node_or_null("DeckRows") != null,
			"Modular bridge is missing its physical stone rows")
		assert(bridge.get_node_or_null("BridgeCollision") != null,
			"Modular bridge is missing its independent collision")
		assert(is_equal_approx(bridge.bridge_width,
			TravessiaMap.DRAGON_BRIDGE_WIDTH),
			"Dragon bridges must keep the canonical full width")
		assert(bridge.is_collision_enabled(),
			"Bridge collision must activate after the final masonry row")
	assert(game.arena_map.is_dragon_access_open(),
		"Dragon access must open after both bridges finish assembling")
	assert(north_bridge.position.z < 0.0 \
		and north_bridge.row_nodes[0].position.z > 0.0,
		"North modular bridge must assemble south toward the dragon")
	assert(is_equal_approx(north_bridge.start_width_scale,
		TravessiaMap.NORTH_BRIDGE_START_SCALE)
		and is_equal_approx(north_bridge.end_width_scale, 1.0),
		"North bridge must widen subtly toward the closer island edge")
	assert(is_equal_approx(south_bridge.start_width_scale, 1.0)
		and is_equal_approx(south_bridge.end_width_scale, 1.0),
		"Approved south bridge perspective must remain unchanged")
	assert(south_bridge.position.z > 0.0 \
		and south_bridge.row_nodes[0].position.z < 0.0,
		"South modular bridge must assemble north toward the dragon")

	brutus.global_position = Vector3(100.0, 0.0, 100.0)
	await physics_frame
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
		"Minion must use the lane tower when no enemy unit is nearby")

	# Unit targeting overrides the current tower objective without introducing
	# lateral movement. Minions and heroes both have priority over structures.
	var blue_position := blue_minion.global_position
	var red_position := red_minion.global_position
	red_minion.global_position = blue_position + Vector3(0.0, 0.0, -2.4)
	blue_minion.objective = enemy_tower
	blue_minion.call("_process_minion")
	assert(blue_minion.objective == red_minion,
		"Nearby enemy minion must have priority over the lane tower")

	var enemy_hero: HeroBot
	for hero_node in get_nodes_in_group("hero_bots"):
		var hero := hero_node as HeroBot
		if hero != null and hero.team == 1:
			enemy_hero = hero
			break
	assert(enemy_hero != null, "Enemy hero required for minion priority test is missing")
	var hero_position := enemy_hero.global_position
	red_minion.global_position = blue_position + Vector3(0.0, 0.0, -8.0)
	enemy_hero.global_position = blue_position + Vector3(0.0, 0.0, -2.2)
	blue_minion.objective = enemy_tower
	blue_minion.call("_process_minion")
	assert(blue_minion.objective == enemy_hero,
		"Nearby enemy hero must have priority over the lane tower")

	enemy_hero.global_position = hero_position
	red_minion.global_position = red_position
	blue_minion.global_position = blue_position
	blue_minion.objective = null

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
