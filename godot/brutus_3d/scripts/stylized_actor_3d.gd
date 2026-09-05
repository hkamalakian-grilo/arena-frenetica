class_name StylizedActor3D
extends Node3D

## Runtime adapter shared by the final rigged roster and team minions.
## Front is -Z, matching Brutus and the canonical movement convention.

const LYRA_SCENE := preload("res://assets/roster/lyra.glb")
const NIX_SCENE := preload("res://assets/roster/nix.glb")
const SOL_SCENE := preload("res://assets/roster/sol.glb")
const MINION_BLUE_SCENE := preload("res://assets/roster/minion_blue.glb")
const MINION_RED_SCENE := preload("res://assets/roster/minion_red.glb")

var model_root: Node3D
var animation_player: AnimationPlayer
var actor_kind: StringName
var variant: StringName
var moving := false
var action_locked := false
var defeated := false


func configure(new_actor_kind: StringName, new_variant: StringName, team: int) -> void:
	actor_kind = new_actor_kind
	variant = new_variant
	name = "Roster3D"
	var scene := _select_scene(team)
	assert(scene != null, "Roster model is missing for %s" % variant)
	model_root = scene.instantiate()
	model_root.name = "%sModel" % String(variant).capitalize()
	model_root.scale = Vector3.ONE * (0.82 if actor_kind == &"minion" else 1.28)
	add_child(model_root)
	animation_player = model_root.find_child(
		"AnimationPlayer", true, false) as AnimationPlayer
	assert(animation_player != null, "%s GLB needs an AnimationPlayer" % variant)
	for clip_name in [&"idle", &"run"]:
		if animation_player.has_animation(clip_name):
			animation_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	animation_player.animation_finished.connect(_on_animation_finished)
	_add_team_ring(team, actor_kind == &"minion")
	_play_motion(&"idle")


func update_motion(_delta: float, direction: Vector3, speed_ratio: float) -> void:
	if defeated:
		return
	moving = speed_ratio > 0.05
	face_direction(direction)
	if not action_locked:
		_play_motion(&"run" if moving else &"idle")


func trigger_attack() -> void:
	_play_action(&"attack")


func trigger_hurt() -> void:
	_play_action(&"hurt", 0.035)


func trigger_q() -> void:
	_play_action(&"q")


func trigger_ultimate() -> void:
	_play_action(&"ultimate", 0.12)


func trigger_death() -> void:
	defeated = true
	action_locked = true
	_play_clip(&"death", 0.06, 2.0)


func revive() -> void:
	defeated = false
	action_locked = false
	visible = true
	_play_motion(&"idle")


func death_duration() -> float:
	if animation_player != null and animation_player.has_animation(&"death"):
		return animation_player.get_animation(&"death").length
	return 1.8


func face_direction(direction: Vector3) -> void:
	if direction.length_squared() > 0.001:
		rotation.y = atan2(-direction.x, -direction.z)


func _select_scene(team: int) -> PackedScene:
	if actor_kind == &"minion":
		return MINION_BLUE_SCENE if team == 0 else MINION_RED_SCENE
	match variant:
		&"lyra": return LYRA_SCENE
		&"nix": return NIX_SCENE
		&"sol": return SOL_SCENE
	return null


func _play_motion(clip_name: StringName) -> void:
	if animation_player.current_animation == clip_name \
			and animation_player.is_playing():
		return
	_play_clip(clip_name, 0.14, 1.0)


func _play_action(clip_name: StringName, blend := 0.06) -> void:
	if defeated or animation_player == null \
			or not animation_player.has_animation(clip_name):
		return
	action_locked = true
	_play_clip(clip_name, blend, 1.0)


func _play_clip(clip_name: StringName, blend: float, speed: float) -> void:
	if animation_player != null and animation_player.has_animation(clip_name):
		animation_player.speed_scale = speed
		animation_player.play(clip_name, blend)


func _on_animation_finished(clip_name: StringName) -> void:
	if clip_name == &"death" or defeated:
		return
	action_locked = false
	_play_motion(&"run" if moving else &"idle")


func _add_team_ring(team: int, compact: bool) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "TeamRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.37 if compact else 0.48
	mesh.outer_radius = 0.44 if compact else 0.57
	mesh.rings = 24
	mesh.ring_segments = 8
	ring.mesh = mesh
	var color := Color("3acfff") if team == 0 else Color("ff4f68")
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(color, 0.88)
	ring_material.emission_enabled = true
	ring_material.emission = color
	ring_material.emission_energy_multiplier = 0.45
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_material
	ring.position.y = 0.045
	add_child(ring)
