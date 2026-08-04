extends SceneTree

## Builds a deterministic height map from the approved Travessia artwork.
## It never redraws the map: each height sample comes from the original pixel.

const SOURCE := "res://assets/maps/travessia_terrain_v3.png"
const OUTPUT := "res://assets/maps/travessia_depth_v1.png"
const DEPTH_SIZE := Vector2i(320, 604)


func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	assert(not source.is_empty(), "Travessia source art must be readable")
	var depth := Image.create(DEPTH_SIZE.x, DEPTH_SIZE.y, false, Image.FORMAT_L8)
	for y in range(DEPTH_SIZE.y):
		for x in range(DEPTH_SIZE.x):
			var uv := Vector2(
				(float(x) + 0.5) / float(DEPTH_SIZE.x),
				(float(y) + 0.5) / float(DEPTH_SIZE.y))
			var source_x := clampi(floori(uv.x * source.get_width()),
				0, source.get_width() - 1)
			var source_y := clampi(floori(uv.y * source.get_height()),
				0, source.get_height() - 1)
			var color := source.get_pixel(source_x, source_y)
			var value := _height_for_pixel(color, uv)
			depth.set_pixel(x, y, Color(value, value, value, 1.0))

	# One down/up pass removes pixel noise while keeping the silhouettes aligned.
	depth.resize(160, 302, Image.INTERPOLATE_BILINEAR)
	depth.resize(DEPTH_SIZE.x, DEPTH_SIZE.y, Image.INTERPOLATE_CUBIC)
	var error := depth.save_png(OUTPUT)
	assert(error == OK, "Could not save Travessia height map")
	print("TRAVESSIA_DEPTH_OK ", OUTPUT, " ", DEPTH_SIZE.x, "x", DEPTH_SIZE.y)
	quit()


func _height_for_pixel(color: Color, uv: Vector2) -> float:
	var luminance := color.get_luminance()
	var saturation := color.s
	var hue := color.h
	var is_water := hue >= 0.47 and hue <= 0.62 and saturation >= 0.38
	if is_water:
		return 0.01

	# Dark saturated greens are trees and dense bushes; light yellow-greens are
	# grass and remain near the gameplay plane.
	var is_green := hue >= 0.16 and hue <= 0.46 and saturation >= 0.24
	var vegetation := 0.0
	if is_green:
		vegetation = clampf((0.50 - luminance) / 0.30, 0.0, 1.0)
		vegetation *= clampf((saturation - 0.20) / 0.48, 0.0, 1.0)

	# Stone walls and rock rings are mostly darker and less saturated than the
	# golden lane paving. This also captures their painted contact shadows.
	var stone := clampf((0.43 - luminance) / 0.25, 0.0, 1.0)
	stone *= clampf((0.72 - saturation) / 0.55, 0.0, 1.0)

	# The outer forest and cliff frame should read as the tallest silhouette.
	var edge_distance := minf(minf(uv.x, 1.0 - uv.x), minf(uv.y, 1.0 - uv.y))
	var outer_frame := 1.0 - smoothstep(0.055, 0.145, edge_distance)
	outer_frame *= clampf((0.48 - luminance) / 0.28, 0.0, 1.0)

	var height := maxf(vegetation * 0.84, stone * 0.58)
	height = maxf(height, outer_frame)
	return clampf(height, 0.0, 1.0)
