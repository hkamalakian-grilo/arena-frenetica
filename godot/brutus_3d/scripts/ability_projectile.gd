class_name AbilityProjectile
extends Node3D

## Reusable straight or homing projectile. Damages enemies of `team`; when
## `heal` is set it instead restores an allied hero it touches (Sol's orb).
## `pierce` keeps flying through units; otherwise the first contact ends it.

var team := 0
var source: Node3D
var direction := Vector3(0, 0, -1)
var speed := 9.0
var max_distance := 6.0
var hit_radius := 0.34
var damage := 0.0
var heal := 0.0
var pierce := false
var hits_structures := true
var homing_target: Node3D
var color := Color(1.0, 0.9, 0.5)
var travelled := 0.0
var hit_ids: Array = []
var trail_timer := 0.0
var mesh_instance: MeshInstance3D
var on_hit: Callable


func configure(data: Dictionary) -> void:
	team = data.get("team", 0)
	source = data.get("source", null)
	direction = data.get("direction", Vector3(0, 0, -1))
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
	speed = data.get("speed", 9.0)
	max_distance = data.get("range", 6.0)
	hit_radius = data.get("width", 0.34)
	damage = data.get("damage", 0.0)
	heal = data.get("heal", 0.0)
	pierce = data.get("pierce", false)
	hits_structures = data.get("hits_structures", true)
	homing_target = data.get("homing_target", null)
	color = data.get("color", color)
	on_hit = data.get("on_hit", Callable())
	name = "AbilityProjectile"
	_build_visual()


func _build_visual() -> void:
	mesh_instance = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = hit_radius * 0.55
	mesh.height = hit_radius * 2.6
	mesh_instance.mesh = mesh
	mesh_instance.rotation.x = PI * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.4
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	add_child(mesh_instance)
	Vfx.trail(self, Color(color, 0.85), hit_radius * 0.9, 18)
	_face_direction()


func _face_direction() -> void:
	if direction.length_squared() > 0.001:
		rotation.y = atan2(direction.x, direction.z)


func _physics_process(delta: float) -> void:
	if homing_target != null:
		if not CombatWorld.is_valid_target(homing_target):
			queue_free()
			return
		var to_target := homing_target.global_position + Vector3(0, 0.9, 0) - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.001:
			direction = to_target.normalized()
			_face_direction()
	var step := speed * delta
	global_position += direction * step
	travelled += step
	if homing_target != null:
		if CombatWorld.planar(self, homing_target) <= hit_radius + 0.35:
			_apply(homing_target)
			queue_free()
			return
	else:
		for candidate in get_tree().get_nodes_in_group("damageable"):
			if candidate == source or not CombatWorld.is_valid_target(candidate, self):
				continue
			if hit_ids.has(candidate.get_instance_id()):
				continue
			var candidate_team := int(candidate.call("get_team"))
			var is_ally := candidate_team == team
			if is_ally and (heal <= 0.0 or not CombatWorld.is_hero(candidate)):
				continue
			if not is_ally and not hits_structures and CombatWorld.is_structure(candidate):
				continue
			var reach := hit_radius + (0.9 if CombatWorld.is_structure(candidate) else 0.42)
			if CombatWorld.planar(self, candidate) > reach:
				continue
			_apply(candidate)
			hit_ids.append(candidate.get_instance_id())
			if not pierce or is_ally:
				queue_free()
				return
	if travelled >= max_distance:
		queue_free()


func _apply(target: Node3D) -> void:
	var target_team := int(target.call("get_team"))
	var hit_point := target.global_position + Vector3(0, 0.9, 0)
	if target_team == team:
		if heal > 0.0 and target.has_method("heal"):
			target.call("heal", heal)
			CombatWorld.report_damage(get_tree(), target.global_position, heal,
				Color(0.55, 1.0, 0.6))
			Vfx.burst(get_parent(), hit_point, Color(0.6, 1.0, 0.65), 14, 1.6, 0.14, 0.6, true, 1.5)
	elif damage > 0.0:
		target.call("take_damage", damage, team)
		CombatWorld.report_damage(get_tree(), target.global_position, damage,
			Color(1.0, 0.86, 0.45) if team == 0 else Color(1.0, 0.55, 0.5))
		Vfx.burst(get_parent(), hit_point, color, 10, 2.4, 0.12, 0.3)
		Vfx.flash(get_parent(), hit_point, Color(color, 0.9), 0.7, 0.14)
	if on_hit.is_valid():
		on_hit.call(target)


func _spawn_trail(delta: float) -> void:
	trail_timer -= delta
	if trail_timer > 0.0:
		return
	trail_timer = 0.05
	var puff := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = hit_radius * 0.4
	mesh.height = hit_radius * 0.8
	puff.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material_override = material
	get_parent().add_child(puff)
	puff.global_position = global_position
	var tween := puff.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.22)
	tween.tween_callback(puff.queue_free)
