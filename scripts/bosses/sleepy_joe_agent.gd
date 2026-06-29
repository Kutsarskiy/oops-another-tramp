extends CharacterBody2D
class_name SleepyJoeAgent

signal health_changed(agent_name: String, current_hp: float, max_hp: float)
signal agent_died(agent_name: String)

const ENEMY_LAYER_BIT: int = 3
const PLAYER_BODY_LAYER_BIT: int = 1
const WALL_COLLISION_LAYER_BIT: int = 0
const PaperStateSpriteScript: Script = preload("res://scripts/visuals/paper_state_sprite.gd")
const BulletScene: PackedScene = preload("res://scenes/projectiles/enemy/sleepy_joe/agent_red_projectile.tscn")

@export var agent_name: String = "Agent A"
@export var max_hp: float = 70.0
@export var move_speed: float = 155.0
@export var preferred_boss_distance: float = 240.0
@export var boss_keepout_distance: float = 46.0
@export var guard_player_distance: float = 180.0
@export var agent_keepout_distance: float = 48.0
@export var flank_offset: float = 48.0
@export var body_block_line_ratio: float = 0.38
@export var max_guard_line_distance: float = 320.0
@export var bodyguard_boss_distance: float = 92.0
@export var bodyguard_close_distance: float = 48.0
@export var bodyguard_far_distance: float = 112.0
@export var bodyguard_near_player_distance: float = 230.0
@export var bodyguard_far_player_distance: float = 620.0
@export var bodyguard_side_offset: float = 38.0
@export var bodyguard_player_pull: float = 0.0
@export var bodyguard_follow_delay: float = 0.28
@export var bodyguard_push_distance: float = 72.0
@export var bodyguard_push_max_per_frame: float = 0.35
@export var mirror_collision_with_visual: bool = true
@export var center_hold_radius: float = 330.0
@export var center_steering_strength: float = 0.65
@export var fire_rate: float = 3.0
@export var reload_after_shots: int = 60
@export var reload_duration: float = 2.0
@export var bullet_speed: float = 420.0
@export var bullet_lifetime: float = 1.65
@export var bullet_radius: float = 16.0
@export var bullet_color: Color = Color(1.0, 0.16, 0.12, 1.0)
@export var bullet_texture_path: String = "res://assets/projectiles/enemy/sleepy_joe/agent_red_shot.svg"
@export var suppression_area_radius: float = 130.0
@export var suppression_prediction_time: float = 0.12
@export var suppression_prediction_max_time: float = 0.62
@export var suppression_prediction_error_radius: float = 92.0
@export var suppression_angle_jitter_degrees: float = 7.5
@export var suppression_lane_angle_step: float = 2.35
@export var suppression_lane_distance_min: float = 0.25
@export var suppression_lane_distance_max: float = 0.95
@export var attack_delay_after_spawn_intro: float = 1.0
@export var burst_min_shots: int = 5
@export var burst_max_shots: int = 7
@export var burst_pause_min: float = 0.65
@export var burst_pause_max: float = 0.9
@export var burst_start_desync_max: float = 0.35
@export var orbit_side: float = 1.0
@export var global_stun_damage_multiplier: float = 2.0
@export var global_stun_tint: Color = Color(1.0, 0.58, 0.58, 1.0)
@export var spawn_intro_duration: float = 0.55
@export var spawn_intro_fall_height: float = 210.0
@export var spawn_intro_start_rotation_degrees: float = -12.0
@export var spawn_intro_shadow_offset: Vector2 = Vector2(0.0, 48.0)
@export var spawn_intro_shadow_color: Color = Color(0.0, 0.0, 0.0, 0.28)
@export var paper_state_texture_paths: Dictionary = {
	&"idle": "res://assets/characters/bosses/sleepy_joe/miniboss/secret_service_agent.png"
}

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
@onready var hurtbox_collision_shape: CollisionShape2D = get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D

