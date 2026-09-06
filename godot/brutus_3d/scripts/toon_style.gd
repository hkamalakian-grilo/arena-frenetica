class_name ToonStyle
extends RefCounted

## Cartoon presentation shared by every character: three-band cel lighting
## with a darker underside, a dark silhouette outline drawn as a second pass,
## and a soft blob shadow on the ground. Works on the gl_compatibility renderer.

const CEL_SHADER := """
shader_type spatial;
render_mode cull_back, specular_disabled;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float shadow_floor = 0.45;
uniform float bands = 3.0;
// Painted-style vertical gradient: feet sit in shade, the head catches light.
uniform float gradient_bottom = 0.0;
uniform float gradient_top = 1.6;
uniform float gradient_floor = 0.62;

varying float world_height;

void vertex() {
	world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float lift = smoothstep(gradient_bottom, gradient_top, world_height);
	ALBEDO = albedo.rgb * mix(gradient_floor, 1.0, lift);
	EMISSION = emission_color.rgb * emission_energy;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float stepped = floor(ndl * bands + 0.35) / bands;
	float shade = mix(shadow_floor, 1.0, stepped);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * shade;
}
"""

const OUTLINE_SHADER := """
shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;
uniform float width = 0.05;
uniform vec4 line_color : source_color = vec4(0.06, 0.05, 0.08, 1.0);

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
"""

const SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float alpha = (1.0 - smoothstep(0.10, 1.0, dot(centered, centered))) * 0.30;
	ALBEDO = vec3(0.08, 0.06, 0.03);
	ALPHA = alpha;
}
"""

static var _cel_shader: Shader
static var _outline_shader: Shader
static var _shadow_shader: Shader


## Replaces every StandardMaterial3D under `model` with a cel-shaded copy and
## chains an outline pass. `outline_width` is in the model's local units.
static func apply(model: Node, outline_width: float, saturation := 1.08) -> void:
	if model == null:
		return
	if _cel_shader == null:
		_cel_shader = Shader.new()
		_cel_shader.code = CEL_SHADER
	var outline := _outline_material(outline_width)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if source == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = _cel_shader
			material.set_shader_parameter("albedo", _punch(source.albedo_color, saturation))
			if source.emission_enabled:
				material.set_shader_parameter("emission_color", source.emission)
				material.set_shader_parameter("emission_energy",
					minf(source.emission_energy_multiplier, 0.9))
			material.next_pass = outline
			mesh_instance.set_surface_override_material(surface_index, material)


## Same look applied to the surfaces of a Mesh resource (for MultiMesh use).
## `gradient_top` sets where the vertical shade reaches full brightness.
static func convert_mesh(mesh: Mesh, outline_width: float, gradient_top := 1.6,
		saturation := 1.05) -> void:
	if mesh == null:
		return
	if _cel_shader == null:
		_cel_shader = Shader.new()
		_cel_shader.code = CEL_SHADER
	var outline := _outline_material(outline_width)
	for surface_index in range(mesh.get_surface_count()):
		var source := mesh.surface_get_material(surface_index) as StandardMaterial3D
		if source == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = _cel_shader
		material.set_shader_parameter("albedo", _punch(source.albedo_color, saturation))
		material.set_shader_parameter("gradient_top", gradient_top)
		material.set_shader_parameter("gradient_floor", 0.72)
		if source.emission_enabled:
			material.set_shader_parameter("emission_color", source.emission)
			material.set_shader_parameter("emission_energy",
				minf(source.emission_energy_multiplier, 1.2))
		material.next_pass = outline
		mesh.surface_set_material(surface_index, material)


static func add_blob_shadow(parent: Node3D, size: float, height := 0.03) -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	shadow.name = "BlobShadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size * 0.82)
	shadow.mesh = plane
	shadow.position.y = height
	var material := ShaderMaterial.new()
	if _shadow_shader == null:
		_shadow_shader = Shader.new()
		_shadow_shader.code = SHADOW_SHADER
	material.shader = _shadow_shader
	shadow.material_override = material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shadow)
	return shadow


static func _outline_material(width: float) -> ShaderMaterial:
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = OUTLINE_SHADER
	var material := ShaderMaterial.new()
	material.shader = _outline_shader
	material.set_shader_parameter("width", width)
	material.set_shader_parameter("line_color", Color(0.06, 0.05, 0.08, 1.0))
	return material


## Slightly more saturated mid-tones read better under flat cel lighting
## without touching the authored hue or blowing out the value.
static func _punch(color: Color, saturation: float) -> Color:
	var h := color.h
	var s := clampf(color.s * saturation, 0.0, 1.0)
	var v := clampf(color.v, 0.0, 1.0)
	return Color.from_hsv(h, s, v, color.a)
