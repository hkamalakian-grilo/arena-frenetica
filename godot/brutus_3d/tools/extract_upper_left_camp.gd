extends SceneTree

const SOURCE := "res://assets/maps/travessia_terrain_v3.png"
const OUTPUT := "res://tools/upper_left_camp_source.png"
const REGION := Rect2i(175, 300, 320, 360)


func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	assert(not source.is_empty(), "Travessia source art must be readable")
	var crop := source.get_region(REGION)
	var error := crop.save_png(OUTPUT)
	assert(error == OK, "Could not save upper-left camp crop")
	print("UPPER_LEFT_CAMP_SOURCE_OK ", OUTPUT, " region=", REGION)
	quit()
