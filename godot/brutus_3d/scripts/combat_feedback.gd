class_name CombatFeedback
extends Node

## Juice layer shared by the match: floating damage numbers, hitstop, and the
## red screen flash when the player is hurt. Pure presentation: nothing here
## changes simulation results, so tests can run with or without it.

const HITSTOP_SCALE := 0.12

var world: Node3D
var hud: Node
var hurt_flash: ColorRect
var hurt_material: ShaderMaterial
var flash_strength := 0.0
var hitstop_left := 0.0
var hitstop_base_scale := 1.0
var hitstop_active := false
var low_health_ratio := 1.0
var low_health_phase := 0.0


func setup(world_root: Node3D, hud_root: Node) -> void:
	world = world_root
	hud = hud_root
	name = "CombatFeedback"
	_build_hurt_flash()


func _process(delta: float) -> void:
	if hitstop_active:
		# delta is already scaled by Engine.time_scale; recover real seconds.
		hitstop_left -= delta / maxf(Engine.time_scale, 0.001)
		if hitstop_left <= 0.0:
			_end_hitstop()
	if hurt_material == null:
		return
	var shown := flash_strength
	if low_health_ratio < 0.3:
		# Slow heartbeat on the edges while Brutus is close to dying.
		low_health_phase += delta / maxf(Engine.time_scale, 0.001)
		var pulse := 0.22 + 0.16 * (0.5 + 0.5 * sin(low_health_phase * 5.0))
		shown = maxf(shown, pulse)
	hurt_material.set_shader_parameter("strength", shown)


func _exit_tree() -> void:
	if hitstop_active:
		_end_hitstop()


## Freezes the world briefly so a landed blow reads as heavy. Only the first
## request in a burst takes effect; a longer request extends an active one.
func request_hitstop(seconds: float) -> void:
	if seconds <= 0.0:
		return
	if hitstop_active:
		hitstop_left = maxf(hitstop_left, seconds)
		return
	hitstop_active = true
	hitstop_base_scale = Engine.time_scale
	hitstop_left = seconds
	Engine.time_scale = hitstop_base_scale * HITSTOP_SCALE


func _end_hitstop() -> void:
	hitstop_active = false
	hitstop_left = 0.0
	Engine.time_scale = hitstop_base_scale


## Floating number above a hit target. `amount` is rounded for readability.
func spawn_damage_number(world_position: Vector3, amount: float, color: Color,
		scale := 1.0) -> Label3D:
	if world == null:
		return null
	var label := Label3D.new()
	label.name = "DamageNumber"
	label.text = str(roundi(amount))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 64
	label.outline_size = 14
	label.pixel_size = 0.0042 * scale
	label.modulate = color
	label.outline_modulate = Color(0.05, 0.05, 0.08, 0.95)
	label.render_priority = 4
	world.add_child(label)
	var jitter := Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.15, 0.15))
	label.global_position = world_position + Vector3(0, 1.9, 0) + jitter
	label.scale = Vector3.ONE * 1.6
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position", label.global_position + Vector3(0, 1.25, 0), 0.62) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.32).set_delay(0.30)
	tween.chain().tween_callback(label.queue_free)
	return label


## Short word popup (ABATE!, ATORDOADO) rendered larger than a number.
func spawn_text(world_position: Vector3, text: String, color: Color) -> Label3D:
	var label := spawn_damage_number(world_position, 0.0, color, 0.85)
	if label != null:
		label.text = text
	return label


## Red vignette pulse when Brutus takes damage; strength scales with the hit.
func flash_hurt(strength: float) -> void:
	if hurt_flash == null:
		return
	flash_strength = clampf(0.40 + strength * 0.5, 0.40, 0.85)
	var tween := create_tween()
	tween.tween_property(self, "flash_strength", 0.0, 0.42) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func set_player_health_ratio(ratio: float) -> void:
	low_health_ratio = ratio


func _build_hurt_flash() -> void:
	if hud == null:
		return
	hurt_flash = ColorRect.new()
	hurt_flash.name = "HurtFlash"
	hurt_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_flash.color = Color.WHITE
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_material = ShaderMaterial.new()
	var shader := Shader.new()
	# Edge-only vignette: the centre of the arena stays readable while the
	# frame pulses red, which is what a mobile player reads as "I am hurt".
	shader.code = """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radial = dot(centered, centered);
	float edge = smoothstep(0.48, 1.55, radial);
	COLOR = vec4(0.86, 0.07, 0.10, edge * strength * 0.85);
}
"""
	hurt_material.shader = shader
	hurt_material.set_shader_parameter("strength", 0.0)
	hurt_flash.material = hurt_material
	hud.add_child(hurt_flash)
	hud.move_child(hurt_flash, 0)
