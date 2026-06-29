extends BossAttack
class_name IceCreamBombAttack


const BulletScene: PackedScene = preload("res://scenes/projectiles/enemy/sleepy_joe/ice_cream_large_projectile.tscn")
const SplitBulletScene: PackedScene = preload("res://scenes/projectiles/enemy/sleepy_joe/ice_cream_split_projectile.tscn")

var cooldown: float = 5.0
var windup_duration: float = 1.0
var recovery_duration: float = 1.0
var large_speed: float = 450.0
var large_lifetime: float = 2.2
var large_curve_strength_degrees: float = 30.0
var large_curve_frequency: float = 0.55
var small_speed: float = 350.0
var small_lifetime: float = 2.6
var split_count: int = 16
var small_bounces: int = 0
var prediction_time: float = 0.65
var prediction_error_radius: float = 90.0
var large_texture_path: String = "res://assets/projectiles/enemy/sleepy_joe/ice_cream_large_shot.png"
var split_texture_path: String = "res://assets/projectiles/enemy/sleepy_joe/ice_cream_big_shot.png"

var _cooldown_left: float = 2.4
var _windup_left: float = 0.0
var _recovery_left: float = 0.0
var _pending_direction: Vector2 = Vector2.RIGHT


func update(delta: float) -> void:
	if owner_boss == null:
		return

	if _windup_left > 0.0:
		_windup_left = maxf(_windup_left - delta, 0.0)

		if _windup_left <= 0.0:
			_fire_bomb()
			_recovery_left = recovery_duration

		return

	if _recovery_left > 0.0:
		_recovery_left = maxf(_recovery_left - delta, 0.0)

		if _recovery_left <= 0.0:
			_end_windup()
			_cooldown_left = cooldown

		return

	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if _cooldown_left > 0.0:
		return

	if owner_boss.has_method("can_start_special_attack") and not owner_boss.call("can_start_special_attack"):
		_cooldown_left = 0.25
		return

	_start_windup()


func cancel() -> void:
	_windup_left = 0.0
	_recovery_left = 0.0
	_cooldown_left = cooldown
	_end_windup()


func _start_windup() -> void:
	var player := owner_boss.get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		_cooldown_left = 0.5
		return

	_pending_direction = _get_predicted_direction(player)

	if _pending_direction.length_squared() <= 0.001:
		_pending_direction = Vector2.RIGHT

	if owner_boss.has_method("set_special_windup_active"):
		owner_boss.call("set_special_windup_active", true)

	show_debug_attack("Ice Cream Bomb")
	_windup_left = windup_duration


func _fire_bomb() -> void:
	var player := owner_boss.get_tree().get_first_node_in_group("player") as Node2D

	if player != null:
		_pending_direction = _get_predicted_direction(player)

	var bullet := BulletScene.instantiate()

	if bullet == null:
		return

	var projectile_radius: float = bullet.radius
	var projectile_color: Color = bullet.color
	owner_boss.get_parent().add_child(bullet)
	bullet.global_position = owner_boss.global_position
	bullet.direction = _pending_direction
	bullet.setup_bullet(true)
	bullet.configure_projectile(
		1,
		large_speed,
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


func _end_windup() -> void:
	if owner_boss != null and owner_boss.has_method("set_special_windup_active"):
		owner_boss.call("set_special_windup_active", false)

	clear_debug_attack("Ice Cream Bomb")


func _get_predicted_direction(player: Node2D) -> Vector2:
	var player_velocity := Vector2.ZERO

	if player.has_method("get_camera_movement_velocity"):
		player_velocity = player.call("get_camera_movement_velocity")
	elif player is CharacterBody2D:
		player_velocity = (player as CharacterBody2D).velocity

	var prediction_error := Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * sqrt(randf()) * prediction_error_radius
	var predicted_position := player.global_position + player_velocity * prediction_time + prediction_error
	var direction := predicted_position - owner_boss.global_position

	if direction.length_squared() <= 0.001:
		return Vector2.RIGHT

	return direction.normalized()
