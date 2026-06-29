extends BossAttack
class_name CybertruckTestAttack


const LandingWarningMarkerScript: Script = preload("res://scripts/effects/landing_warning_marker.gd")
const MetalSphereProjectileScript: Script = preload("res://scripts/projectiles/enemy/techno_king_metal_sphere_projectile.gd")

var windup_duration: float = 1.0
var projectile_speed: float = 750.0
var impact_radius: float = 115.0
var damage: int = 1
var spawn_offset: Vector2 = Vector2(0.0, -18.0)

var _windup_left: float = 0.0
var _is_winding_up: bool = false
var _warning_marker: Node = null


func update(delta: float) -> void:
	if owner_boss == null:
		return

	if _windup_left > 0.0:
		_windup_left = maxf(_windup_left - delta, 0.0)
		show_debug_attack("Cybertruck Test")

		if _windup_left <= 0.0:
			_fire_metal_sphere()
			_finish_windup()

		return


func cancel() -> void:
	_windup_left = 0.0
	_clear_warning_marker()
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
	show_debug_attack("Cybertruck Test")
	_create_windup_warning_marker(player)

	if owner_boss.has_method("set_techno_king_visual_override"):
		owner_boss.call("set_techno_king_visual_override", &"phase_1_metal_sphere")

	return true


func _finish_windup() -> void:
	if _is_winding_up and owner_boss != null and owner_boss.has_method("clear_techno_king_visual_override"):
		owner_boss.call("clear_techno_king_visual_override", &"phase_1_metal_sphere")

	_is_winding_up = false
	clear_debug_attack("Cybertruck Test")


func _fire_metal_sphere() -> void:
	var parent_node := owner_boss.get_parent()

	if parent_node == null:
		return

	var player := owner_boss.get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		return

	var start_position := owner_boss.global_position + spawn_offset
	var target_position := player.global_position
	var marker = _warning_marker

	if marker == null or not is_instance_valid(marker):
		marker = LandingWarningMarkerScript.new()
		marker.warning_radius = impact_radius
		parent_node.add_child(marker)

	if marker.has_method("lock_to_position"):
		marker.call("lock_to_position", target_position)
	else:
		marker.global_position = target_position

	_warning_marker = null

	var sphere = MetalSphereProjectileScript.new()
	sphere.configure(
		start_position,
		target_position,
		projectile_speed,
		damage,
		impact_radius,
		marker
	)
	parent_node.add_child(sphere)


func _create_windup_warning_marker(player: Node2D) -> void:
	_clear_warning_marker()

	var parent_node := owner_boss.get_parent()

	if parent_node == null:
		return

	var marker = LandingWarningMarkerScript.new()
	marker.warning_radius = impact_radius
	marker.follow_target = player
	marker.blink_enabled = true
	parent_node.add_child(marker)
	marker.global_position = player.global_position
	_warning_marker = marker


func _clear_warning_marker() -> void:
	if _warning_marker != null and is_instance_valid(_warning_marker):
		_warning_marker.queue_free()

	_warning_marker = null
