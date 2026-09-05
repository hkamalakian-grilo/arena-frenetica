extends SceneTree

## Full three-minute match with a simple Brutus autopilot, at real time.
## Prints a timeline every 15 s and a summary at the end so balance changes
## can be judged without a device. Run:
##   godot --headless --path . --script tools/validate_match.gd

var game: Node
var brutus: BrutusController
var timeline: Array = []
var first_tower_at := -1.0
var dragon_first_hit_at := -1.0
var dragon_killed_at := -1.0
var brutus_deaths := 0
var last_report := -15.0
var retreating := false
var route: Array = []
var route_timer := 0.0
var casts := {"q": 0, "r": 0}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	brutus = game.get_node("Brutus") as BrutusController
	brutus.defeated.connect(func() -> void: brutus_deaths += 1)
	while not game.match_over:
		await physics_frame
		_autopilot()
		_observe()
	_summary()
	quit()


func _autopilot() -> void:
	if brutus.is_defeated or brutus.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	var tree: SceneTree = self
	var ratio := brutus.health_ratio()
	if retreating and ratio >= 0.8:
		retreating = false
	elif not retreating and ratio < 0.3:
		retreating = true
	var goal := Vector2.ZERO
	if retreating:
		goal = Vector2(TravessiaDefinition.PLAYER_SPAWN.x, TravessiaDefinition.PLAYER_SPAWN.z)
	else:
		var enemies := CombatWorld.enemies_near(tree, brutus.global_position, 4.5, 0, false)
		var target := CombatWorld.nearest(enemies, brutus.global_position)
		var dragon := CombatWorld.find_dragon(tree)
		var weak := _weak_structure()
		if weak != null and (target == null or not CombatWorld.is_hero(target)):
			if CombatWorld.planar(brutus, weak) <= 1.4:
				brutus.set_virtual_input(Vector2.ZERO)
				brutus.request_attack()
				return
			_steer_to(Vector2(weak.global_position.x, weak.global_position.z))
			return
		if target != null:
			var distance := CombatWorld.planar(brutus, target)
			if distance <= 1.6:
				brutus.set_virtual_input(Vector2.ZERO)
				brutus.request_attack()
				if brutus.r_cooldown_left <= 0.0 and CombatWorld.is_hero(target):
					brutus.request_r()
					casts.r += 1
				return
			if brutus.q_cooldown_left <= 0.0 and distance <= 5.0:
				brutus.request_q()
				casts.q += 1
				return
			goal = Vector2(target.global_position.x, target.global_position.z)
		elif dragon != null and game.arena_map.is_dragon_access_open() and ratio > 0.5:
			if CombatWorld.planar(brutus, dragon) <= 1.6:
				brutus.set_virtual_input(Vector2.ZERO)
				brutus.request_attack()
				return
			goal = Vector2.ZERO
		else:
			var structure := _enemy_structure()
			if structure == null:
				brutus.set_virtual_input(Vector2.ZERO)
				return
			if CombatWorld.planar(brutus, structure) <= 1.4:
				brutus.set_virtual_input(Vector2.ZERO)
				brutus.request_attack()
				return
			goal = Vector2(structure.global_position.x, structure.global_position.z)
	_steer_to(goal)


func _enemy_structure() -> Node3D:
	var best: ArenaActor
	var best_distance := INF
	for node in get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor == null or actor.is_defeated or actor.team != 1:
			continue
		if actor.actor_kind != &"tower" and actor.actor_kind != &"base":
			continue
		if actor.actor_kind == &"base" and actor.get_is_protected():
			continue
		var distance := CombatWorld.planar(brutus, actor)
		if distance < best_distance:
			best_distance = distance
			best = actor
	return best


func _weak_structure() -> Node3D:
	var structure := _enemy_structure() as ArenaActor
	if structure != null and structure.health_ratio() < 0.45:
		return structure
	return null


