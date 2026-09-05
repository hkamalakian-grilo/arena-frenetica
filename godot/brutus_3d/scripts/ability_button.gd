class_name AbilityButton
extends Button

## Touch ability button with the mobile MOBA contract:
## tap = quick cast, hold and drag = manual aim (release to cast, drag back
## onto the button to cancel). Draws a radial cooldown fill and the aim stick.
## Screen drag (x right, y down) maps directly to world (x, z).

signal quick_cast
signal aim_started
signal aim_changed(direction: Vector2)
signal aim_cast(direction: Vector2)
signal aim_cancelled

@export var aimable := true
@export var repeat_while_held := false
@export var drag_threshold := 14.0
@export var stick_radius := 96.0
@export var repeat_interval := 0.22

var cooldown_ratio := 1.0
var cooldown_left := 0.0
var pointer_id := -2
var press_position := Vector2.ZERO
var aiming := false
var aim_direction := Vector2.ZERO
var held := false
var repeat_timer := 0.0
var overlay: Control
var ready_text := ""


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	ready_text = text
	overlay = AbilityOverlay.new()
	overlay.owner_button = self
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


func _process(delta: float) -> void:
	if held and repeat_while_held and not disabled:
		repeat_timer -= delta / maxf(Engine.time_scale, 0.001)
		if repeat_timer <= 0.0:
			repeat_timer = repeat_interval
			quick_cast.emit()


## `left` seconds remaining out of `total`; ratio 1.0 means ready.
func set_cooldown(left: float, total: float) -> void:
	cooldown_left = maxf(0.0, left)
	var next_ratio := 1.0 if total <= 0.0 else clampf(1.0 - left / total, 0.0, 1.0)
	if not is_equal_approx(next_ratio, cooldown_ratio):
		cooldown_ratio = next_ratio
		overlay.queue_redraw()
	text = ("%s\n%.1f" % [ready_text.left(1), left]) if left > 0.0 else ready_text


func is_aiming() -> bool:
	return aiming


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and pointer_id == -2:
			_press(event.index, event.position)
		elif not event.pressed and event.index == pointer_id:
			_release(event.position)
		accept_event()
	elif event is InputEventScreenDrag and event.index == pointer_id:
		_drag(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and pointer_id == -2:
			_press(-1, event.position)
		elif not event.pressed and pointer_id == -1:
			_release(event.position)
		accept_event()
	elif event is InputEventMouseMotion and pointer_id == -1:
		_drag(event.position)
		accept_event()


func _press(index: int, at_position: Vector2) -> void:
	if disabled:
		return
	pointer_id = index
	press_position = at_position
	aiming = false
	aim_direction = Vector2.ZERO
	held = true
	repeat_timer = 0.0
	if not aimable:
		quick_cast.emit()
		repeat_timer = repeat_interval
	overlay.queue_redraw()


func _drag(at_position: Vector2) -> void:
	if pointer_id == -2 or not aimable:
		return
	var offset := at_position - press_position
	if not aiming:
		if offset.length() < drag_threshold:
			return
		aiming = true
		aim_started.emit()
	aim_direction = offset.normalized() if offset.length_squared() > 0.001 else Vector2.ZERO
	aim_changed.emit(aim_direction)
	overlay.queue_redraw()


func _release(at_position: Vector2) -> void:
	var was_aiming := aiming
	var direction := aim_direction
	var inside := Rect2(Vector2.ZERO, size).grow(6.0).has_point(at_position)
	pointer_id = -2
	held = false
	aiming = false
	aim_direction = Vector2.ZERO
	overlay.queue_redraw()
	if disabled:
		return
	if not aimable:
		return
	if was_aiming:
		if inside or direction.length_squared() < 0.001:
			aim_cancelled.emit()
		else:
			aim_cast.emit(direction)
	else:
		quick_cast.emit()


func _stick_end() -> Vector2:
	return size * 0.5 + aim_direction * stick_radius


class AbilityOverlay:
	extends Control

	var owner_button: AbilityButton

	func _draw() -> void:
		if owner_button == null:
			return
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5
		var ratio := owner_button.cooldown_ratio
		if ratio < 1.0:
			# Dark wedge for the remaining cooldown, sweeping clockwise from 12h.
			var start := -PI * 0.5
			var end := start + TAU * (1.0 - ratio)
			var points := PackedVector2Array([center])
			var steps := 28
			for index in range(steps + 1):
				var angle := lerpf(start, end, float(index) / steps)
				points.append(center + Vector2(cos(angle), sin(angle)) * (radius - 3.0))
			draw_colored_polygon(points, Color(0.02, 0.03, 0.02, 0.62))
			draw_arc(center, radius - 3.0, start, end, 40, Color(1.0, 0.85, 0.4, 0.9), 3.0)
		if owner_button.aiming:
			var stick_end := owner_button._stick_end()
			draw_line(center, stick_end, Color(1.0, 0.92, 0.6, 0.85), 5.0)
			draw_circle(stick_end, 18.0, Color(1.0, 0.82, 0.35, 0.95))
			draw_arc(center, radius + 4.0, 0.0, TAU, 48, Color(1.0, 0.5, 0.35, 0.8), 3.0)
