extends SceneTree

## Separates the remaining approved Travessia artwork into full-canvas 2.5D
## layers. Every layer keeps the original pixels and global UVs, while the
## shared terrain receives a neutral underpaint and a flattened height map.

const SOURCE := "res://assets/maps/travessia_terrain_v5.png"
const SOURCE_DEPTH := "res://assets/maps/travessia_depth_v1.png"
const OUTPUT_TERRAIN := "res://assets/maps/travessia_terrain_v6.png"
const OUTPUT_DEPTH := "res://assets/maps/travessia_depth_v4.png"
const MODULE_IDS := [
	"north_boundary",
	"south_boundary",
	"west_outer_forest",
	"east_outer_forest",
	"north_river_bank",
	"south_river_bank",
	"dragon_island",
	"left_lane_bridge",
	"right_lane_bridge",
]
const CAMP_IDS := [
	"upper_left", "upper_right", "lower_left", "lower_right",
]


func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	var source_depth := Image.load_from_file(SOURCE_DEPTH)
	assert(not source.is_empty() and not source_depth.is_empty(),
		"Canonical map sources must be readable")

	var base := source.duplicate()
	var base_depth := source_depth.duplicate()
	var underpaint := source.duplicate()
	underpaint.resize(92, 173, Image.INTERPOLATE_LANCZOS)
	underpaint.resize(source.get_width(), source.get_height(),
		Image.INTERPOLATE_LANCZOS)

	var modules: Array[Image] = []
	for _id in MODULE_IDS:
		var layer := Image.create(source.get_width(), source.get_height(), false,
			Image.FORMAT_RGBA8)
		layer.fill(Color(0.0, 0.0, 0.0, 0.0))
		modules.append(layer)
	var camp_layers: Array[Image] = []
	for camp_id in CAMP_IDS:
		var camp := Image.load_from_file(
			"res://assets/maps/%s_camp_full_v1.png" % camp_id)
		assert(not camp.is_empty(), "Full-canvas camp layer must exist")
		camp_layers.append(camp)

	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var height := _sample_depth(source_depth, source, x, y)
			var owner := _module_owner(x, y, height)
			if owner < 0:
				continue
			modules[owner].set_pixel(x, y, source.get_pixel(x, y))
			base.set_pixel(x, y, underpaint.get_pixel(x, y))

	# The height map is intentionally lower-resolution than the color texture.
	# Convert its texels back to full-map coordinates before clearing relief.
	for depth_y in range(base_depth.get_height()):
		for depth_x in range(base_depth.get_width()):
			var x := clampi(floori((float(depth_x) + 0.5)
				/ base_depth.get_width() * source.get_width()),
				0, source.get_width() - 1)
			var y := clampi(floori((float(depth_y) + 0.5)
				/ base_depth.get_height() * source.get_height()),
				0, source.get_height() - 1)
			var height := source_depth.get_pixel(depth_x, depth_y).r
			var clear_relief := _module_owner(x, y, height) >= 0
			if not clear_relief:
				for camp in camp_layers:
					if camp.get_pixel(x, y).a >= 0.05:
						clear_relief = true
						break
			if clear_relief:
				base_depth.set_pixel(depth_x, depth_y, Color.BLACK)

	assert(base.save_png(OUTPUT_TERRAIN) == OK,
		"Could not save complete modular terrain")
	assert(base_depth.save_png(OUTPUT_DEPTH) == OK,
		"Could not save flattened modular terrain depth")
	for index in range(MODULE_IDS.size()):
		var output := "res://assets/maps/%s_full_v1.png" % MODULE_IDS[index]
		assert(modules[index].save_png(output) == OK,
			"Could not save map module: %s" % MODULE_IDS[index])
	print("COMPLETE_MAP_MODULES_OK count=", MODULE_IDS.size())
	quit()


func _module_owner(x: int, y: int, height: float) -> int:
	# Complete authored pieces are selected first, including their flat inner
	# surfaces. Remaining boundaries use relief to avoid stealing lane pixels.
	if _inside_ellipse(x, y, Vector2(456.0, 842.0), Vector2(181.0, 207.0)):
		return 6 # DragonIsland
	if x >= 130 and x <= 259 and y >= 755 and y <= 918:
		return 7 # LeftLaneBridge
	if x >= 654 and x <= 783 and y >= 755 and y <= 918:
		return 8 # RightLaneBridge
	# Keep the outermost authored edge continuous. Splitting this row only by
	# height would expose a thin underpaint seam at the entrance gates.
	if y <= 110:
		return 0 # NorthBoundary
	if y >= 1580:
		return 1 # SouthBoundary
	if height < 0.055:
		return -1
	if y <= 365:
		return 0 # NorthBoundary
	if y >= 1360:
		return 1 # SouthBoundary
	if x <= 205 and y >= 300 and y <= 1420:
		return 2 # WestOuterForest
	if x >= 708 and y >= 300 and y <= 1420:
		return 3 # EastOuterForest
	if y >= 520 and y <= 780 and x >= 165 and x <= 748:
		return 4 # NorthRiverBank
	if y >= 915 and y <= 1135 and x >= 165 and x <= 748:
		return 5 # SouthRiverBank
	return -1


func _inside_ellipse(x: int, y: int, center: Vector2,
		radii: Vector2) -> bool:
	var point := Vector2(
		(float(x) - center.x) / radii.x,
		(float(y) - center.y) / radii.y)
	return point.length_squared() <= 1.0


func _sample_depth(depth: Image, source: Image, x: int, y: int) -> float:
	var depth_x := clampi(floori((float(x) + 0.5) / source.get_width()
		* depth.get_width()), 0, depth.get_width() - 1)
	var depth_y := clampi(floori((float(y) + 0.5) / source.get_height()
		* depth.get_height()), 0, depth.get_height() - 1)
	return depth.get_pixel(depth_x, depth_y).r
