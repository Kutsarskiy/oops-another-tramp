extends Node


var _restore_timer: SceneTreeTimer = null


func trigger(duration: float, time_scale: float = 0.02) -> void:
	var safe_duration := maxf(duration, 0.0)

	if safe_duration <= 0.0:
		return

	Engine.time_scale = clampf(time_scale, 0.001, 1.0)
	_restore_timer = get_tree().create_timer(safe_duration, true, false, true)
	_restore_timer.timeout.connect(_restore_time_scale)


func _restore_time_scale() -> void:
	Engine.time_scale = 1.0
	_restore_timer = null
