extends BossAttack
class_name TestShootAttack


var cooldown: float = 0.25
var timer: float = 0.0
var bullet_texture_path: String = "res://assets/projectiles/enemy/sleepy_joe/ice_cream_big_shot.png"
var aim_area_radius: float = 150.0
var angle_spread_degrees: float = 13.0

var bullet_scene := preload("res://scenes/bullet.tscn")


func update(delta: float) -> void:

	timer -= delta

	if timer > 0.0:
		return

	timer = cooldown

	shoot()


func shoot() -> void:

	if owner_boss == null:
		return

	if owner_boss.has_method("can_use_basic_attack") and not owner_boss.call("can_use_basic_attack"):
		return

	var player := owner_boss.get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		return

	var bullet = bullet_scene.instantiate()

	owner_boss.get_parent().add_child(bullet)

	bullet.global_position = owner_boss.global_position

	var spread_multiplier := 1.0

	if owner_boss.has_method("get_basic_attack_spread_multiplier"):
		spread_multiplier = float(owner_boss.call("get_basic_attack_spread_multiplier"))

	var target_position: Vector2 = player.global_position + _get_random_aim_offset() * spread_multiplier
	var direction: Vector2 = (target_position - owner_boss.global_position).normalized()

	if owner_boss.has_method("get_basic_attack_direction"):
		direction = owner_boss.call("get_basic_attack_direction", player, direction)

	var angle_spread := angle_spread_degrees * spread_multiplier
	direction = direction.rotated(deg_to_rad(randf_range(-angle_spread, angle_spread)))

	bullet.direction = direction

	bullet.setup_bullet(true)
	bullet.configure_projectile(
		bullet.damage,
		bullet.speed,
		bullet.lifetime,
		bullet.radius,
		bullet.color,
		bullet_texture_path
	)

	if owner_boss.has_method("on_attack_shot"):
		owner_boss.call("on_attack_shot")


func _get_random_aim_offset() -> Vector2:
	var angle := randf_range(0.0, TAU)
	var distance := sqrt(randf()) * aim_area_radius

	return Vector2.RIGHT.rotated(angle) * distance
