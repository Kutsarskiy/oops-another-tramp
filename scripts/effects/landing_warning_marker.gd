extends Node2D
class_name LandingWarningMarker


@export var warning_radius: float = 115.0
@export var warning_color: Color = Color(1.0, 0.18, 0.08, 0.85)
@export var fill_alpha: float = 0.16
@export var line_width: float = 4.0
@export var blink_enabled: bool = false
@export var blink_frequency: float = 4.0
@export var follow_target: Node2D = null

var _time: float = 0.0
var _is_locked: bool = false


func _process(delta: float) -> void:
	_time += delta

	if not _is_locked and follow_target != null and is_instance_valid(follow_target):
		global_position = follow_target.global_position

	queue_redraw()


func lock_to_position(new_global_position: Vector2) -> void:
	_is_locked = true
	follow_target = null
	blink_enabled = false
	global_position = new_global_position
	queue_redraw()


func _draw() -> void:
	if blink_enabled and sin(_time * TAU * blink_frequency) < -0.15:
		return

	var pulse := 0.5 + 0.5 * sin(_time * TAU * 2.0)
	var outer_radius := warning_radius + lerpf(0.0, 8.0, pulse)
	var color := warning_color
	var fill_color := Color(color.r, color.g, color.b, fill_alpha)

	draw_circle(Vector2.ZERO, warning_radius, fill_color)
	draw_arc(Vector2.ZERO, outer_radius, 0.0, TAU, 72, color, line_width)
	draw_arc(Vector2.ZERO, warning_radius * 0.62, 0.0, TAU, 72, Color(color.r, color.g, color.b, color.a * 0.72), line_width * 0.65)
	draw_line(Vector2(-warning_radius, 0.0), Vector2(warning_radius, 0.0), Color(color.r, color.g, color.b, color.a * 0.45), line_width * 0.5)
	draw_line(Vector2(0.0, -warning_radius), Vector2(0.0, warning_radius), Color(color.r, color.g, color.b, color.a * 0.45), line_width * 0.5)