func _steer_to(goal: Vector2) -> void:
	var here := Vector2(brutus.global_position.x, brutus.global_position.z)
	route_timer -= 1.0 / 60.0
	if route.is_empty() or route_timer <= 0.0:
		route = TravessiaNav.route(here, goal, game.arena_map.is_dragon_access_open(), 0.34)
		route_timer = 0.5
	while route.size() > 1 and here.distance_to(route[0]) < 0.4:
		route.remove_at(0)
	var next: Vector2 = route[0] if not route.is_empty() else goal
	var direction := next - here
	if direction.length() < 0.2:
		brutus.set_virtual_input(Vector2.ZERO)
		return
	brutus.set_virtual_input(direction.normalized())


func _observe() -> void:
	var t: float = game.match_time
	var dragon := CombatWorld.find_dragon(self)
	if dragon != null and dragon.health < dragon.max_health and dragon_first_hit_at < 0.0:
		dragon_first_hit_at = t
	if game.dragon_slain_by >= 0 and dragon_killed_at < 0.0:
		dragon_killed_at = t
	var destroyed: int = game.team_towers_destroyed[0] + game.team_towers_destroyed[1]
	if destroyed > 0 and first_tower_at < 0.0:
		first_tower_at = t
	if t - last_report >= 15.0:
		last_report = t
		var modes := []
		for node in get_nodes_in_group("hero_bots"):
			var bot := node as HeroBot
			modes.append("%s:%s%s" % [bot.display_name, bot.mode, "(dead)" if bot.is_defeated else ""])
		var tower_hp := []
		var fronts := {}
		for node in get_nodes_in_group("arena_actors"):
			var actor := node as ArenaActor
			if actor == null or actor.is_defeated:
				continue
			if actor.actor_kind == &"tower":
				tower_hp.append("%s%d" % ["B" if actor.team == 0 else "R", roundi(actor.health_ratio() * 100.0)])
			elif actor.actor_kind == &"minion":
				var key := "%s%s" % ["L" if actor.lane_x < 0.0 else "R", "b" if actor.team == 0 else "r"]
				var z := actor.global_position.z
				if not fronts.has(key) or (actor.team == 0 and z < fronts[key]) \
						or (actor.team == 1 and z > fronts[key]):
					fronts[key] = z
		var front_text := []
		for key in ["Lb", "Lr", "Rb", "Rr"]:
			front_text.append("%s=%s" % [key, ("%.1f" % fronts[key]) if fronts.has(key) else "-"])
		var line := "t=%03d towers=%d×%d kills=%d×%d core=%d%%×%d%% towerhp=%s fronts=%s brutus=%d%% dragon=%s bots=%s" % [
			int(t), game.team_towers_destroyed[0], game.team_towers_destroyed[1],
			game.team_kills[0], game.team_kills[1],
			roundi(game.call("_base_health", 0) / 42.0), roundi(game.call("_base_health", 1) / 42.0),
			",".join(tower_hp), " ".join(front_text),
			roundi(brutus.health_ratio() * 100.0),
			("alive %d%%" % roundi(dragon.health_ratio() * 100.0)) if dragon != null else (
				"slain by %d" % game.dragon_slain_by if game.dragon_slain_by >= 0 else "egg"),
			", ".join(modes)]
		timeline.append(line)
		print(line)


func _summary() -> void:
	var verdict: Dictionary = game.call("_team_advantage")
	print("VALIDATE_MATCH_DONE winner=%d reason=\"%s\" towers=%d×%d kills=%d×%d first_tower=%.0fs dragon_first_hit=%.0fs dragon_killed=%.0fs brutus_deaths=%d q=%d r=%d" % [
		int(verdict.winner), String(verdict.reason),
		game.team_towers_destroyed[0], game.team_towers_destroyed[1],
		game.team_kills[0], game.team_kills[1], first_tower_at, dragon_first_hit_at,
		dragon_killed_at, brutus_deaths, casts.q, casts.r])
