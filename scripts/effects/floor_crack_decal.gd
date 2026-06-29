extends Node2D
class_name FloorCrackDecal


@export var crack_radius: float = 145.0
@export var branch_count: int = 11
@export var branch_segments: int = 4
@export var crack_color: Color = Color(0.03, 0.025, 0.02, 0.58)
@export var line_width: float = 4.0

var _branches: Array[PackedVector2Array] = []


func _ready() -> void:
	z_index = 1
	_generate_cracks()
	queue_redraw()


func _draw() -> void:
	for branch in _branches:
		if branch.size() < 2:
			continue

		for i in range(branch.size() - 1):
			var width_t := 1.0 - float(i) / float(maxi(branch.size() - 1, 1))
			draw_line(branch[i], branch[i + 1], crack_color, maxf(line_width * width_t, 1.0))


func _generate_cracks() -> void:
	_branches.clear()

	for i in range(branch_count):
		var angle := TAU * float(i) / float(maxi(branch_count, 1)) + randf_range(-0.22, 0.22)
		var direction := Vector2.RIGHT.rotated(angle)
		var points := PackedVector2Array()
		var point := Vector2.ZERO
		points.append(point)

		var branch_length := crack_radius * randf_range(0.55, 1.0)

		for segment in range(branch_segments):
			var segment_t := float(segment + 1) / float(branch_segments)
			var segment_distance := branch_length * segment_t
			var jitter := direction.orthogonal() * randf_range(-18.0, 18.0) * segment_t
			point = direction * segment_distance + jitter
			points.append(point)

		_branches.append(points)

		if randf() < 0.55:
			_add_side_crack(points, direction)


func _add_side_crack(source_points: PackedVector2Array, direction: Vector2) -> void:
	if source_points.size() < 3:
		return

	var start_index := randi_range(1, source_points.size() - 2)
	var start_point := source_points[start_index]
	var side := -1.0 if randf() < 0.5 else 1.0
	var side_direction := direction.rotated(randf_range(0.45, 0.95) * side).normalized()
	var points := PackedVector2Array()
	points.append(start_point)
	points.append(start_point + side_direction * crack_radius * randf_range(0.16, 0.32))
	_branches.append(points)
