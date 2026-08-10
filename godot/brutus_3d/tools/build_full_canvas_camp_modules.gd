extends SceneTree

## Places every cropped jungle module on a transparent full-map canvas.
## The runtime can then use the exact same mesh, UVs and height map as the
## terrain, preventing perspective seams at the module boundaries.

const MAP_SIZE := Vector2i(913, 1723)
const CAMPS := [
	{
		"id": "upper_left",
		"region": Rect2i(175, 300, 320, 360),
	},
	{
		"id": "upper_right",
		"region": Rect2i(418, 300, 320, 360),
	},
	{
		"id": "lower_left",
		"region": Rect2i(175, 980, 320, 450),
	},
	{
		"id": "lower_right",
		"region": Rect2i(418, 980, 320, 450),
	},
]


func _initialize() -> void:
	for data in CAMPS:
		_build_full_canvas(data)
	print("FULL_CANVAS_CAMP_MODULES_OK count=", CAMPS.size())
	quit()


func _build_full_canvas(data: Dictionary) -> void:
	var id: String = data.id
	var region: Rect2i = data.region
	var crop := Image.load_from_file(
		"res://assets/maps/%s_camp_v1.png" % id)
	assert(not crop.is_empty(), "Camp crop must be readable: %s" % id)
	assert(crop.get_size() == region.size,
		"Camp crop dimensions must match its authored region: %s" % id)
	var canvas := Image.create(MAP_SIZE.x, MAP_SIZE.y, false,
		Image.FORMAT_RGBA8)
	canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
	canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, region.size), region.position)
	var output := "res://assets/maps/%s_camp_full_v1.png" % id
	assert(canvas.save_png(output) == OK,
		"Could not save full-map camp layer: %s" % id)
