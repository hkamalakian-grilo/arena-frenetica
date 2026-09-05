class_name ToonStyle
extends RefCounted

## Cartoon presentation shared by every character: hard two-step lighting,
## a dark silhouette outline drawn as a second pass, and a soft blob shadow
## on the ground. Works on the gl_compatibility renderer.

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

static var _outline_shader: Shader
static var _shadow_shader: Shader


## Replaces every StandardMaterial3D under `model` with a toon-lit copy and
## chains an outline pass. `outline_width` is in the model's local units.
static func apply(model: Node, outline_width: float, saturation := 1.18) -> void:
	if model == null:
		return
	var outline := _outline_material(outline_width)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as StandardMaterial3D
			material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			material.specular_mode = BaseMaterial3D.SPECULAR_TOON
			material.roughness = maxf(material.roughness, 0.7)
			material.metallic = minf(material.metallic, 0.15)
			material.albedo_color = _punch(material.albedo_color, saturation)
			if material.emission_enabled:
				material.emission_energy_multiplier = minf(material.emission_energy_multiplier, 0.8)
			material.next_pass = outline
			mesh_instance.set_surface_override_material(surface_index, material)


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


## Slightly more saturated and brighter mid-tones read better under the
## flat toon lighting without touching the authored hue.
static func _punch(color: Color, saturation: float) -> Color:
	var h := color.h
	var s := clampf(color.s * saturation, 0.0, 1.0)
	var v := clampf(color.v * 1.06, 0.0, 1.0)
	return Color.from_hsv(h, s, v, color.a)
