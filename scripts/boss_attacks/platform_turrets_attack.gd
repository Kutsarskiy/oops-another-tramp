extends BossAttack
class_name PlatformTurretsAttack


var shot_interval: float = 0.25
var bullet_speed: float = 500.0
var bullet_lifetime: float = 1.8
var bullet_radius: float = 16.0
var aim_area_radius: float = 250.0
var angle_spread_degrees: float = 30.0
var turret_offsets: Array[Vector2] = [
	Vector2(-112.0, 6.0),
	Vector2(112.0, 6.0)
]

var _shot_left: float = 0.12
var _next_turret_index: int = 0


func update(delta: float) -> void:
	if owner_boss == null:
		return

	if owner_boss.has_method("can_use_platform_turrets") and not owner_boss.call("can_use_platform_turrets"):
		clear_debug_attack("Platform Turrets")
		return

	_shot_left = maxf(_shot_left - delta, 0.0)

	if _shot_left > 0.0:
		return

	show_debug_attack("Platform Turrets")
	_fire_turret_pair()
	_shot_left = shot_interval


func cancel() -> void:
	_shot_left = 0.0
	clear_debug_attack("Platform Turrets")


func _fire_turret_pair() -> void:
	var player := owner_boss.get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		return

	for i in range(turret_offsets.size()):
		var turret_index := (_next_turret_index + i) % turret_offsets.size()
		_fire_from_turret(player, turret_offsets[turret_index])

	_next_turret_index = (_next_turret_index + 1) % maxi(turret_offsets.size(), 1)


func _fire_from_turret(player: Node2D, local_offset: Vector2) -> void:
	var bullet_scene := _get_owner_basic_bullet_scene()
	var bullet = bullet_scene.instantiate()

	if bullet == null:
		return

	var spawn_position := owner_boss.global_position + local_offset
	var target_position := player.global_position + _get_random_aim_offset()
	var direction := target_position - spawn_position

	if direction.length_squared() <= 0.001:
		direction = Vector2.DOWN

	direction = direction.normalized().rotated(deg_to_rad(randf_range(-angle_spread_degrees, angle_spread_degrees)))

	var projectile_radius: float = bullet.radius
	var projectile_color: Color = bullet.color
	var texture_path := _get_owner_basic_bullet_texture_path()

	owner_boss.get_parent().add_child(bullet)
	bullet.global_position = spawn_position
	bullet.direction = direction
	bullet.setup_bullet(true)
	bullet.configure_projectile(
		bullet.damage,
		bullet_speed,
		bullet_lifetime,
		bullet_radius if bullet_radius > 0.0 else projectile_radius,
		projectile_color,
		texture_path
	)

	if owner_boss.has_method("on_attack_shot"):
		owner_boss.call("on_attack_shot")


func _get_random_aim_offset() -> Vector2:
	var angle := randf_range(0.0, TAU)
	var distance := sqrt(randf()) * aim_area_radius

	return Vector2.RIGHT.rotated(angle) * distance


func _get_owner_basic_bullet_scene() -> PackedScene:
	if owner_boss != null and owner_boss.has_method("get_basic_bullet_scene"):
		var owner_scene: PackedScene = owner_boss.call("get_basic_bullet_scene")

		if owner_scene != null:
			return owner_scene

	return preload("res://scenes/projectiles/enemy/techno_king/techno_king_basic_projectile.tscn")


func _get_owner_basic_bullet_texture_path() -> String:
	if owner_boss != null and owner_boss.has_method("get_basic_bullet_texture_path"):
		return str(owner_boss.call("get_basic_bullet_texture_path", ""))

	return ""