var current_hp: float = 70.0
var owner_boss: BaseBoss = null
var _player: Node2D = null
var _shoot_cd: float = 0.0
var _shots_before_reload: int = 0
var _reload_left: float = 0.0
var _attack_pause_left: float = 0.0
var _burst_pause_left: float = 0.0
var _burst_shots_left: int = 0
var _paper_visual = PaperStateSpriteScript.new()
var _global_stun_left: float = 0.0
var _base_stun_modulate: Color = Color.WHITE
var _boss_defeat_vanishing: bool = false
var _spawn_intro_active: bool = false
var _spawn_intro_shadow: Sprite2D = null
var _suppression_shot_index: int = 0
var _base_collision_layer: int = 0
var _base_collision_mask: int = 0
var _base_hurtbox_monitoring: bool = false
var _base_hurtbox_monitorable: bool = false
var _base_collision_shape_position: Vector2 = Vector2.ZERO
var _base_hurtbox_collision_shape_position: Vector2 = Vector2.ZERO
var _delayed_guard_position: Vector2 = Vector2.ZERO
var _has_delayed_guard_position: bool = false


func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemy")
	add_to_group("miniboss")
	add_to_group("sleepy_joe_agent")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1 << ENEMY_LAYER_BIT
	collision_mask = (1 << WALL_COLLISION_LAYER_BIT) | (1 << PLAYER_BODY_LAYER_BIT) | (1 << ENEMY_LAYER_BIT)
	_base_collision_layer = collision_layer
	_base_collision_mask = collision_mask

	_configure_hurtbox()
	if collision_shape != null:
		_base_collision_shape_position = collision_shape.position
	if hurtbox_collision_shape != null:
		_base_hurtbox_collision_shape_position = hurtbox_collision_shape.position
	_paper_visual.setup(sprite, paper_state_texture_paths)
	if sprite != null:
		_base_stun_modulate = sprite.modulate
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_shoot_cd = randf_range(0.12, 0.34) + randf_range(0.0, burst_start_desync_max)
	_start_new_burst()
	_update_visual()
	health_changed.emit(agent_name, current_hp, max_hp)


func initialize(new_agent_name: String, boss: BaseBoss, hp_value: float, side: float) -> void:
	agent_name = new_agent_name
	owner_boss = boss
	max_hp = hp_value
	current_hp = max_hp
	orbit_side = side
	_delayed_guard_position = global_position
	_has_delayed_guard_position = false


func _physics_process(delta: float) -> void:
	if _spawn_intro_active:
		velocity = Vector2.ZERO
		_move_and_slide_with_bed_bounds()
		_paper_visual.set_state(&"idle")
		return

	if _boss_defeat_vanishing:
		_update_global_stun(delta)
		velocity = Vector2.ZERO
		_move_and_slide_with_bed_bounds()
		_paper_visual.set_state(&"idle")
		return

	if not _is_boss_alive():
		queue_free()
		return

	if _update_global_stun(delta):
		velocity = Vector2.ZERO
		_move_and_slide_with_bed_bounds()
		_paper_visual.set_state(&"idle")
		return

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D

	if _player == null or owner_boss == null:
		velocity = Vector2.ZERO
		_move_and_slide_with_bed_bounds()
		return

	var desired_velocity := _get_guard_velocity(delta)

	if desired_velocity.length() > 0.001:
		velocity = desired_velocity.limit_length(move_speed)
	else:
		velocity = Vector2.ZERO

	_move_and_slide_with_bed_bounds()
	_apply_bodyguard_pressure()

	var aim_direction := (_player.global_position - global_position).normalized()

	if aim_direction.length_squared() > 0.001:
		_paper_visual.face_direction(aim_direction)
		_sync_collision_mirroring()

	if _attack_pause_left > 0.0:
		_attack_pause_left = maxf(_attack_pause_left - delta, 0.0)
		_paper_visual.set_state(&"idle")
		return

	if _reload_left > 0.0:
		_reload_left = maxf(_reload_left - delta, 0.0)
		_paper_visual.set_state(&"idle")
		return

	if _burst_pause_left > 0.0:
		_burst_pause_left = maxf(_burst_pause_left - delta, 0.0)

		if _burst_pause_left <= 0.0:
			_start_new_burst()

		_paper_visual.set_state(&"idle")
		return

	_shoot_cd -= delta

	if _shoot_cd <= 0.0:
		_shoot_cd = 1.0 / maxf(fire_rate, 0.01)
		_shoot_suppression_volley(aim_direction)
		_burst_shots_left -= 1

		if _burst_shots_left <= 0:
			_burst_pause_left = randf_range(burst_pause_min, burst_pause_max)

	_paper_visual.set_state(&"idle")


