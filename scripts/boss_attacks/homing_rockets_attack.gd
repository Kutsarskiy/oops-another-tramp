extends BossAttack
class_name HomingRocketsAttack


const HomingRocketScript: Script = preload("res://scripts/projectiles/enemy/techno_king_homing_rocket.gd")

var windup_duration: float = 1.0
var rocket_speed: float = 400.0
var rocket_hp: int = 3
var rocket_lifetime: float = -1.0
var launch_offsets: Array[Vector2] = [
	Vector2(-86.0, -6.0),
	Vector2(86.0, -6.0)
]

var _windup_left: float = 0.0
var _is_winding_up: bool = false


func update(delta: float) -> void:
	if owner_boss == null:
		return

	if _windup_left > 0.0:
		_windup_left = maxf(_windup_left - delta, 0.0)
		show_debug_attack("Homing Rockets")

		if _windup_left <= 0.0:
			_launch_rockets()
			_finish_windup()

		return


func cancel() -> void:
	_windup_left = 0.0
	_finish_windup()


func force_start() -> bool:
	if is_busy():
		return false

	return _start_windup()


func is_busy() -> bool:
	return _windup_left > 0.0 or _is_winding_up


func _start_windup() -> bool:
	var player := owner_boss.get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		return false

	_windup_left = windup_duration
	_is_winding_up = true
	show_debug_attack("Homing Rockets")

	if owner_boss.has_method("set_techno_king_visual_override"):
		owner_boss.call("set_techno_king_visual_override", &"phase_1_rocket_launch")

	return true


func _finish_windup() -> void:
	if _is_winding_up and owner_boss != null and owner_boss.has_method("clear_techno_king_visual_override"):
		owner_boss.call("clear_techno_king_visual_override", &"phase_1_rocket_launch")

	_is_winding_up = false
	clear_debug_attack("Homing Rockets")


func _launch_rockets() -> void:
	var parent_node := owner_boss.get_parent()
	var player := owner_boss.get_tree().get_first_node_in_group("player") as Node2D

	if parent_node == null or player == null:
		return

	for i in range(launch_offsets.size()):
		var spawn_position := owner_boss.global_position + launch_offsets[i]
		var initial_direction := player.global_position - spawn_position

		if initial_direction.length_squared() <= 0.001:
			initial_direction = Vector2.DOWN

		initial_direction = initial_direction.normalized().rotated(deg_to_rad((-18.0 if i == 0 else 18.0)))
		var rocket = HomingRocketScript.new()
		rocket.configure(
			initial_direction,
			rocket_speed,
			rocket_hp,
			rocket_lifetime,
			-1.0 if i == 0 else 1.0
		)
		parent_node.add_child(rocket)
		rocket.global_position = spawn_position
