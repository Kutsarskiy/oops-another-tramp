extends Control


@export var cursor_texture: Texture2D = preload("res://assets/ui/cursors/crosshair026.png")
@export var cursor_scale: float = 0.25

var _mouse_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(_delta: float) -> void:
	_mouse_position = get_viewport().get_mouse_position()
	queue_redraw()


func _draw() -> void:
	if cursor_texture == null:
		return

	var texture_size := cursor_texture.get_size() * cursor_scale
	var cursor_rect := Rect2(_mouse_position - texture_size * 0.5, texture_size)
	draw_texture_rect(cursor_texture, cursor_rect, false)
