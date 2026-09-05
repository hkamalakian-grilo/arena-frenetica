class_name AbilityZone
extends Node3D

## Ground area that ticks periodically: damages and slows enemies (Lyra's
## Chuva de Flechas) or heals and hastens allies (Sol's Zona Radiante).
## A short `delay` telegraphs the area before the first tick.

var team := 0
var radius := 2.0
var duration := 3.0
var tick := 0.5
var delay := 0.0
var damage_per_tick := 0.0
var heal_per_tick := 0.0
var slow_factor := 1.0
var haste := 0.0
var color := Color(1.0, 0.8, 0.3)
var age := 0.0
var next_tick := 0.0
var ticks_applied := 0
var disc: MeshInstance3D
var disc_material: StandardMaterial3D
var ring: MeshInstance3D


func configure(data: Dictionary) -> void:
	team = data.get("team", 0)
	radius = data.get("radius", 2.0)
	duration = data.get("duration", 3.0)
	tick = data.get("tick", 0.5)
	delay = data.get("delay", 0.0)
	damage_per_tick = data.get("damage_per_second", 0.0) * tick
	heal_per_tick = data.get("heal_per_second", 0.0) * tick
	slow_factor = data.get("slow", 1.0)
	haste = data.get("haste", 0.0)
	color = data.get("color", color)
	next_tick = delay
	name = "AbilityZone"
	_build_visual()


func _build_visual() -> void:
	disc = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	mesh.radial_segments = 40
	disc.mesh = mesh
	disc_material = StandardMaterial3D.new()
	disc_material.albedo_color = Color(color, 0.18)
	disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = disc_material
	disc.position.y = 0.05
	add_child(disc)
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.08
	torus.outer_radius = radius
	torus.rings = 40
	torus.ring_segments = 6
	ring.mesh = torus
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(color, 0.9)
	ring_material.emission_enabled = true
	ring_material.emission = color
	ring_material.emission_energy_multiplier = 1.4
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_material
	ring.position.y = 0.07
	add_child(ring)
	Vfx.area(self, radius * 0.9, Color(color, 0.9), damage_per_tick > 0.0)


func _process(delta: float) -> void:
	# Pulse while active; dim during the telegraph.
	var active := age >= delay
	var pulse := 0.5 + 0.5 * sin(age * 9.0)
	disc_material.albedo_color = Color(color, (0.22 + 0.16 * pulse) if active else 0.10)
	ring.scale = Vector3.ONE * (1.0 if active else 0.85 + 0.15 * clampf(age / maxf(delay, 0.01), 0.0, 1.0))
	if delay > 0.0 and age < delay:
		ring.rotation.y += delta * 3.0


func _physics_process(delta: float) -> void:
	age += delta
	if age >= next_tick and age <= delay + duration + 0.001:
		next_tick += tick
		_apply_tick()
	if age >= delay + duration:
		queue_free()


func _apply_tick() -> void:
	ticks_applied += 1
	var tree := get_tree()
	if damage_per_tick > 0.0 or slow_factor < 1.0:
		for enemy in CombatWorld.enemies_near(tree, global_position, radius, team, false):
			if damage_per_tick > 0.0:
				enemy.call("take_damage", damage_per_tick, team)
				CombatWorld.report_damage(tree, enemy.global_position, damage_per_tick,
					Color(1.0, 0.86, 0.45) if team == 0 else Color(1.0, 0.55, 0.5))
			if slow_factor < 1.0 and enemy.has_method("apply_slow"):
				enemy.call("apply_slow", slow_factor, tick + 0.15)
	if heal_per_tick > 0.0 or haste > 0.0:
		for ally in CombatWorld.allies_near(tree, global_position, radius, team, true):
			if heal_per_tick > 0.0 and ally.has_method("heal"):
				ally.call("heal", heal_per_tick)
				CombatWorld.report_damage(tree, ally.global_position, heal_per_tick,
					Color(0.55, 1.0, 0.6))
			if haste > 0.0 and ally.has_method("apply_haste"):
				ally.call("apply_haste", haste, tick + 0.15)