func take_damage(amount: int) -> void:
	if _spawn_intro_active:
		return

	current_hp = maxf(current_hp - _get_global_stun_modified_damage(amount), 0.0)
	health_changed.emit(agent_name, current_hp, max_hp)

	if current_hp <= 0.0:
		agent_died.emit(agent_name)
		queue_free()


func debug_kill() -> void:
	if current_hp <= 0.0:
		return

	current_hp = 0.0
	health_changed.emit(agent_name, current_hp, max_hp)
	agent_died.emit(agent_name)
	queue_free()


func _get_guard_position() -> Vector2:
	var boss_position := owner_boss.global_position
	var boss_to_player := _player.global_position - boss_position

	if boss_to_player.length_squared() <= 0.001:
		boss_to_player = Vector2.DOWN

	var guard_direction := boss_to_player.normalized()
	var tangent := guard_direction.orthogonal() * orbit_side
	var alive_agent_count := _get_alive_agent_count()
	var side_offset := 0.0 if alive_agent_count <= 1 else bodyguard_side_offset
	var cover_distance := _get_bodyguard_cover_distance(boss_position)
	var desired_position := boss_position + guard_direction * cover_distance + tangent * side_offset

	if global_position.distance_to(_player.global_position) < guard_player_distance:
		desired_position += _safe_direction(global_position - _player.global_position, -guard_direction) * 48.0

	return _clamp_point_to_bed_bounds(_pull_position_toward_center(desired_position))


func _get_guard_velocity(delta: float) -> Vector2:
	var target_position := _get_delayed_guard_position(delta)
	var to_target := target_position - global_position
	var desired_velocity := Vector2.ZERO

	if to_target.length() > 14.0:
		desired_velocity = to_target.normalized() * move_speed

	desired_velocity += _get_avoidance_velocity()
	desired_velocity += _get_center_steering_velocity()
	return desired_velocity


func _get_delayed_guard_position(delta: float) -> Vector2:
	var instant_target := _get_guard_position()

	if not _has_delayed_guard_position:
		_delayed_guard_position = instant_target
		_has_delayed_guard_position = true
		return _delayed_guard_position

	var delay := maxf(bodyguard_follow_delay, 0.001)
	var follow_t := 1.0 - exp(-delta / delay)
	_delayed_guard_position = _delayed_guard_position.lerp(instant_target, follow_t)
	return _clamp_point_to_bed_bounds(_delayed_guard_position)


func _get_bodyguard_cover_distance(boss_position: Vector2) -> float:
	if _player == null:
		return bodyguard_boss_distance

	var player_distance := boss_position.distance_to(_player.global_position)
	var distance_t := inverse_lerp(bodyguard_near_player_distance, bodyguard_far_player_distance, player_distance)
	distance_t = clampf(distance_t, 0.0, 1.0)
	return lerpf(bodyguard_close_distance, bodyguard_far_distance, distance_t)


func _get_alive_agent_count() -> int:
	var count := 0

	for agent in get_tree().get_nodes_in_group("sleepy_joe_agent"):
		if agent == null or not is_instance_valid(agent):
			continue

		if agent.get("current_hp") is float and float(agent.get("current_hp")) <= 0.0:
			continue

		count += 1

	return count


func _apply_bodyguard_pressure() -> void:
	if owner_boss == null or not owner_boss.has_method("apply_bodyguard_pressure"):
		return

	owner_boss.call("apply_bodyguard_pressure", global_position, bodyguard_push_distance, bodyguard_push_max_per_frame)


