extends BossAttack
class_name IceCreamStormAttack


const BulletScene: PackedScene = preload("res://scenes/projectiles/enemy/sleepy_joe/ice_cream_basic_projectile.tscn")

var cooldown: float = 20.0
var windup_duration: float = 1.0
var duration: float = 10.0
var recovery_duration: float = 1.0
var volley_interval: float = 0.25
var bullets_per_volley: int = 12
var bullet_speed: float = 450.0
var bullet_lifetime: float = 0.0
var bullet_radius: float = 16.0
var bullet_texture_path: String = "res://assets/projectiles/enemy/sleepy_joe/ice_cream_big_shot.png"
var angular_step_offset: float = 0.2
var wave_angle_jitter_degrees: float = 3.5

var _cooldown_left: float = 7.0
var _windup_left: float = 0.0
var _storm_left: float = 0.0
var _recovery_left: float = 0.0
var _volley_left: float = 0.0
var _wave_index: int = 0


func update(delta: float) -> void:
	if owner_boss == null:
		return

	if _windup_left > 0.0:
		_windup_left = maxf(_windup_left - delta, 0.0)

		if _windup_left <= 0.0:
			_begin_storm()

		return

	if _storm_left > 0.0:
		_storm_left = maxf(_storm_left - delta, 0.0)
		_volley_left = maxf(_volley_left - delta, 0.0)

		if owner_boss.has_method("set_agents_attack_paused"):
			owner_boss.call("set_agents_attack_paused", maxf(_storm_left, 0.2))

		if _volley_left <= 0.0:
			_fire_volley()
			_volley_left = volley_interval

		if _storm_left <= 0.0:
			_recovery_left = recovery_duration

		return

	if _recovery_left > 0.0:
		_recovery_left = maxf(_recovery_left - delta, 0.0)

		if _recovery_left <= 0.0:
			_end_storm()
			_cooldown_left = cooldown

		return

	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if _cooldown_left > 0.0:
		return

	if owner_boss.has_method("can_start_ice_cream_storm") and not owner_boss.call("can_start_ice_cream_storm"):
		_cooldown_left = 0.25
		return

	_start_storm()


func cancel() -> void:
	if _windup_left <= 0.0 and _storm_left <= 0.0 and _recovery_left <= 0.0:
		return

	_cooldown_left = cooldown
	_end_storm()


func _start_storm() -> void:
	_windup_left = windup_duration
	show_debug_attack("Ice Cream Storm")

	if owner_boss.has_method("set_special_windup_active"):
		owner_boss.call("set_special_windup_active", true)

	if owner_boss.has_method("set_agents_attack_paused"):
		owner_boss.call("set_agents_attack_paused", windup_duration + duration + recovery_duration)


func _begin_storm() -> void:
	_storm_left = duration
	_volley_left = 0.0
	_wave_index = 0


func _end_storm() -> void:
	_windup_left = 0.0
	_storm_left = 0.0
	_recovery_left = 0.0
	_volley_left = 0.0

	if owner_boss != null and owner_boss.has_method("set_special_windup_active"):
		owner_boss.call("set_special_windup_active", false)

	if owner_boss != null and owner_boss.has_method("set_agents_attack_paused"):
		owner_boss.call("set_agents_attack_paused", 0.0)

	clear_debug_attack("Ice Cream Storm")


func _fire_volley() -> void:
	var parent_node := owner_boss.get_parent()

	if parent_node == null:
		return

	var base_angle := float(_wave_index) * angular_step_offset
	var angle_step := TAU / float(maxi(bullets_per_volley, 1))

	for i in range(bullets_per_volley):
		var bullet := BulletScene.instantiate()

		if bullet == null:
			continue

		var angle_jitter := deg_to_rad(randf_range(-wave_angle_jitter_degrees, wave_angle_jitter_degrees))
		var shot_direction := Vector2.RIGHT.rotated(base_angle + angle_step * float(i) + angle_jitter)
		parent_node.add_child(bullet)
		bullet.global_position = owner_boss.global_position
		bullet.direction = shot_direction
		bullet.setup_bullet(true)
		bullet.configure_projectile(
			1,
			bullet_speed,
			bullet_lifetime,
			bullet_radius,
			Color(1.0, 0.52, 0.16),
			bullet_texture_path
		)

	_wave_index += 1
