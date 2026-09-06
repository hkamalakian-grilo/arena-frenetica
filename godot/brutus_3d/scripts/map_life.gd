class_name MapLife
extends Node3D

## Motion layered over the painted Travessia without touching its pixels:
## rippling water on the river and the dragon lake, drifting cloud shadows,
## and ambient petals/fireflies. Everything is procedural and cheap enough for
## the gl_compatibility renderer.

const WATER_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float river_half_width = 1.55;
uniform float lake_inner = 2.05;
uniform float lake_outer = 4.55;
uniform float lane_x = 5.35;
uniform float bridge_half_width = 1.35;
uniform float speed = 0.35;
uniform vec4 tint : source_color = vec4(0.75, 0.92, 1.0, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ripple(vec2 p, float t) {
	float a = sin(p.x * 3.1 + t * 1.7 + sin(p.y * 2.3 + t * 0.9) * 1.4);
	float b = sin(p.y * 2.7 - t * 1.3 + sin(p.x * 1.9 - t * 0.7) * 1.2);
	float c = sin((p.x + p.y) * 4.3 + t * 2.1);
	float v = (a + b) * 0.5 + c * 0.35;
	return smoothstep(0.55, 1.0, v);
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = TIME * speed;
	float in_river = 1.0 - smoothstep(river_half_width - 0.25, river_half_width, abs(p.y));
	float r = length(p);
	float in_lake = smoothstep(lake_inner, lake_inner + 0.25, r) * (1.0 - smoothstep(lake_outer - 0.3, lake_outer, r));
	float mask = max(in_river, in_lake);
	// Bridges and the dragon bridges are stone: keep them dry.
	float left_bridge = 1.0 - smoothstep(bridge_half_width - 0.1, bridge_half_width, abs(p.x + lane_x));
	float right_bridge = 1.0 - smoothstep(bridge_half_width - 0.1, bridge_half_width, abs(p.x - lane_x));
	float center_bridge = (1.0 - smoothstep(0.85, 1.0, abs(p.x))) * step(lake_inner - 0.2, r);
	mask *= 1.0 - max(max(left_bridge, right_bridge), center_bridge) * (1.0 - in_lake * 0.0);
	float highlight = ripple(p, t) * 0.55 + ripple(p * 1.9 + vec2(3.0, 7.0), t * 1.4) * 0.3;
	ALBEDO = tint.rgb * highlight * mask * 0.42;
	ALPHA = mask;
}
"""

const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled;
uniform float speed = 0.05;
uniform float darkness = 0.16;
uniform float scale = 0.11;

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.1 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * scale + vec2(TIME * speed, TIME * speed * 0.35);
	float clouds = smoothstep(0.52, 0.78, fbm(p));
	float shade = 1.0 - clouds * darkness;
	ALBEDO = vec3(shade);
	ALPHA = 1.0;
}
"""

var water: MeshInstance3D
var clouds: MeshInstance3D
var petals: GPUParticles3D
var fireflies: GPUParticles3D


func build() -> void:
	name = "MapLife"
	_build_water()
	_build_clouds()
	_build_ambient_particles()


func _build_water() -> void:
	water = MeshInstance3D.new()
	water.name = "WaterRipples"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(TravessiaDefinition.MAP_SIZE.x, 10.5)
	water.mesh = mesh
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WATER_SHADER
	material.shader = shader
	material.set_shader_parameter("lane_x", absf(TravessiaDefinition.LANE_X[0]))
	material.set_shader_parameter("bridge_half_width", 1.35)
	water.material_override = material
	water.position.y = 0.06
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _build_clouds() -> void:
	clouds = MeshInstance3D.new()
	clouds.name = "CloudShadows"
	var mesh := PlaneMesh.new()
	mesh.size = TravessiaDefinition.MAP_SIZE + Vector2(2.0, 2.0)
	clouds.mesh = mesh
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = CLOUD_SHADER
	material.shader = shader
	clouds.material_override = material
	# Above the tallest relief so the multiply pass covers forests too.
	clouds.position.y = 0.95
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(clouds)


func _build_ambient_particles() -> void:
	petals = _ambient_emitter("Petals", Color(0.78, 0.55, 0.95, 0.85), 0.11, 26,
		Vector3(0.6, -0.25, 0.2), 9.0, 2.2)
	fireflies = _ambient_emitter("Fireflies", Color(1.0, 0.95, 0.55, 0.9), 0.07, 18,
		Vector3(0.0, 0.15, 0.0), 6.0, 0.9)


func _ambient_emitter(node_name: String, color: Color, size: float, amount: int,
		drift: Vector3, lifetime: float, spread_speed: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var quad_material := StandardMaterial3D.new()
	quad_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad_material.vertex_color_use_as_albedo = true
	quad_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = quad_material
	particles.draw_pass_1 = quad
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(TravessiaDefinition.PLAYABLE_HALF_EXTENTS.x + 1.0, 0.4,
		TravessiaDefinition.PLAYABLE_HALF_EXTENTS.y)
	material.direction = drift
	material.spread = 35.0
	material.initial_velocity_min = spread_speed * 0.4
	material.initial_velocity_max = spread_speed
	material.gravity = Vector3(0.0, -0.05, 0.0)
	material.scale_min = 0.6
	material.scale_max = 1.3
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 0.6
	material.turbulence_noise_scale = 3.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, 0.0))
	gradient.add_point(0.2, color)
	gradient.add_point(0.8, color)
	gradient.set_color(gradient.get_point_count() - 1, Color(color, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	material.color_ramp = ramp
	particles.process_material = material
	particles.position.y = 1.2
	add_child(particles)
	particles.emitting = true
	return particles
