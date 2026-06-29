extends BossAttack
class_name TestShootAttack


var cooldown: float = 0.25
var rage_cooldown: float = 0.2
var timer: float = 0.0
var bullet_texture_path: String = "res://assets/projectiles/enemy/sleepy_joe/ice_cream_big_shot.png"
var bullet_speed: float = 550.0
var bullet_lifetime: float = 1.5
var aim_area_radius: float = 150.0
var angle_spread_degrees: float = 13.0

var bullet_scene: PackedScene = preload("res://scenes/projectiles/enemy/sleepy_joe/ice_cream_basic_projectile.tscn")


func update(delta: float) -> void:

	timer -= delta

	if timer > 0.0:
		return

	timer = _get_current_cooldown()

	shoot()


func shoot() -> void:

	if owner_boss == null:
		return

	if owner_boss.has_method("can_use_basic_attack") and not owner_boss.call("can_use_basic_attack"):
		return

	var player := owner_boss.get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		return

	var selected_bullet_scene := _get_owner_basic_bullet_scene()
	var bullet = selected_bullet_scene.instantiate()
	var projectile_radius: float = bullet.radius
	var projectile_color: Color = bullet.color
	var selected_texture_path := _get_owner_basic_bullet_texture_path()

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
		bullet_speed,
		bullet_lifetime,
		projectile_radius,
		projectile_color,
		selected_texture_path
	)

	show_debug_attack("Basic Shot")

	if owner_boss.has_method("on_attack_shot"):
		owner_boss.call("on_attack_shot")


func _get_random_aim_offset() -> Vector2:
	var angle := randf_range(0.0, TAU)
	var distance := sqrt(randf()) * aim_area_radius

	return Vector2.RIGHT.rotated(angle) * distance


func _get_current_cooldown() -> float:
	if owner_boss != null and owner_boss.has_method("is_rage_phase") and bool(owner_boss.call("is_rage_phase")):
		return rage_cooldown

	return cooldown


func _get_owner_basic_bullet_scene() -> PackedScene:
	if owner_boss != null and owner_boss.has_method("get_basic_bullet_scene"):
		var owner_scene: PackedScene = owner_boss.call("get_basic_bullet_scene")

		if owner_scene != null:
			return owner_scene

	return bullet_scene


func _get_owner_basic_bullet_texture_path() -> String:
	if owner_boss != null and owner_boss.has_method("get_basic_bullet_texture_path"):
		return str(owner_boss.call("get_basic_bullet_texture_path", bullet_texture_path))

	return bullet_texture_path
