extends SceneTree

## Separates the remaining three jungle camps from the already modular terrain.

const SOURCE := "res://assets/maps/travessia_terrain_v4.png"
const SOURCE_DEPTH := "res://assets/maps/travessia_depth_v2.png"
const OUTPUT_TERRAIN := "res://assets/maps/travessia_terrain_v5.png"
const OUTPUT_DEPTH := "res://assets/maps/travessia_depth_v3.png"
const CAMPS := [
	{
		"id": "upper_right",
		"region": Rect2i(418, 300, 320, 360),
		"center": Vector2(160.0, 180.0),
		"radii": Vector2(124.0, 188.0),
	},
	{
		"id": "lower_left",
		"region": Rect2i(175, 980, 320, 450),
		"center": Vector2(160.0, 238.0),
		"radii": Vector2(124.0, 220.0),
		"mask_min_y": 58.0,
	},
	{
		"id": "lower_right",
		"region": Rect2i(418, 980, 320, 450),
		"center": Vector2(160.0, 238.0),
		"radii": Vector2(124.0, 220.0),
		"mask_min_y": 58.0,
	},
]


func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	var source_depth := Image.load_from_file(SOURCE_DEPTH)
	assert(not source.is_empty() and not source_depth.is_empty(),
		"Modular terrain sources must be readable")
	var terrain := source.duplicate()
	var terrain_depth := source_depth.duplicate()

	for data in CAMPS:
		_build_camp(data, source, source_depth, terrain, terrain_depth)

	assert(terrain.save_png(OUTPUT_TERRAIN) == OK,
		"Could not save four-camp modular terrain")
	assert(terrain_depth.save_png(OUTPUT_DEPTH) == OK,
		"Could not save four-camp modular depth")
	print("REMAINING_CAMP_MODULES_OK count=", CAMPS.size())
	quit()


func _build_camp(data: Dictionary, source: Image, source_depth: Image,
		terrain: Image, terrain_depth: Image) -> void:
	var region: Rect2i = data.region
	var clean := Image.load_from_file(
		"res://assets/maps/%s_camp_ground_ai_v1.png" % data.id)
	assert(not clean.is_empty(), "Clean camp reference must be readable")
	clean.resize(region.size.x, region.size.y, Image.INTERPOLATE_LANCZOS)
	var camp := Image.create(region.size.x, region.size.y, false,
		Image.FORMAT_RGBA8)
	var camp_depth := Image.create(region.size.x, region.size.y, false,
		Image.FORMAT_L8)

	for y in range(region.size.y):
		for x in range(region.size.x):
			var local := Vector2(float(x) + 0.5, float(y) + 0.5)
			var pixel := Vector2i(region.position.x + x, region.position.y + y)
			var original := source.get_pixelv(pixel)
			var height := _sample_depth(source_depth, source, pixel)
			var alpha := _object_mask(local, data, height)
			terrain.set_pixelv(pixel, original.lerp(clean.get_pixel(x, y), alpha))
			camp.set_pixel(x, y, Color(original.r, original.g, original.b, alpha))
			camp_depth.set_pixel(x, y,
				Color(height * alpha, height * alpha, height * alpha, 1.0))

	for y in range(terrain_depth.get_height()):
		for x in range(terrain_depth.get_width()):
			var full_pixel := Vector2i(
				floori((float(x) + 0.5) / terrain_depth.get_width()
					* source.get_width()),
				floori((float(y) + 0.5) / terrain_depth.get_height()
					* source.get_height()))
			if not region.has_point(full_pixel):
				continue
			var local := Vector2(full_pixel - region.position)
			var height: float = terrain_depth.get_pixel(x, y).r
			var alpha := _object_mask(local, data, height)
			var remaining: float = height * (1.0 - alpha)
			terrain_depth.set_pixel(x, y,
				Color(remaining, remaining, remaining, 1.0))

	var camp_path := "res://assets/maps/%s_camp_v1.png" % data.id
	var depth_path := "res://assets/maps/%s_camp_depth_v1.png" % data.id
	assert(camp.save_png(camp_path) == OK, "Could not save camp layer")
	assert(camp_depth.save_png(depth_path) == OK, "Could not save camp depth")


func _ellipse_mask(point: Vector2, center: Vector2, radii: Vector2) -> float:
	var normalized := Vector2(
		(point.x - center.x) / radii.x,
		(point.y - center.y) / radii.y)
	return 1.0 - smoothstep(0.84, 1.0, normalized.length())


func _object_mask(point: Vector2, data: Dictionary, height: float) -> float:
	var region_limit := _ellipse_mask(point, data.center, data.radii)
	if data.has("mask_min_y"):
		region_limit *= smoothstep(float(data.mask_min_y),
			float(data.mask_min_y) + 24.0, point.y)
	var authored_object := smoothstep(0.025, 0.14, height)
	return clampf(region_limit * authored_object, 0.0, 1.0)


func _sample_depth(depth: Image, source: Image, pixel: Vector2i) -> float:
	var uv := Vector2(
		(float(pixel.x) + 0.5) / source.get_width(),
		(float(pixel.y) + 0.5) / source.get_height())
	var depth_pixel := Vector2i(
		clampi(floori(uv.x * depth.get_width()), 0, depth.get_width() - 1),
		clampi(floori(uv.y * depth.get_height()), 0, depth.get_height() - 1))
	return depth.get_pixelv(depth_pixel).r
