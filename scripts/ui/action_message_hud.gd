extends Label

@export var panel_size: Vector2 = Vector2(760.0, 48.0)
@export var bottom_margin: float = 132.0
@export var message_time: float = 1.6

var _time_left: float = 0.0


func _ready() -> void:
	add_to_group("action_message_hud")

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	size = panel_size
	custom_minimum_size = panel_size

	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
	add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)

	text = ""
	visible = false
	_update_position()


func _process(delta: float) -> void:
	_update_position()

	if _time_left <= 0.0:
		return

	_time_left = maxf(_time_left - delta, 0.0)

	if _time_left <= 0.0:
		text = ""
		visible = false


func show_message(message: String) -> void:
	if message.is_empty():
		return

	text = message
	visible = true
	_time_left = message_time
	_update_position()


func _update_position() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	size = panel_size
	position = Vector2(
		(viewport_size.x - panel_size.x) * 0.5,
		viewport_size.y - panel_size.y - bottom_margin
	)
