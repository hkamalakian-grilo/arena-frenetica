class_name HudStyle
extends RefCounted

## Shared look for the in-match HUD: outlined chunky labels, dark rounded
## plates with a gold rim, and circular ability buttons with painted icons.

const GOLD := Color(1.0, 0.80, 0.30)
const INK := Color(0.03, 0.05, 0.04, 0.82)
const OUTLINE := Color(0.02, 0.03, 0.03, 0.9)


static func outline_label(label: Label, font_size: int, color: Color, outline := 5) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", outline)


static func plate(corner := 14, border := 2, color := INK, rim := GOLD) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(rim, 0.75)
	style.set_border_width_all(border)
	style.set_corner_radius_all(corner)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


static func circle(bg: Color, rim: Color, border: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = rim
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	style.anti_aliasing = true
	return style


## Circular ability button: dark glass, coloured rim, painted icon.
static func ability_button(button: AbilityButton, rim: Color, icon: Texture2D) -> void:
	# A corner radius at least half the button always renders as a circle.
	var radius := maxi(64, int(minf(button.size.x, button.size.y) * 0.5))
	button.add_theme_stylebox_override("normal",
		circle(Color(0.05, 0.08, 0.06, 0.82), rim, 4, radius))
	button.add_theme_stylebox_override("hover",
		circle(Color(0.08, 0.11, 0.08, 0.86), rim.lightened(0.15), 4, radius))
	button.add_theme_stylebox_override("pressed",
		circle(Color(rim.darkened(0.55), 0.92), rim.lightened(0.35), 5, radius))
	button.add_theme_stylebox_override("disabled",
		circle(Color(0.04, 0.05, 0.05, 0.7), Color(rim, 0.35), 3, radius))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	button.add_theme_color_override("font_outline_color", OUTLINE)
	button.add_theme_constant_override("outline_size", 5)
	button.icon_texture = icon
	button.rim_color = rim


static func health_bar(bar: ProgressBar, fill: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.03, 0.05, 0.04, 0.92)
	background.border_color = Color(0.02, 0.03, 0.03, 0.95)
	background.set_border_width_all(2)
	background.set_corner_radius_all(11)
	background.shadow_color = Color(0, 0, 0, 0.45)
	background.shadow_size = 5
	background.shadow_offset = Vector2(0, 3)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.border_color = fill.lightened(0.35)
	fill_style.border_width_top = 3
	fill_style.set_corner_radius_all(10)
	fill_style.content_margin_left = 2.0
	fill_style.content_margin_right = 2.0
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill_style)
