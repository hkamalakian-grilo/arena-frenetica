extends SceneTree

const SOURCE := "res://assets/maps/travessia_terrain_v3.png"
const CAMPS := [
	{"name": "upper_right", "region": Rect2i(418, 300, 320, 360)},
	{"name": "lower_left", "region": Rect2i(175, 1063, 320, 360)},
	{"name": "lower_right", "region": Rect2i(418, 1063, 320, 360)},
]


func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	assert(not source.is_empty(), "Travessia source art must be readable")
	for data in CAMPS:
		var crop := source.get_region(data.region)
		var output := "res://tools/%s_camp_source.png" % data.name
		assert(crop.save_png(output) == OK, "Could not save camp crop")
		print("CAMP_SOURCE_OK ", output, " region=", data.region)
	quit()
