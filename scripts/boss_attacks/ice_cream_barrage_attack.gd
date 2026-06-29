extends BossAttack
class_name IceCreamBarrageAttack


const BulletScene: PackedScene = preload("res://scenes/projectiles/enemy/sleepy_joe/ice_cream_large_projectile.tscn")
const SplitBulletScene: PackedScene = preload("res://scenes/projectiles/enemy/sleepy_joe/ice_cream_split_projectile.tscn")

var cooldown: float = 10.0
var rage_cooldown: float = 5.0
var windup_duration: float = 1.0
var recovery_duration: float = 1.0
var shot_count: int = 3
var shot_interval: float = 1.0
var aim_area_radius: float = 150.0
var prediction_time: float = 0.35
var large_speed: float = 400.0
var rage_huge_shot_speed: float = 450.0
var large_lifetime: float = 2.4
var large_curve_strength_degrees: float = 30.0
var large_curve_frequency: float = 0.55
var small_speed: float = 350.0
var small_lifetime: float = 2.6
var split_count: int = 16
var small_bounces: int = 0
var large_texture_path: String = "res://assets/projectiles/enemy/sleepy_joe/ice_cream_large_shot.png"
var split_texture_path: String = "res://assets/projectiles/enemy/sleepy_joe/ice_cream_big_shot.png"

var _cooldown_left: float = 4.0
var _windup_left: float = 0.0
var _between_shots_left: float = 0.0
var _recovery_left: float = 0.0
var _shots_left: int = 0


func update(delta: float) -> void:
	if owner_boss == null:
		return

	if _windup_left > 0.0:
		_windup_left = maxf(_windup_left - delta, 0.0)

		if _windup_left <= 0.0:
			_fire_barrage_shot()

		return

	if _between_shots_left > 0.0:
		_between_shots_left = maxf(_between_shots_left - delta, 0.0)

		if _between_shots_left <= 0.0:
			_fire_barrage_shot()

		return

	if _recovery_left > 0.0:
		_recovery_left = maxf(_recovery_left - delta, 0.0)

		if _recovery_left <= 0.0:
			_end_barrage()
			_cooldown_left = _get_current_cooldown()

		return

	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if _cooldown_left > 0.0:
		return

	if owner_boss.has_method("can_start_ice_cream_barrage") and not owner_boss.call("can_start_ice_cream_barrage"):
		_cooldown_left = 0.25
		return

	_start_barrage()


func cancel() -> void:
	if _windup_left <= 0.0 and _between_shots_left <= 0.0 and _recovery_left <= 0.0 and _shots_left <= 0:
		return

	_cooldown_left = _get_current_cooldown()
	_recovery_left = 0.0
	_end_barrage()


func _start_barrage() -> void:
	var player := owner_boss.get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		_cooldown_left = 0.5
		return

	_shots_left = shot_count

	if _is_owner_in_rage():
		_fire_barrage_shot()
		return

	if owner_boss.has_method("set_special_windup_active"):
		owner_boss.call("set_special_windup_active", true)

	show_debug_attack("Ice Cream Barrage")
	_windup_left = windup_duration


func _fire_barrage_shot() -> void:
	if _shots_left <= 0:
		if _is_owner_in_rage():
			_end_barrage()
			_cooldown_left = _get_current_cooldown()
		else:
			_recovery_left = recovery_duration
		return

	var player := owner_boss.get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		if _is_owner_in_rage():
			_end_barrage()
			_cooldown_left = _get_current_cooldown()
		else:
			_recovery_left = recovery_duration
		return

	var bullet := BulletScene.instantiate()

	if bullet == null:
		if _is_owner_in_rage():
			_end_barrage()
			_cooldown_left = _get_current_cooldown()
		else:
			_recovery_left = recovery_duration
		return

	var direction := _get_area_direction(player)
	var projectile_radius: float = bullet.radius
	var projectile_color: Color = bullet.color

	owner_boss.get_parent().add_child(bullet)
	bullet.global_position = owner_boss.global_position
	bullet.direction = direction
	bullet.setup_bullet(true)
	bullet.configure_projectile(
		1,
		_get_current_large_speed(),
		large_lifetime,
		projectile_radius,
		projectile_color,
		large_texture_path
	)
	bullet.configure_split_projectile(
		split_texture_path,
		split_count,
		small_speed,
		small_lifetime,
		small_bounces,
		true,
		true,
		SplitBulletScene
	)
	bullet.configure_curve(
		large_curve_strength_degrees,
		large_curve_frequency
	)

	_shots_left -= 1

	if _shots_left > 0:
		_between_shots_left = shot_interval
	else:
		if _is_owner_in_rage():
			_end_barrage()
			_cooldown_left = _get_current_cooldown()
		else:
			_recovery_left = recovery_duration


func _end_barrage() -> void:
	_shots_left = 0
	_windup_left = 0.0
	_between_shots_left = 0.0

	if owner_boss != null and owner_boss.has_method("set_special_windup_active"):
		owner_boss.call("set_special_windup_active", false)

	clear_debug_attack("Ice Cream Barrage")


func _is_owner_in_rage() -> bool:
	return owner_boss != null and owner_boss.has_method("is_rage_phase") and bool(owner_boss.call("is_rage_phase"))


func _get_current_cooldown() -> float:
	if _is_owner_in_rage():
		return rage_cooldown

	return cooldown


func _get_current_large_speed() -> float:
	if _is_owner_in_rage():
		return rage_huge_shot_speed

	return large_speed


func _get_area_direction(player: Node2D) -> Vector2:
	var player_velocity := Vector2.ZERO

	if player.has_method("get_camera_movement_velocity"):
		player_velocity = player.call("get_camera_movement_velocity")
	elif player is CharacterBody2D:
		player_velocity = (player as CharacterBody2D).velocity

	var target_offset := Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * sqrt(randf()) * aim_area_radius
	var target_position := player.global_position + player_velocity * prediction_time + target_offset
	var direction := target_position - owner_boss.global_position

	if direction.length_squared() <= 0.001:
		return Vector2.RIGHT

	return direction.normalized()
