class_name CombatWorld
extends RefCounted

## Static helpers shared by heroes, projectiles and zones: who is an enemy,
## who is nearby, and how to report damage to the presentation layer without
## coupling gameplay scripts to main.gd.


## `viewer` enables bush concealment: a hidden hero only counts as a target
## for viewers within BUSH_REVEAL_DISTANCE.
static func is_valid_target(candidate, viewer: Node3D = null) -> bool:
	if not (is_instance_valid(candidate) and candidate is Node3D \
			and candidate.has_method("get_team") and candidate.has_method("take_damage") \
			and candidate.has_method("is_targetable") and bool(candidate.call("is_targetable"))):
		return false
	if viewer != null and is_concealed(candidate) \
			and planar(viewer, candidate) > TravessiaDefinition.BUSH_REVEAL_DISTANCE:
		return false
	return true


static func is_concealed(candidate) -> bool:
	return is_instance_valid(candidate) and candidate.has_method("is_concealed") \
		and bool(candidate.call("is_concealed"))


static func is_structure(candidate) -> bool:
	var actor := candidate as ArenaActor
	return actor != null and (actor.actor_kind == &"tower" or actor.actor_kind == &"base")


static func is_hero(candidate) -> bool:
	return candidate is HeroBot or candidate is BrutusController


static func planar(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x, a.global_position.z).distance_to(
		Vector2(b.global_position.x, b.global_position.z))


static func planar_to(a: Node3D, point: Vector3) -> float:
	return Vector2(a.global_position.x, a.global_position.z).distance_to(
		Vector2(point.x, point.z))


## Enemies of `team` within `radius` of `center`. `team == 2` is the neutral
## dragon: hostile to everyone, but towers never target it.
static func enemies_near(tree: SceneTree, center: Vector3, radius: float, team: int,
		include_structures := true, exclude: Node = null) -> Array:
	var result: Array = []
	for node in tree.get_nodes_in_group("damageable"):
		if node == exclude or not is_valid_target(node):
			continue
		if int(node.call("get_team")) == team:
			continue
		if not include_structures and is_structure(node):
			continue
		if planar_to(node, center) <= radius:
			result.append(node)
	return result


static func allies_near(tree: SceneTree, center: Vector3, radius: float, team: int,
		heroes_only := true, exclude: Node = null) -> Array:
	var result: Array = []
	for node in tree.get_nodes_in_group("damageable"):
		if node == exclude or not is_valid_target(node):
			continue
		if int(node.call("get_team")) != team:
			continue
		if heroes_only and not is_hero(node):
			continue
		if planar_to(node, center) <= radius:
			result.append(node)
	return result


static func nearest(candidates: Array, origin: Vector3) -> Node3D:
	var best: Node3D
	var best_distance := INF
	for candidate in candidates:
		var distance := planar_to(candidate, origin)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


static func find_dragon(tree: SceneTree) -> ArenaActor:
	for node in tree.get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor != null and actor.actor_kind == &"dragon" and not actor.is_defeated:
			return actor
	return null


static func report_damage(tree: SceneTree, position: Vector3, amount: float, color: Color) -> void:
	var feedback := tree.get_first_node_in_group("combat_feedback")
	if feedback != null:
		feedback.call("spawn_damage_number", position, amount, color)


static func report_text(tree: SceneTree, position: Vector3, text: String, color: Color) -> void:
	var feedback := tree.get_first_node_in_group("combat_feedback")
	if feedback != null:
		feedback.call("spawn_text", position, text, color)


static func play_sfx(tree: SceneTree, clip: StringName, volume_db := 0.0) -> void:
	tree.call_group("arena_sfx", "play", clip, volume_db, 0.08)


static func team_color(team: int) -> Color:
	if team == 0:
		return Color("4ed7ff")
	if team == 1:
		return Color("ff526b")
	return Color("c48cff")
