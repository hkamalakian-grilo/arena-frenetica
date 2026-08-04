extends SceneTree

## Separates the first jungle camp while preserving the approved map pixels.
## The generated clean-ground reference is sampled only under the object mask;
## roads, bridge, water and every unrelated pixel remain from the canonical art.

const SOURCE := "res://assets/maps/travessia_terrain_v3.png"
const SOURCE_DEPTH := "res://assets/maps/travessia_depth_v1.png"
const CLEAN_REFERENCE := "res://assets/maps/upper_left_camp_ground_ai_v1.png"
const OUTPUT_TERRAIN := "res://assets/maps/travessia_terrain_v4.png"
const OUTPUT_DEPTH := "res://assets/maps/travessia_depth_v2.png"
const OUTPUT_CAMP := "res://assets/maps/upper_left_camp_v1.png"
const OUTPUT_CAMP_DEPTH := "res://assets/maps/upper_left_camp_depth_v1.png"
const REGION := Rect2i(175, 300, 320, 360)
const TOP_MASK_CENTER := Vector2(160.0, 112.0)
const TOP_MASK_RADII := Vector2(86.0, 103.0)
const LOWER_MASK_CENTER := Vector2(145.0, 222.0)
const LOWER_MASK_RADII := Vector2(78.0, 94.0)


func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	var source_depth := Image.load_from_file(SOURCE_DEPTH)
	var clean_reference := Image.load_from_file(CLEAN_REFERENCE)
	assert(not source.is_empty() and not source_depth.is_empty() \
		and not clean_reference.is_empty(), "Camp module sources must be readable")
	clean_reference.resize(REGION.size.x, REGION.size.y,
		Image.INTERPOLATE_LANCZOS)

	var terrain := source.duplicate()
	var terrain_depth := source_depth.duplicate()
	var camp := Image.create(REGION.size.x, REGION.size.y, false,
		Image.FORMAT_RGBA8)
	var camp_depth := Image.create(REGION.size.x, REGION.size.y, false,
		Image.FORMAT_L8)

	for y in range(REGION.size.y):
		for x in range(REGION.size.x):
			var local := Vector2(float(x) + 0.5, float(y) + 0.5)
			var global_pixel := Vector2i(REGION.position.x + x,
				REGION.position.y + y)
			var original := source.get_pixelv(global_pixel)
			var clean := clean_reference.get_pixel(x, y)
			var authored_height := _sample_depth(source_depth, source,
				global_pixel)
			var alpha := _object_mask(local, authored_height)
			terrain.set_pixelv(global_pixel, original.lerp(clean, alpha))
			camp.set_pixel(x, y, Color(original.r, original.g, original.b, alpha))
			camp_depth.set_pixel(x, y,
				Color(authored_height * alpha, authored_height * alpha,
					authored_height * alpha, 1.0))

	# Remove only the separated camp relief from the full-map height field.
	for y in range(terrain_depth.get_height()):
		for x in range(terrain_depth.get_width()):
			var full_pixel := Vector2i(
				floori((float(x) + 0.5) / terrain_depth.get_width()
					* source.get_width()),
				floori((float(y) + 0.5) / terrain_depth.get_height()
					* source.get_height()))
			if not REGION.has_point(full_pixel):
				continue
			var local := Vector2(full_pixel - REGION.position)
			var height: float = terrain_depth.get_pixel(x, y).r
			var alpha := _object_mask(local, height)
			var remaining: float = height * (1.0 - alpha)
			terrain_depth.set_pixel(x, y,
				Color(remaining, remaining, remaining, 1.0))

	assert(terrain.save_png(OUTPUT_TERRAIN) == OK,
		"Could not save separated Travessia terrain")
	assert(terrain_depth.save_png(OUTPUT_DEPTH) == OK,
		"Could not save separated Travessia depth")
	assert(camp.save_png(OUTPUT_CAMP) == OK,
		"Could not save upper-left camp layer")
	assert(camp_depth.save_png(OUTPUT_CAMP_DEPTH) == OK,
		"Could not save upper-left camp depth")
	print("UPPER_LEFT_CAMP_MODULE_OK region=", REGION)
	quit()


func _sample_depth(depth: Image, source: Image, pixel: Vector2i) -> float:
	var uv := Vector2(
		(float(pixel.x) + 0.5) / source.get_width(),
		(float(pixel.y) + 0.5) / source.get_height())
	var depth_pixel := Vector2i(
		clampi(floori(uv.x * depth.get_width()), 0, depth.get_width() - 1),
		clampi(floori(uv.y * depth.get_height()), 0, depth.get_height() - 1))
	return depth.get_pixelv(depth_pixel).r


func _object_mask(local: Vector2, authored_height: float) -> float:
	var top := _ellipse_mask(local, TOP_MASK_CENTER, TOP_MASK_RADII)
	var lower := _ellipse_mask(local, LOWER_MASK_CENTER, LOWER_MASK_RADII)
	# Broad authored silhouettes guarantee that no object remnant is baked into
	# the clean floor. The separated layer still contains the untouched pixels.
	return maxf(top, lower)


func _ellipse_mask(point: Vector2, center: Vector2, radii: Vector2) -> float:
	var normalized := Vector2(
		(point.x - center.x) / radii.x,
		(point.y - center.y) / radii.y)
	return 1.0 - smoothstep(0.84, 1.0, normalized.length())
