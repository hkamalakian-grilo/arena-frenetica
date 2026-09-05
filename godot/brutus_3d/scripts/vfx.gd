class_name Vfx
extends RefCounted

## Particle and flash helpers for combat feedback. Everything is procedural
## (no textures) and built for the gl_compatibility renderer: GPUParticles3D
## with billboard quads, additive sparks, soft dust and a crescent slash.

const ARC_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float progress = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.x, -p.y);
	float band = smoothstep(0.45, 0.62, r) * (1.0 - smoothstep(0.86, 1.0, r));
	float sweep = 1.0 - smoothstep(1.05, 1.35, abs(angle));
	float head = 1.0 - smoothstep(0.0, 1.0, progress);
	ALBEDO = tint.rgb * (1.4 - progress);
	ALPHA = band * sweep * head * 0.9;
}
"""

static var _arc_shader: Shader
static var _spark_mesh: QuadMesh
static var _dust_mesh: QuadMesh


static func _quad(size: float, additive: bool) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.no_depth_test = additive
	mesh.material = material
	return mesh


static func _ramp(color: Color, end_alpha := 0.0) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, color.a))
	gradient.set_color(1, Color(color.lightened(0.1), end_alpha))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


## One-shot radial burst. `additive` makes sparks; otherwise soft smoke/dust.
static func burst(parent: Node, at_position: Vector3, color: Color, count := 16,
		speed := 3.0, size := 0.16, lifetime := 0.5, additive := true,
		gravity := -4.0, direction := Vector3.UP, spread := 180.0) -> GPUParticles3D:
	if parent == null:
		return null
	var particles := GPUParticles3D.new()
	particles.name = "VfxBurst"
	particles.amount = count
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.local_coords = false
	particles.draw_pass_1 = _quad(size, additive)
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.12
	material.direction = direction
	material.spread = spread
	material.initial_velocity_min = speed * 0.45
	material.initial_velocity_max = speed
	material.gravity = Vector3(0.0, gravity, 0.0)
	material.damping_min = 1.5
	material.damping_max = 3.0
	material.scale_min = 0.6
	material.scale_max = 1.3
	material.color_ramp = _ramp(color)
	particles.process_material = material
	parent.add_child(particles)
	particles.global_position = at_position
	particles.emitting = true
	_free_later(particles, lifetime + 0.3)
	return particles


## Soft ground dust (footsteps, dash trail, landings).
static func dust(parent: Node, at_position: Vector3, count := 8, size := 0.28, speed := 1.2) -> GPUParticles3D:
	return burst(parent, at_position + Vector3(0, 0.08, 0), Color(0.76, 0.64, 0.42, 0.55),
		count, speed, size, 0.55, false, 0.6, Vector3.UP, 70.0)


## Additive flash sprite that pops and fades; reads as the moment of impact.
static func flash(parent: Node, at_position: Vector3, color: Color, size := 1.0,
		duration := 0.18) -> MeshInstance3D:
	if parent == null:
		return null
	var node := MeshInstance3D.new()
	node.name = "VfxFlash"
	node.mesh = _quad(size, true)
	var material := node.mesh.material as StandardMaterial3D
	material.vertex_color_use_as_albedo = false
	material.albedo_color = color
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.global_position = at_position
	node.scale = Vector3.ONE * 0.4
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector3.ONE * 1.25, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(node.queue_free)
	return node


## Crescent slash on the ground in front of a melee hit.
static func slash(parent: Node, at_position: Vector3, direction: Vector3, color: Color,
		size := 1.6, duration := 0.22) -> MeshInstance3D:
	if parent == null:
		return null
	if _arc_shader == null:
		_arc_shader = Shader.new()
		_arc_shader.code = ARC_SHADER
	var node := MeshInstance3D.new()
	node.name = "VfxSlash"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	node.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = _arc_shader
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("progress", 0.0)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.global_position = at_position + Vector3(0, 0.12, 0)
	node.rotation.y = atan2(direction.x, direction.z)
	var tween := node.create_tween()
	tween.tween_method(func(value: float) -> void:
		material.set_shader_parameter("progress", value), 0.0, 1.0, duration)
	tween.tween_callback(node.queue_free)
	return node


## Continuous emitter attached to a moving node (projectiles, thrown shield).
static func trail(parent: Node3D, color: Color, size := 0.14, rate := 24,
		additive := true) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "VfxTrail"
	particles.amount = rate
	particles.lifetime = 0.35
	particles.local_coords = false
	particles.draw_pass_1 = _quad(size, additive)
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.08
	material.direction = Vector3.UP
	material.spread = 180.0
	material.initial_velocity_min = 0.1
	material.initial_velocity_max = 0.5
	material.gravity = Vector3.ZERO
	material.scale_min = 0.5
	material.scale_max = 1.0
	material.color_ramp = _ramp(color)
	particles.process_material = material
	parent.add_child(particles)
	particles.emitting = true
	return particles


## Continuous area emitter for zones. `falling` rains from above (arrows);
## otherwise sparkles rise from the ground (healing light).
static func area(parent: Node3D, radius: float, color: Color, falling: bool,
		rate := 40) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "VfxArea"
	particles.amount = rate
	particles.lifetime = 0.7 if falling else 1.1
	particles.local_coords = false
	particles.draw_pass_1 = _quad(0.12 if falling else 0.16, true)
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(radius, 0.05, radius)
	material.direction = Vector3.DOWN if falling else Vector3.UP
	material.spread = 8.0 if falling else 25.0
	material.initial_velocity_min = 6.0 if falling else 0.6
	material.initial_velocity_max = 8.0 if falling else 1.2
	material.gravity = Vector3.ZERO
	material.scale_min = 0.7
	material.scale_max = 1.2
	material.color_ramp = _ramp(color)
	particles.process_material = material
	parent.add_child(particles)
	particles.position.y = 4.0 if falling else 0.1
	particles.emitting = true
	return particles


static func _free_later(node: Node, seconds: float) -> void:
	if node == null or not node.is_inside_tree():
		return
	var timer := node.get_tree().create_timer(seconds, true, false, true)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free())
