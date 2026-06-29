extends Control


const IndicatorTexture: Texture2D = preload("res://assets/ui/cursors/crosshair022.png")

@export var danger_distance: float = 760.0
@export var edge_padding: float = 76.0
@export var marker_size: float = 24.0
@export var marker_color: Color = Color(1.0, 1.0, 1.0, 0.96)

var _camera: Camera2D = null
var _player: Node2D = null
var _markers: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	_update_markers()
	queue_redraw()


func _draw() -> void:
	for marker in _markers:
		var position_value: Vector2 = marker["position"]
		var direction: Vector2 = marker["direction"]
		var pulse := 1.0 + sin(_time * TAU * 4.0) * 0.12
		var size_value := marker_size * pulse
		var texture_size := IndicatorTexture.get_size()
		var scale_value := size_value * 2.0 / maxf(texture_size.x, texture_size.y)
		var transform := Transform2D(direction.angle() + PI * 0.5, position_value)
		draw_set_transform_matrix(transform.scaled(Vector2.ONE * scale_value))
		draw_texture(IndicatorTexture, -texture_size * 0.5, marker_color)
		draw_set_transform_matrix(Transform2D.IDENTITY)


func _update_markers() -> void:
	_markers.clear()

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D

	if _player == null:
		return

	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()

	if _camera == null:
		return

	var viewport_size := get_viewport_rect().size
	var screen_center := viewport_size * 0.5
	var screen_rect := Rect2(Vector2.ZERO, viewport_size)

	for rocket in get_tree().get_nodes_in_group("techno_king_rocket"):
		var rocket_node := rocket as Node2D

		if rocket_node == null or not is_instance_valid(rocket_node):
			continue

		if rocket_node.global_position.distance_to(_player.global_position) > danger_distance:
			continue

		var rocket_screen_position := screen_center + (rocket_node.global_position - _camera.global_position) * _camera.zoom

		if screen_rect.has_point(rocket_screen_position):
			continue

		var direction := rocket_screen_position - screen_center

		if direction.length_squared() <= 0.001:
			continue

		direction = direction.normalized()
		_markers.append({
			"position": _get_edge_position(screen_center, viewport_size, direction),
			"direction": direction
		})


func _get_edge_position(screen_center: Vector2, viewport_size: Vector2, direction: Vector2) -> Vector2:
	var half_size := viewport_size * 0.5 - Vector2.ONE * edge_padding
	var tx := INF if absf(direction.x) <= 0.001 else half_size.x / absf(direction.x)
	var ty := INF if absf(direction.y) <= 0.001 else half_size.y / absf(direction.y)
	var distance := minf(tx, ty)

	return screen_center + direction * distance