func _move_and_slide_with_bed_bounds() -> void:
	move_and_slide()

	if owner_boss == null or not owner_boss.has_method("get_bed_movement_rect"):
		return

	global_position = _clamp_point_to_bed_bounds(global_position)


func _clamp_point_to_bed_bounds(point: Vector2) -> Vector2:
	if owner_boss == null or not owner_boss.has_method("get_bed_movement_rect"):
		return point

	var bed_rect: Rect2 = owner_boss.call("get_bed_movement_rect")
	return Vector2(
		clampf(point.x, bed_rect.position.x, bed_rect.end.x),
		clampf(point.y, bed_rect.position.y, bed_rect.end.y)
	)


func _get_avoidance_velocity() -> Vector2:
	var avoidance := Vector2.ZERO

	if owner_boss != null and is_instance_valid(owner_boss):
		avoidance += _avoid_position(owner_boss.global_position, boss_keepout_distance, 0.45)

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
	if owner_boss != null and owner_boss.has_method("get_bed_movement_rect"):
		var bed_rect: Rect2 = owner_boss.call("get_bed_movement_rect")
		return bed_rect.get_center()

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


func _sync_collision_mirroring() -> void:
	var mirror_sign := -1.0 if mirror_collision_with_visual and sprite != null and sprite.flip_h else 1.0

	if collision_shape != null:
		collision_shape.position = Vector2(_base_collision_shape_position.x * mirror_sign, _base_collision_shape_position.y)

	if hurtbox_collision_shape != null:
		hurtbox_collision_shape.position = Vector2(
			_base_hurtbox_collision_shape_position.x * mirror_sign,
			_base_hurtbox_collision_shape_position.y
		)


func _shoot_suppression_volley(direction: Vector2) -> void:
	if direction.length_squared() <= 0.001:
		return

	if _reload_left > 0.0:
		return

	var predicted_player_position := _get_predicted_player_position()
	var bullet := BulletScene.instantiate()

	if bullet == null:
		return

	var target_position := predicted_player_position + _get_suppression_offset()
	var shot_direction := _safe_direction(target_position - global_position, direction)
	shot_direction = shot_direction.rotated(deg_to_rad(randf_range(-suppression_angle_jitter_degrees, suppression_angle_jitter_degrees)))

	get_parent().add_child(bullet)
	bullet.global_position = global_position
	bullet.direction = shot_direction
	bullet.setup_bullet(true)
	bullet.configure_projectile(1, bullet_speed, bullet_lifetime, bullet_radius, bullet_color, bullet_texture_path)
	_shots_before_reload += 1
	_suppression_shot_index += 1

	if _shots_before_reload >= reload_after_shots:
		_shots_before_reload = 0
		_reload_left = reload_duration


func _start_new_burst() -> void:
	_burst_shots_left = randi_range(mini(burst_min_shots, burst_max_shots), maxi(burst_min_shots, burst_max_shots))


func _get_predicted_player_position() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return global_position

	var player_velocity := Vector2.ZERO

	if _player.has_method("get_camera_movement_velocity"):
		player_velocity = _player.call("get_camera_movement_velocity")
	elif _player is CharacterBody2D:
		player_velocity = (_player as CharacterBody2D).velocity

	var distance_to_player := global_position.distance_to(_player.global_position)
	var travel_time := distance_to_player / maxf(bullet_speed, 1.0)
	var lead_time := clampf(travel_time + suppression_prediction_time, 0.0, suppression_prediction_max_time)
	var prediction_error := Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * sqrt(randf()) * suppression_prediction_error_radius
	return _player.global_position + player_velocity * lead_time + prediction_error


func _get_suppression_offset() -> Vector2:
	var angle := float(_suppression_shot_index) * suppression_lane_angle_step + orbit_side * 0.45
	angle += randf_range(-0.42, 0.42)
	var distance_t := randf_range(suppression_lane_distance_min, suppression_lane_distance_max)
	var distance := suppression_area_radius * clampf(distance_t, 0.0, 1.0)
	return Vector2.RIGHT.rotated(angle) * distance


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
	_base_hurtbox_monitoring = true
	_base_hurtbox_monitorable = true


