extends SceneTree

## Creates the hatch-state island layer. Only the narrow north/south entrance
## corridors receive masonry sampled from the approved lateral bridge, so every
## unrelated authored island pixel remains untouched.

const SOURCE := "res://assets/maps/dragon_island_full_v1.png"
const MASONRY_SOURCE := "res://assets/maps/travessia_terrain_v3.png"
const OUTPUT := "res://assets/maps/dragon_island_open_full_v1.png"
const NORTH_ENTRANCE := Rect2i(408, 694, 98, 66)
const SOUTH_ENTRANCE := Rect2i(408, 925, 98, 66)
const MASONRY_ROWS := [
	Rect2i(164, 820, 57, 20),
	Rect2i(164, 842, 57, 19),
]


func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	var masonry := Image.load_from_file(MASONRY_SOURCE)
	assert(not source.is_empty() and not masonry.is_empty(),
		"Dragon island and masonry sources must be readable")
	var opened := source.duplicate()
	_paint_corridor(opened, masonry, NORTH_ENTRANCE, 0.84, 1.0)
	_paint_corridor(opened, masonry, SOUTH_ENTRANCE, 1.0, 1.0)
	assert(opened.save_png(OUTPUT) == OK,
		"Could not save open dragon-island layer")
	print("OPEN_DRAGON_ISLAND_OK corridors=2")
	quit()


func _paint_corridor(image: Image, masonry: Image,
		corridor: Rect2i, start_width_scale: float,
		end_width_scale: float) -> void:
	for y in range(corridor.position.y, corridor.end.y):
		var progress := float(y - corridor.position.y) \
			/ float(maxi(1, corridor.size.y - 1))
		var row_width := float(corridor.size.x) * lerpf(
			start_width_scale, end_width_scale, progress)
		var row_left := float(corridor.position.x) \
			+ (float(corridor.size.x) - row_width) * 0.5
		for x in range(corridor.position.x, corridor.end.x):
			if float(x) < row_left or float(x) >= row_left + row_width:
				continue
			var local_y := y - corridor.position.y
			var row_index := floori(float(local_y) / 20.0) \
				% MASONRY_ROWS.size()
			var region: Rect2i = MASONRY_ROWS[row_index]
			var source_x := region.position.x + clampi(floori(
				(float(x) - row_left) / row_width
					* region.size.x), 0, region.size.x - 1)
			var source_y := region.position.y + clampi(
				local_y % 20, 0, region.size.y - 1)
			var color := masonry.get_pixel(source_x, source_y)
			color.a = 1.0
			image.set_pixel(x, y, color)
