extends Node2D
class_name RocketExplosionEffect


@export var duration: float = 0.28
@export var radius: float = 58.0
@export var spark_count: int = 12
@export var shake_duration: float = 0.5
@export var shake_strength: float = 15.0

var _elapsed: float = 0.0
var _shake_elapsed: float = 0.0
var _spark_directions: Array[Vector2] = []
var _spark_lengths: Array[float] = []
var _camera: Camera2D = null


func _ready() -> void:
	z_index = 70
	_camera = get_viewport().get_camera_2d()
	for i in range(spark_count):
		_spark_directions.append(Vector2.RIGHT.rotated(randf() * TAU))
		_spark_lengths.append(randf_range(radius * 0.45, radius * 0.95))


func _process(delta: float) -> void:
	_elapsed += delta
	_update_camera_shake(delta)

	if _elapsed >= duration:
		if _shake_elapsed >= shake_duration:
			queue_free()
		return

	queue_redraw()


func _draw() -> void:
	var t := clampf(_elapsed / maxf(duration, 0.01), 0.0, 1.0)
	var alpha := 1.0 - t
	var flash_radius := lerpf(radius * 0.38, radius * 0.95, t)
	var ring_radius := lerpf(radius * 0.22, radius, t)

	draw_circle(Vector2.ZERO, flash_radius, Color(1.0, 0.56, 0.08, 0.38 * alpha))
	draw_circle(Vector2.ZERO, flash_radius * 0.48, Color(1.0, 0.92, 0.52, 0.72 * alpha))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 42, Color(1.0, 0.18, 0.04, 0.92 * alpha), 4.0)

	for i in range(_spark_directions.size()):
		var direction := _spark_directions[i]
		var length := _spark_lengths[i] * lerpf(0.35, 1.0, t)
		var start := direction * radius * 0.2
		var end := direction * length
		draw_line(start, end, Color(1.0, 0.78, 0.24, 0.8 * alpha), 3.0)


func _update_camera_shake(delta: float) -> void:
	if shake_duration <= 0.0 or shake_strength <= 0.0:
		return

	if _shake_elapsed >= shake_duration:
		return

	_shake_elapsed = minf(_shake_elapsed + delta, shake_duration)

	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()

	if _camera == null or not _camera.has_method("set_shake_offset"):
		return

	var t := _shake_elapsed / maxf(shake_duration, 0.01)
	var strength := lerpf(shake_strength, 0.0, t)
	var shake_offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	_camera.call("set_shake_offset", shake_offset)
