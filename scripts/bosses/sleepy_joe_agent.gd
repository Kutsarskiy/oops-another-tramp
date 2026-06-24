extends CharacterBody2D
class_name SleepyJoeAgent

signal health_changed(agent_name: String, current_hp: float, max_hp: float)
signal agent_died(agent_name: String)

const ENEMY_LAYER_BIT: int = 3
const PLAYER_BODY_LAYER_BIT: int = 1
const WALL_COLLISION_LAYER_BIT: int = 0
const PaperStateSpriteScript: Script = preload("res://scripts/visuals/paper_state_sprite.gd")
const BulletScene: PackedScene = preload("res://scenes/bullet.tscn")

@export var agent_name: String = "Agent A"
@export var max_hp: float = 70.0
@export var move_speed: float = 155.0
@export var preferred_boss_distance: float = 240.0
@export var boss_keepout_distance: float = 220.0
@export var guard_player_distance: float = 180.0
@export var agent_keepout_distance: float = 128.0
@export var flank_offset: float = 86.0
@export var max_guard_line_distance: float = 360.0
@export var center_hold_radius: float = 330.0
@export var center_steering_strength: float = 0.65
@export var fire_rate: float = 3.2
@export var reload_after_shots: int = 60
@export var reload_duration: float = 2.0
@export var bullet_speed: float = 500.0
@export var bullet_lifetime: float = 1.75
@export var bullet_radius: float = 6.0
@export var bullet_spread_degrees: float = 7.0
@export var muzzle_spacing: float = 22.0
@export var orbit_side: float = 1.0
@export var global_stun_damage_multiplier: float = 2.0
@export var global_stun_tint: Color = Color(1.0, 0.58, 0.58, 1.0)
@export var paper_state_texture_paths: Dictionary = {
	&"idle": "res://assets/characters/bosses/sleepy_joe/miniboss/secret_service_agent.png"
}

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D

var current_hp: float = 70.0
var owner_boss: BaseBoss = null
var _player: Node2D = null
var _shoot_cd: float = 0.0
var _shots_before_reload: int = 0
var _reload_left: float = 0.0
var _paper_visual = PaperStateSpriteScript.new()
var _global_stun_left: float = 0.0
var _base_stun_modulate: Color = Color.WHITE
var _boss_defeat_vanishing: bool = false


func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemy")
	add_to_group("miniboss")
	add_to_group("sleepy_joe_agent")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1 << ENEMY_LAYER_BIT
	collision_mask = (1 << WALL_COLLISION_LAYER_BIT) | (1 << PLAYER_BODY_LAYER_BIT) | (1 << ENEMY_LAYER_BIT)

	_configure_hurtbox()
	_paper_visual.setup(sprite, paper_state_texture_paths)
	if sprite != null:
		_base_stun_modulate = sprite.modulate
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_shoot_cd = randf_range(0.12, 0.34)
	_update_visual()
	health_changed.emit(agent_name, current_hp, max_hp)


func initialize(new_agent_name: String, boss: BaseBoss, hp_value: float, side: float) -> void:
	agent_name = new_agent_name
	owner_boss = boss
	max_hp = hp_value
	current_hp = max_hp
	orbit_side = side


func _physics_process(delta: float) -> void:
	if _boss_defeat_vanishing:
		_update_global_stun(delta)
		velocity = Vector2.ZERO
		move_and_slide()
		_paper_visual.set_state(&"idle")
		return

	if not _is_boss_alive():
		queue_free()
		return

	if _update_global_stun(delta):
		velocity = Vector2.ZERO
		move_and_slide()
		_paper_visual.set_state(&"idle")
		return

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D

	if _player == null or owner_boss == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var desired_velocity := _get_guard_velocity()

	if desired_velocity.length() > 0.001:
		velocity = desired_velocity.limit_length(move_speed)
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	var aim_direction := (_player.global_position - global_position).normalized()

	if aim_direction.length_squared() > 0.001:
		_paper_visual.face_direction(aim_direction)

	if _reload_left > 0.0:
		_reload_left = maxf(_reload_left - delta, 0.0)
		_paper_visual.set_state(&"idle")
		return

	_shoot_cd -= delta

	if _shoot_cd <= 0.0:
		_shoot_cd = 1.0 / maxf(fire_rate, 0.01)
		_shoot_dual(aim_direction)

	_paper_visual.set_state(&"idle")


func take_damage(amount: int) -> void:
	current_hp = maxf(current_hp - _get_global_stun_modified_damage(amount), 0.0)
	health_changed.emit(agent_name, current_hp, max_hp)

	if current_hp <= 0.0:
		agent_died.emit(agent_name)
		queue_free()


func _get_guard_position() -> Vector2:
	var boss_position := owner_boss.global_position
	var player_position := _player.global_position
	var boss_to_player := player_position - boss_position

	if boss_to_player.length_squared() <= 0.001:
		boss_to_player = Vector2.DOWN

	var guard_direction := boss_to_player.normalized()
	var tangent := guard_direction.orthogonal() * orbit_side
	var boss_player_distance := boss_to_player.length()
	var line_distance := clampf(
		boss_player_distance * 0.48,
		preferred_boss_distance,
		max_guard_line_distance
	)
	var desired_position := boss_position + guard_direction * line_distance + tangent * flank_offset

	if global_position.distance_to(player_position) < guard_player_distance:
		desired_position += _safe_direction(global_position - player_position, -guard_direction) * 80.0

	if desired_position.distance_to(boss_position) < preferred_boss_distance:
		desired_position = boss_position + _safe_direction(desired_position - boss_position, guard_direction) * preferred_boss_distance

	return _pull_position_toward_center(desired_position)


