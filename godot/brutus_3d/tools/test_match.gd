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
	var clock_before: float = game.match_time
	await create_timer(0.24, true, false, true).timeout
	var real_clock_advance: float = game.match_time - clock_before
	assert(real_clock_advance >= 0.18 and real_clock_advance <= 0.55,
		"Match clock must advance in real time instead of taking six minutes")
	game.match_time = 0.0
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
	assert(game.get_node("HUD/MatchStatus").text.contains("03:00"),
		"Match countdown must start at 03:00")
	assert(game.get_node("HUD/BrutusHealthText") != null,
		"Brutus health bar must have a readable label")
	assert(game.get_node("HUD/EndOverlay") != null,
		"A complete post-match overlay is missing")
	assert(not game.get_node("HUD/Title").visible and not game.get_node("HUD/Hint").visible \
		and not game.get_node("HUD/Speed").visible,
		"Clean mobile HUD must hide instructional text during play")
	var q_button := game.get_node("HUD/QButton") as Button
	var q_button_style := q_button.get_theme_stylebox("normal") as StyleBoxFlat
	assert(q_button.offset_left == -244.0 and q_button.offset_right == -140.0,
		"Q button must not overlap the lower main tower")
	assert(q_button_style != null and q_button_style.corner_radius_top_left == 64,
		"Ability controls must use circular backgrounds instead of dark rectangles")
	assert(game.get_node("TravessiaMap") is TravessiaMap, "Canonical Travessia map is missing")
	assert(game.get_node("TravessiaMap/ArenaBounds").get_child_count() == 4,
		"Travessia must contain four arena boundaries")
	assert(is_equal_approx(game.get_node("CameraRig/Camera3D").size, 14.0),
		"Brawler camera must stay close to the action")
	assert(game.follow_player_camera,
		"Close camera must follow Brutus; the minimap covers the overview")
	assert(game.get_node("HUD/Minimap") is Minimap, "Minimap is missing from the HUD")
	brutus.global_position = Vector3(-8.0, 0.0, -16.0)
	game.snap_camera_to_player()
	var rig := game.get_node("CameraRig") as Node3D
	assert(absf(rig.global_position.x) <= 5.0 + 0.01 and rig.global_position.z >= -8.4 - 0.01,
		"Camera rig must clamp so the map edge never shows")
	brutus.global_position = TravessiaDefinition.PLAYER_SPAWN
	game.snap_camera_to_player()
	var outlined := 0
	for child in brutus.visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
			continue
		var material := mesh_instance.get_active_material(0) as ShaderMaterial
		if material != null and material.shader != null 				and material.shader.code.contains("void light()") 				and material.next_pass is ShaderMaterial:
			outlined += 1
	assert(outlined > 0, "Brutus must use cel lighting with an outline pass")
	assert(brutus.get_node_or_null("BlobShadow") != null, "Brutus needs a ground blob shadow")
	# Block-kit presentation: the map is instanced from assets/kit/map_kit.glb
	# on a grid derived from the walkable mask, with real light and shadow.
	assert(game.arena_map.uses_block_kit(), "Travessia must be built from the 3D block kit")
	var block_map: BlockMap = game.arena_map.block_map
	assert(block_map != null and block_map.piece_names().size() >= 14,
		"The map kit must load every authored piece")
	for piece_name in ["tile_grass", "tile_road", "tile_water", "tile_bridge", "bush",
			"tree_round", "wall_stone"]:
		assert(block_map.get_node_or_null(piece_name) is MultiMeshInstance3D,
			"Block map must instance %s" % piece_name)
	assert(block_map.count_cells(BlockMap.Cell.ROAD) > 300
		and block_map.count_cells(BlockMap.Cell.WATER) > 80
		and block_map.count_cells(BlockMap.Cell.BRIDGE) >= 12,
		"Grid classification must produce roads, water and bridges")
	assert(block_map.get_node("TowerPlatforms").get_child_count() == 4,
		"Every lane tower must have an independent movable platform")
	assert(block_map.get_node("DragonGates").get_child_count() >= 4,
		"The island must have removable gate blocks")
	assert(game.get_node("TravessiaMap/DynamicProps") is Node3D,
		"Travessia dynamic-prop layer is missing")
	assert(game.get_node("TravessiaMap/DynamicProps/MapLife/WaterRipples") is MeshInstance3D,
		"Animated water must be present")
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
		assert(hero.visual_model.model_root != null \
			and hero.visual_model.animation_player != null,
			"Roster hero must instantiate its rigged GLB")
		for clip_name in [&"idle", &"run", &"attack", &"q", &"ultimate", &"hurt", &"death"]:
			assert(hero.visual_model.animation_player.has_animation(clip_name),
				"Roster hero is missing %s" % clip_name)
		assert(hero.collision_layer == 2 and hero.collision_mask == 1,
			"Hero bots must collide only with the map layer")
		assert(hero.find_children("*", "Sprite3D", true, false).is_empty(),
			"Roster heroes must not fall back to camera-facing sprites")
		assert(hero.health_fill != null and hero.health_backdrop != null,
			"Every hero must expose a readable 3D health bar")

	var actors := get_nodes_in_group("arena_actors")
	assert(actors.size() >= 11, "Travessia must start with bases, towers, egg and a wave")
	var enemy_tower: ArenaActor
	var enemy_towers: Array[ArenaActor] = []
	var enemy_base: ArenaActor
	var blue_minion: ArenaActor
	var red_minion: ArenaActor
	var dragon_egg: ArenaActor
	for node in actors:
		var actor := node as ArenaActor
		if actor == null:
			continue
		if actor.team == 1 and actor.actor_kind == &"tower":
			enemy_towers.append(actor)
			if enemy_tower == null:
				enemy_tower = actor
		elif actor.team == 1 and actor.actor_kind == &"base":
			enemy_base = actor
		elif actor.team == 0 and actor.actor_kind == &"minion" and blue_minion == null:
			blue_minion = actor
		elif actor.team == 1 and actor.actor_kind == &"minion" and red_minion == null:
			red_minion = actor
		elif actor.actor_kind == &"dragon_egg":
			dragon_egg = actor
	assert(enemy_towers.size() == 2 and enemy_base != null, "Enemy structures are missing")
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
	assert(dragon_egg.actor_art == null and dragon_egg.creature_model != null,
		"Dragon egg must use its native 3D model instead of a billboard sprite")
	assert(dragon_egg.creature_model.find_children(
		"*", "MeshInstance3D", true, false).size() >= 30,
		"Dragon egg 3D assembly is incomplete")
	assert(dragon_egg.creature_animation != null \
		and dragon_egg.creature_animation.has_animation(&"idle") \
		and dragon_egg.creature_animation.has_animation(&"hatch"),
		"Dragon egg must import both authored animation clips")
	assert(game.find_children("*", "ArenaActor", true, false).all(
		func(actor: ArenaActor) -> bool: return actor.actor_kind != &"dragon"),
		"Dragon must not exist before the egg hatches")
	assert(blue_minion.actor_model is StylizedActor3D,
		"Minions must use the reusable 3D actor model")
	assert(blue_minion.actor_model.model_root != null \
		and blue_minion.actor_model.animation_player != null,
		"Minion must instantiate its team rigged GLB")
	for clip_name in [&"idle", &"run", &"attack", &"hurt", &"death"]:
		assert(blue_minion.actor_model.animation_player.has_animation(clip_name),
			"Minion is missing %s" % clip_name)
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
	assert(is_instance_valid(dragon_egg) \
		and dragon_egg.creature_animation.current_animation == &"hatch",
		"The egg must play its hatch animation before being removed")
	await create_timer(0.92, true, false, true).timeout
	assert(not is_instance_valid(dragon_egg), "Dragon egg was not removed after hatching")
	var dragon := game.find_children("*", "ArenaActor", true, false).filter(
		func(actor: ArenaActor) -> bool: return actor.actor_kind == &"dragon")
	assert(dragon.size() == 1, "Exactly one dragon must spawn after hatching")
	var live_dragon := dragon[0] as ArenaActor
	assert(live_dragon.actor_art == null and live_dragon.creature_model != null,
		"Dragon must use its native 3D model instead of a billboard sprite")
	assert(live_dragon.creature_model.find_children(
		"*", "MeshInstance3D", true, false).size() >= 45,
		"Dragon 3D assembly is incomplete")
	for clip_name in [&"idle", &"roar", &"attack", &"hurt", &"death"]:
		assert(live_dragon.creature_animation.has_animation(clip_name),
			"Dragon is missing the %s animation" % clip_name)
	assert(game.get_node_or_null(
		"TravessiaMap/DynamicProps/DragonAccessBridges") != null,
		"Central access bridges were not created during the hatch event")
	for gate in game.arena_map.block_map.gate_blocks:
		assert(not gate.visible, "Dragon hatch must open the island gate blocks")
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
	brutus.health = 1000.0
	live_dragon.take_damage(live_dragon.max_health, 0)
	await process_frame
	assert(is_instance_valid(live_dragon) \
		and live_dragon.creature_animation.current_animation == &"death",
		"Dragon must finish its death animation instead of disappearing instantly")
	assert(game.dragon_slain_by == 0 and is_equal_approx(
		float(game.team_damage_multiplier[0]),
		float(game.match_rules.dragon_team_damage_bonus)),
		"Dragon kill did not grant the blue team damage bonus")
	assert(brutus.health == 1420.0,
		"Dragon team reward did not heal Brutus")

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
	var allied_hero: HeroBot
	for hero_node in get_nodes_in_group("hero_bots"):
		var hero := hero_node as HeroBot
		if hero != null and hero.team == 0:
			allied_hero = hero
			break
	assert(allied_hero != null, "Allied hero required for defensive priority test")
	var allied_hero_position := allied_hero.global_position
	var allied_lane_x := allied_hero.lane_x
	allied_hero.global_position = red_minion.global_position + Vector3(0.0, 0.0, 1.8)
	allied_hero.lane_x = red_minion.lane_x
	assert(allied_hero.call("_nearest_enemy_unit", 4.6) == red_minion,
		"Hero bots must defend against nearby minions before attacking structures")
	allied_hero.global_position = allied_hero_position
	allied_hero.lane_x = allied_lane_x

	enemy_hero.global_position = hero_position
	red_minion.global_position = red_position
	blue_minion.global_position = blue_position
	blue_minion.objective = null
	for _wave in range(8):
		game.call("_spawn_wave")
	for lane_value in TravessiaDefinition.LANE_X:
		for team_value in [0, 1]:
			assert(game.call("_lane_minion_count", team_value, lane_value) \
				<= int(game.match_rules.max_minions_per_lane),
				"Minion wave cap failed and can snowball without limit")

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
	var expected_brutus_damage := 100.0 * float(game.team_damage_multiplier[0])
	assert(is_equal_approx(enemy_tower.health, tower_health - expected_brutus_damage),
		"Brutus combat damage or dragon bonus did not reach structures")

	var protected_base_health := enemy_base.health
	enemy_base.take_damage(100.0)
	assert(enemy_base.health == protected_base_health, "Protected base received damage")
	enemy_tower.take_damage(enemy_tower.max_health)
	await process_frame
	assert(enemy_base.get_is_protected(),
		"Base opened while the second lane tower was still standing")
	var second_enemy_tower := enemy_towers[1] if enemy_towers[0] == enemy_tower \
		else enemy_towers[0]
	second_enemy_tower.take_damage(second_enemy_tower.max_health)
	await process_frame
	assert(not enemy_base.get_is_protected(), "Base did not open after both towers fell")
	enemy_base.take_damage(enemy_base.max_health)
	await process_frame
	assert(game.match_over, "Destroying the enemy base did not finish the match")
	assert(game.status_label.text == "VITÓRIA!", "Victory announcement is missing")
	assert(game.end_overlay.visible, "Post-match overlay did not appear")
	print("ARENA_MATCH_OK actors=", actors.size(), " straight_lane=true combat=true victory=true")
	quit()