func play_spawn_intro() -> void:
	if sprite == null:
		return

	_spawn_intro_active = true
	_disable_spawn_intro_collision()
	_ensure_spawn_intro_shadow()

	var base_position := sprite.position
	var base_scale := sprite.scale
	var base_modulate := _base_stun_modulate
	var duration := maxf(spawn_intro_duration, 0.01)

	sprite.position = base_position + Vector2.UP * spawn_intro_fall_height
	sprite.rotation_degrees = spawn_intro_start_rotation_degrees
	sprite.scale = base_scale * 0.84
	sprite.modulate = Color(base_modulate.r, base_modulate.g, base_modulate.b, 0.0)

	if _spawn_intro_shadow != null:
		_spawn_intro_shadow.visible = true
		_spawn_intro_shadow.texture = sprite.texture
		_spawn_intro_shadow.flip_h = sprite.flip_h
		_spawn_intro_shadow.flip_v = sprite.flip_v
		_spawn_intro_shadow.position = base_position + spawn_intro_shadow_offset
		_spawn_intro_shadow.scale = base_scale * 0.48
		_spawn_intro_shadow.modulate = Color(
			spawn_intro_shadow_color.r,
			spawn_intro_shadow_color.g,
			spawn_intro_shadow_color.b,
			0.0
		)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", base_position, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "rotation_degrees", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", base_modulate.a, duration * 0.35)

	if _spawn_intro_shadow != null:
		tween.tween_property(_spawn_intro_shadow, "scale", base_scale * 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_spawn_intro_shadow, "modulate:a", spawn_intro_shadow_color.a, duration * 0.45)

	tween.chain()
	tween.tween_property(sprite, "scale", base_scale * Vector2(1.12, 0.88), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", base_scale, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_spawn_intro)


func _ensure_spawn_intro_shadow() -> void:
	if _spawn_intro_shadow != null:
		return

	_spawn_intro_shadow = Sprite2D.new()
	_spawn_intro_shadow.name = "SpawnIntroShadow"
	_spawn_intro_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spawn_intro_shadow.centered = sprite.centered
	_spawn_intro_shadow.offset = sprite.offset
	_spawn_intro_shadow.z_index = sprite.z_index - 1
	_spawn_intro_shadow.visible = false
	add_child(_spawn_intro_shadow)


func _disable_spawn_intro_collision() -> void:
	collision_layer = 0
	collision_mask = 0

	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	if hurtbox != null:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)

	if hurtbox_collision_shape != null:
		hurtbox_collision_shape.set_deferred("disabled", true)


func _finish_spawn_intro() -> void:
	_spawn_intro_active = false
	_attack_pause_left = maxf(_attack_pause_left, attack_delay_after_spawn_intro)
	collision_layer = _base_collision_layer
	collision_mask = _base_collision_mask
	sprite.modulate = _base_stun_modulate

	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)

	if hurtbox != null:
		hurtbox.set_deferred("monitoring", _base_hurtbox_monitoring)
		hurtbox.set_deferred("monitorable", _base_hurtbox_monitorable)

	if hurtbox_collision_shape != null:
		hurtbox_collision_shape.set_deferred("disabled", false)

	if _spawn_intro_shadow != null:
		var shadow_tween := _spawn_intro_shadow.create_tween()
		shadow_tween.tween_property(_spawn_intro_shadow, "modulate:a", 0.0, 0.12)
		shadow_tween.tween_callback(_spawn_intro_shadow.hide)


func apply_global_stun(duration: float) -> void:
	_global_stun_left = maxf(_global_stun_left, duration)
	_set_global_stun_visual(true)


func set_attack_paused(duration: float) -> void:
	if duration <= 0.0:
		_attack_pause_left = 0.0
		return

	_attack_pause_left = maxf(_attack_pause_left, duration)


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
