class_name FreneticJoystick
extends Control

## Floating analog stick: the base appears where the player first touches
## inside this control (the lower-left half of the screen) and follows the
## classic MOBA feel. A faint ghost marks the rest position while idle.

signal vector_changed(value: Vector2)

@export var radius := 82.0
@export var deadzone := 0.12
## Rest position of the ghost base, relative to the bottom-left corner.
@export var rest_offset := Vector2(128.0, -128.0)

var value := Vector2.ZERO
var pointer_id := -1
var mouse_active := false
var base_center := Vector2.ZERO
var active := false

func _ready() -> void:
	set_process_input(true)
	queue_redraw()

func _rest_center() -> Vector2:
	return Vector2(rest_offset.x, size.y + rest_offset.y)

func _center() -> Vector2:
	return base_center if active else _rest_center()

func _begin(at_position: Vector2) -> void:
	active = true
	base_center = at_position
	_set_from_position(at_position)

func _set_from_position(local_position: Vector2) -> void:
	var raw := (local_position - _center()) / radius
	if raw.length() > 1.0:
		# Drag the base along so the stick never feels stuck at the rim.
		base_center = local_position - raw.normalized() * radius
		raw = raw.normalized()
	if raw.length() < deadzone:
		raw = Vector2.ZERO
	value = raw
	vector_changed.emit(value)
	queue_redraw()

func _release() -> void:
	pointer_id = -1
	mouse_active = false
	active = false
	value = Vector2.ZERO
	vector_changed.emit(value)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and pointer_id < 0:
			pointer_id = event.index
			_begin(event.position)
		elif not event.pressed and event.index == pointer_id:
			_release()
		accept_event()
	elif event is InputEventScreenDrag and event.index == pointer_id:
		_set_from_position(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_active = event.pressed
		if mouse_active:
			_begin(event.position)
		else:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and mouse_active:
		_set_from_position(event.position)
		accept_event()

func _draw() -> void:
	var c := _center()
	var alpha := 1.0 if active else 0.45
	draw_circle(c + Vector2(0, 4), radius + 15.0, Color(0, 0, 0, 0.35 * alpha))
	draw_circle(c, radius + 13.0, Color(0.03, 0.05, 0.04, 0.78 * alpha))
	draw_circle(c, radius + 2.0, Color(0.10, 0.14, 0.10, 0.6 * alpha))
	draw_arc(c, radius + 8.0, 0.0, TAU, 64, Color(1.0, 0.80, 0.30, 0.85 * alpha), 4.0)
	draw_arc(c, radius * 0.45, 0.0, TAU, 40, Color(1.0, 0.85, 0.45, 0.25 * alpha), 2.0)
	for index in range(4):
		var angle := index * PI * 0.5
		var tip := c + Vector2(cos(angle), sin(angle)) * (radius - 6.0)
		draw_circle(tip, 3.0, Color(1.0, 0.85, 0.45, 0.5 * alpha))
	var knob := c + value * radius
	draw_circle(knob + Vector2(0, 3), 38.0, Color(0, 0, 0, 0.35 * alpha))
	draw_circle(knob, 36.0, Color(0.95, 0.58, 0.12, 0.95 * alpha))
	draw_circle(knob + Vector2(-8, -10), 14.0, Color(1.0, 0.85, 0.45, 0.35 * alpha))
	draw_arc(knob, 36.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.48, alpha), 4.0)
