extends Label


@export var update_interval: float = 0.25

var _time_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_text()


func _process(delta: float) -> void:
	_time_left -= delta

	if _time_left > 0.0:
		return

	_time_left = update_interval
	_update_text()


func _update_text() -> void:
	text = "%d FPS" % Engine.get_frames_per_second()