func _get_guard_velocity() -> Vector2:
	var target_position := _get_guard_position()
	var to_target := target_position - global_position
	var desired_velocity := Vector2.ZERO

	if to_target.length() > 14.0:
		desired_velocity = to_target.normalized() * move_speed

	desired_velocity += _get_avoidance_velocity()
	desired_velocity += _get_center_steering_velocity()
	return desired_velocity


func _get_avoidance_velocity() -> Vector2:
	var avoidance := Vector2.ZERO

	if owner_boss != null and is_instance_valid(owner_boss):
		avoidance += _avoid_position(owner_boss.global_position, boss_keepout_distance, 1.55)

	if _player != null and is_instance_valid(_player):
		avoidance += _avoid_position(_player.global_position, guard_player_distance, 0.85)

	for agent in get_tree().get_nodes_in_group("sleepy_joe_agent"):
		if agent == self or not agent is Node2D:
			continue

		avoidance += _avoid_position((agent as Node2D).global_position, agent_keepout_distance, 1.1)

	return avoidance


func _avoid_position(target_position: Vector2, keepout_distance: float, weight: float) -> Vector2:
	var away := global_position - target_position
	var distance := away.length()

	if distance <= 0.001 or distance >= keepout_distance:
		return Vector2.ZERO

	var strength := 1.0 - distance / keepout_distance
	return away.normalized() * move_speed * strength * weight


func _pull_position_toward_center(target_position: Vector2) -> Vector2:
	var arena_center := _get_current_arena_center()
	var from_center := target_position - arena_center
	var distance_from_center := from_center.length()

	if distance_from_center <= center_hold_radius or distance_from_center <= 0.001:
		return target_position

	return arena_center + from_center.normalized() * center_hold_radius


func _get_center_steering_velocity() -> Vector2:
	var arena_center := _get_current_arena_center()
	var to_center := arena_center - global_position
	var distance_from_center := to_center.length()

	if distance_from_center <= center_hold_radius or distance_from_center <= 0.001:
		return Vector2.ZERO

	return to_center.normalized() * move_speed * center_steering_strength


func _get_current_arena_center() -> Vector2:
	var game_root := get_tree().current_scene

	if game_root == null:
		return Vector2.ZERO

	var arena_container := game_root.get_node_or_null("ArenaContainer")

	if arena_container == null:
		return Vector2.ZERO

	for child in arena_container.get_children():
		if child is Node2D and child.get("arena_size") is Vector2:
			return (child as Node2D).global_position

	return Vector2.ZERO


func _safe_direction(direction: Vector2, fallback: Vector2) -> Vector2:
	if direction.length_squared() > 0.001:
		return direction.normalized()

	if fallback.length_squared() > 0.001:
		return fallback.normalized()

	return Vector2.RIGHT


func _shoot_dual(direction: Vector2) -> void:
	if direction.length_squared() <= 0.001:
		return

	if _reload_left > 0.0:
		return

	var tangent := direction.orthogonal()
	var half_spread := deg_to_rad(bullet_spread_degrees) * 0.5

	for offset_sign in [-1.0, 1.0]:
		var bullet := BulletScene.instantiate()

		if bullet == null:
			continue

		get_parent().add_child(bullet)
		bullet.global_position = global_position + tangent * muzzle_spacing * offset_sign
		bullet.direction = direction.rotated(randf_range(-half_spread, half_spread))
		bullet.setup_bullet(true)
		bullet.configure_projectile(1, bullet_speed, bullet_lifetime, bullet_radius, Color(1.0, 0.52, 0.16))
		_shots_before_reload += 1

	if _shots_before_reload >= reload_after_shots:
		_shots_before_reload = 0
		_reload_left = reload_duration


func _update_visual() -> void:
	_paper_visual.set_state(&"idle")


func _is_boss_alive() -> bool:
	return owner_boss != null and is_instance_valid(owner_boss) and not owner_boss.defeated


func _configure_hurtbox() -> void:
	if hurtbox == null:
		return

	hurtbox.add_to_group("enemy")
	hurtbox.add_to_group("enemy_hurtbox")
	hurtbox.set_meta("damage_owner", self)
	hurtbox.set_deferred("monitoring", true)
	hurtbox.set_deferred("monitorable", true)
	hurtbox.collision_layer = 1 << ENEMY_LAYER_BIT
	hurtbox.collision_mask = 0


func apply_global_stun(duration: float) -> void:
	_global_stun_left = maxf(_global_stun_left, duration)
	_set_global_stun_visual(true)


func begin_boss_defeat_vanish() -> void:
	_boss_defeat_vanishing = true


func _update_global_stun(delta: float) -> bool:
	if _global_stun_left <= 0.0:
		return false

	_global_stun_left = maxf(_global_stun_left - delta, 0.0)

	if _global_stun_left <= 0.0:
		_set_global_stun_visual(false)

	return true


func _get_global_stun_modified_damage(amount: int) -> float:
	var final_amount := float(amount)

	if _global_stun_left > 0.0:
		final_amount *= global_stun_damage_multiplier

	return final_amount


func _set_global_stun_visual(is_enabled: bool) -> void:
	if sprite == null:
		return

	if is_enabled:
		sprite.modulate = _base_stun_modulate * global_stun_tint
	else:
		sprite.modulate = _base_stun_modulate
