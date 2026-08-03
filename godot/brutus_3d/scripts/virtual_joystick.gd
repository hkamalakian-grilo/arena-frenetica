class_name FreneticJoystick
extends Control

signal vector_changed(value: Vector2)

@export var radius := 82.0
@export var deadzone := 0.12

var value := Vector2.ZERO
var pointer_id := -1
var mouse_active := false

func _ready() -> void:
	set_process_input(true)
	queue_redraw()

func _center() -> Vector2:
	return size * 0.5

func _set_from_position(local_position: Vector2) -> void:
	var raw := (local_position - _center()) / radius
	if raw.length() > 1.0:
		raw = raw.normalized()
	if raw.length() < deadzone:
		raw = Vector2.ZERO
	value = raw
	vector_changed.emit(value)
	queue_redraw()

func _release() -> void:
	pointer_id = -1
	mouse_active = false
	value = Vector2.ZERO
	vector_changed.emit(value)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and pointer_id < 0:
			pointer_id = event.index
			_set_from_position(event.position)
		elif not event.pressed and event.index == pointer_id:
			_release()
		accept_event()
	elif event is InputEventScreenDrag and event.index == pointer_id:
		_set_from_position(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_active = event.pressed
		if mouse_active:
			_set_from_position(event.position)
		else:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and mouse_active:
		_set_from_position(event.position)
		accept_event()

func _draw() -> void:
	var c := _center()
	draw_circle(c, radius + 13.0, Color(0.02, 0.04, 0.025, 0.66))
	draw_circle(c, radius, Color(0.82, 0.62, 0.2, 0.2))
	draw_arc(c, radius, 0.0, TAU, 64, Color(1.0, 0.78, 0.27, 0.72), 4.0)
	var knob := c + value * radius
	draw_circle(knob, 36.0, Color(0.95, 0.58, 0.12, 0.9))
	draw_arc(knob, 36.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.48, 1.0), 4.0)
