extends Control


const IndicatorTexture: Texture2D = preload("res://assets/ui/cursors/crosshair022.png")

@export var edge_padding: float = 42.0
@export var arrow_size: float = 50.0
@export var marker_color: Color = Color(1.0, 1.0, 1.0, 0.96)

var _boss: Node2D = null
var _camera: Camera2D = null
var _marker_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide()
	BossManager.boss_spawned.connect(_on_boss_spawned)
	BossManager.boss_defeated.connect(_on_boss_defeated)


func _process(_delta: float) -> void:
	_update_marker()


func _draw() -> void:
	var center := size * 0.5
	var direction := _marker_direction
	var texture_size := IndicatorTexture.get_size()
	var scale_value := arrow_size * 2.0 / maxf(texture_size.x, texture_size.y)
	var transform := Transform2D(direction.angle() + PI * 0.5, center)
	draw_set_transform_matrix(transform.scaled(Vector2.ONE * scale_value))
	draw_texture(IndicatorTexture, -texture_size * 0.5, marker_color)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _on_boss_spawned(boss: BaseBoss) -> void:
	_boss = boss
	_camera = get_viewport().get_camera_2d()


func _on_boss_defeated(boss: BaseBoss) -> void:
	if _boss == boss:
		_boss = null
		hide()


func _update_marker() -> void:
	if _boss == null or not is_instance_valid(_boss):
		hide()
		return

	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()

	if _camera == null:
		hide()
		return

	var viewport_size := get_viewport_rect().size
	var screen_center := viewport_size * 0.5
	var boss_screen_position := screen_center + (_boss.global_position - _camera.global_position) * _camera.zoom

	if Rect2(Vector2.ZERO, viewport_size).has_point(boss_screen_position):
		hide()
		return

	var direction := boss_screen_position - screen_center

	if direction.length_squared() <= 0.001:
		hide()
		return

	direction = direction.normalized()
	_marker_direction = direction
	var edge_position := _get_edge_position(screen_center, viewport_size, direction)
	custom_minimum_size = Vector2.ONE * arrow_size * 2.0
	size = custom_minimum_size
	position = edge_position
	show()
	queue_redraw()


func _get_edge_position(screen_center: Vector2, viewport_size: Vector2, direction: Vector2) -> Vector2:
	var half_size := viewport_size * 0.5 - Vector2.ONE * edge_padding
	var tx := INF if absf(direction.x) <= 0.001 else half_size.x / absf(direction.x)
	var ty := INF if absf(direction.y) <= 0.001 else half_size.y / absf(direction.y)
	var distance := minf(tx, ty)
	var marker_center := screen_center + direction * distance

	return marker_center - Vector2.ONE * arrow_size
