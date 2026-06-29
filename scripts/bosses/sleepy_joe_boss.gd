extends "res://scripts/bosses/test_boss.gd"

const PaperStateSpriteScript: Script = preload("res://scripts/visuals/paper_state_sprite.gd")
const AgentScene: PackedScene = preload("res://scenes/bosses/sleepy_joe_agent.tscn")
const IceCreamBombAttackScript: Script = preload("res://scripts/boss_attacks/ice_cream_bomb_attack.gd")
const IceCreamBarrageAttackScript: Script = preload("res://scripts/boss_attacks/ice_cream_barrage_attack.gd")
const IceCreamStormAttackScript: Script = preload("res://scripts/boss_attacks/ice_cream_storm_attack.gd")

@export var paper_state_texture_paths: Dictionary = {
	&"sleepy": "res://assets/characters/bosses/sleepy_joe/paper/sleepy_joe_idle.png",
	&"awakened": "res://assets/characters/bosses/sleepy_joe/paper/sleepy_joe_attack.png",
	&"confused": "res://assets/characters/bosses/sleepy_joe/paper/sleepy_joe_confused.png",
	&"sleeping": "res://assets/characters/bosses/sleepy_joe/paper/sleepy_joe_sleep.png",
	&"windup": "res://assets/characters/bosses/sleepy_joe/paper/sleepy_joe_right_shoot.png"
}
@export var phase_one_move_speed: float = 60.0
@export var phase_two_move_speed: float = 120.0
@export var rage_move_speed: float = 175.0
@export var rage_stop_distance: float = 150.0
@export var rage_overlap_recovery_distance: float = 95.0
@export var rage_chase_burst_duration: float = 0.85
@export var rage_chase_rest_duration: float = 0.35
@export var rage_rest_strafe_speed_multiplier: float = 0.35
@export var phase_one_basic_attack_spread_multiplier: float = 1.25
@export var rage_basic_attack_spread_multiplier: float = 0.75
@export var center_hold_radius: float = 210.0
@export var center_steering_strength: float = 0.75
@export var phase_transition_camera_shake_strength: float = 18.0
@export var preferred_player_distance: float = 360.0
@export var distance_tolerance: float = 70.0
@export var strafe_speed_multiplier: float = 0.48
@export var agent_spawn_distance: float = 130.0
@export var micro_nap_min_interval: float = 5.0
@export var micro_nap_max_interval: float = 10.0
@export var micro_nap_duration: float = 3.0
@export var lost_walk_min_interval: float = 10.0
@export var lost_walk_max_interval: float = 15.0
@export var lost_walk_duration: float = 3.0
@export var micro_nap_priority_window: float = 1.5
@export var lost_walk_speed_multiplier: float = 1.0
@export var micro_nap_damage_multiplier: float = 1.5
@export var random_look_min_interval: float = 1.2
@export var random_look_max_interval: float = 2.8
@export var bed_movement_bounds_enabled: bool = true
@export var mirror_collision_with_visual: bool = true
@export var bed_movement_bounds_center: Vector2 = Vector2(0.0, -430.0)
@export var bed_movement_bounds_size: Vector2 = Vector2(500.0, 310.0)
@export var bed_movement_bounds_padding: Vector2 = Vector2(55.0, 45.0)
@export var bed_boss_anchor_offset: Vector2 = Vector2(0.0, 0.0)
@export var bed_boss_anchor_arrival_distance: float = 26.0
@export var bed_boss_idle_strafe_speed_multiplier: float = 0.22
@export var bed_boss_rage_strafe_speed_multiplier: float = 0.42
@export var bed_phase_one_follow_x_multiplier: float = 0.16
@export var bed_phase_two_follow_x_multiplier: float = 0.28
@export var bed_rage_follow_x_multiplier: float = 0.48
@export var bed_phase_one_follow_y_multiplier: float = 0.34
@export var bed_phase_two_follow_y_multiplier: float = 0.42
@export var bed_rage_follow_y_multiplier: float = 0.44
@export var bed_phase_one_max_follow_x: float = 90.0
@export var bed_phase_two_max_follow_x: float = 145.0
@export var bed_rage_max_follow_x: float = 210.0
@export var bed_phase_one_back_limit_offset: float = -90.0
@export var bed_phase_two_back_limit_offset: float = -95.0
@export var bed_rage_back_limit_offset: float = -105.0
@export var bed_phase_one_front_limit_offset: float = 80.0
@export var bed_phase_two_front_limit_offset: float = 85.0
@export var bed_rage_front_limit_offset: float = 88.0
@export var bed_player_y_reference: float = 310.0
@export var bodyguard_yield_enabled: bool = true
@export var bodyguard_yield_distance: float = 74.0
@export var bodyguard_yield_max_offset: float = 28.0
@export var bodyguard_yield_agent_influence_radius: float = 120.0

@onready var sleepy_sprite: Sprite2D = $Sprite2D
@onready var sleepy_collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var sleepy_hurtbox_collision_shape: CollisionShape2D = get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D

var _paper_visual = PaperStateSpriteScript.new()
var _agents_spawned: bool = false
var _agents: Array[Node] = []
var _micro_nap_timer: float = 0.0
var _micro_nap_left: float = 0.0
var _lost_walk_timer: float = 0.0
var _lost_walk_left: float = 0.0
var _lost_walk_direction: Vector2 = Vector2.ZERO
var _random_look_timer: float = 0.0
var _look_direction: Vector2 = Vector2.LEFT
var _special_windup_active: bool = false
var _phase_transition_pause_left: float = 0.0
var _rage_active: bool = false
var _rage_chase_burst_left: float = 0.0
var _rage_chase_rest_left: float = 0.0
var _rage_strafe_side: float = 1.0
var _base_collision_shape_position: Vector2 = Vector2.ZERO
var _base_hurtbox_collision_shape_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	boss_id = "sleepy_joe"
	boss_name = "Sleepy Joe"
	boss_max_hp = 140.0
	debug_max_phase = 3
	move_speed = phase_one_move_speed
	if sleepy_collision_shape != null:
		_base_collision_shape_position = sleepy_collision_shape.position
	if sleepy_hurtbox_collision_shape != null:
		_base_hurtbox_collision_shape_position = sleepy_hurtbox_collision_shape.position

	_paper_visual.setup(sleepy_sprite, paper_state_texture_paths)
	super()
	_add_ice_cream_bomb_attack()
	_add_ice_cream_barrage_attack()
	_add_ice_cream_storm_attack()
	_update_paper_visual()


func _physics_process(delta: float) -> void:
	_update_phase_transition_pause(delta)

	if _update_global_stun(delta):
		velocity = Vector2.ZERO
		_move_and_slide_with_bed_bounds()
		_update_paper_visual()
		return

	_update_phase_one_behavior(delta)
	_update_paper_visual()

	if not is_fight_active():
		velocity = Vector2.ZERO
		_move_and_slide_with_bed_bounds()
		return

	if _is_phase_one_micro_napping():
		velocity = Vector2.ZERO
		_move_and_slide_with_bed_bounds()
		return

	if _rage_active:
		_update_rage_movement(delta)
		return

	if _special_windup_active:
		velocity = Vector2.ZERO
		_move_and_slide_with_bed_bounds()
		return

	if _is_phase_one_lost_walking():
		_update_lost_walk_movement()
		return

	_update_distance_movement(delta)


func on_attack_shot() -> void:
	_update_paper_visual()


func can_use_basic_attack() -> bool:
	return (
		is_fight_active()
		and _phase_transition_pause_left <= 0.0
		and (not _special_windup_active or _rage_active)
		and not _is_phase_one_micro_napping()
	)


func can_start_special_attack() -> bool:
	return (
		is_fight_active()
		and current_phase == 1
		and not _rage_active
		and _phase_transition_pause_left <= 0.0
		and not _special_windup_active
		and not _is_phase_one_micro_napping()
		and not _is_phase_one_lost_walking()
	)


func can_start_ice_cream_barrage() -> bool:
	return (
		is_fight_active()
		and (current_phase == 2 or _rage_active)
		and _phase_transition_pause_left <= 0.0
		and (not _special_windup_active or _rage_active)
	)


func can_start_ice_cream_storm() -> bool:
	return (
		is_fight_active()
		and current_phase == 2
		and not _rage_active
		and _phase_transition_pause_left <= 0.0
		and not _special_windup_active
	)


func set_agents_attack_paused(duration: float) -> void:
	for agent in _agents:
		if agent != null and is_instance_valid(agent) and agent.has_method("set_attack_paused"):
			agent.call("set_attack_paused", duration)


func set_special_windup_active(is_active: bool) -> void:
	if _rage_active and is_active:
		_special_windup_active = false
		_update_paper_visual()
		return

	_special_windup_active = is_active
	_update_paper_visual()


func get_basic_attack_direction(target: Node2D, fallback_direction: Vector2) -> Vector2:
	if _is_phase_one_lost_walking() and target != null:
		var away_from_player := global_position - target.global_position

		if away_from_player.length_squared() > 0.001:
			return away_from_player.normalized()

	return fallback_direction


func get_basic_attack_spread_multiplier() -> float:
	if _rage_active:
		return rage_basic_attack_spread_multiplier

	if current_phase == 1:
		return phase_one_basic_attack_spread_multiplier

	return 1.0


func is_rage_phase() -> bool:
	return _rage_active


func _debug_trigger_next_phase_condition() -> bool:
	if current_phase == 1:
		return super()

	if current_phase == 2 and not _rage_active:
		_debug_force_rage_phase()
		return true

	return false


func take_damage(amount: int) -> void:
	if defeated:
		return

	if not fight_started and not can_take_damage_before_fight:
		return

	var final_amount := _get_global_stun_modified_damage(amount)

	if _is_phase_one_micro_napping():
		final_amount *= micro_nap_damage_multiplier

	current_hp -= final_amount
	damaged.emit(amount)

	if current_hp <= 0.0:
		current_hp = 0.0
		boss_damaged.emit(current_hp)
		die()
		return

	boss_damaged.emit(current_hp)
	check_phase_transition()


func _on_boss_started() -> void:
	attack_controller.set_active(true)
	_schedule_micro_nap()
	_schedule_lost_walk()
	_random_look_timer = randf_range(random_look_min_interval, random_look_max_interval)


func enter_phase(phase_number: int) -> void:
	super(phase_number)

	if phase_number == 3:
		_enter_rage_phase()
		return

	if phase_number == 2:
		move_speed = phase_two_move_speed
		_cancel_active_special_attacks()
		_stop_phase_one_behavior()
		_start_phase_transition_pause()
		call_deferred("_spawn_agents")


func die() -> void:
	_agents.clear()
	super()


func _update_paper_visual() -> void:
	if sleepy_sprite == null:
		return

	if _rage_active and _paper_visual.has_state(&"windup"):
		_paper_visual.set_state(&"windup")
	elif _special_windup_active and _paper_visual.has_state(&"windup"):
		_paper_visual.set_state(&"windup")
	elif _is_phase_one_micro_napping() and _paper_visual.has_state(&"sleeping"):
		_paper_visual.set_state(&"sleeping")
	elif _is_phase_one_lost_walking() and _paper_visual.has_state(&"confused"):
		_paper_visual.set_state(&"confused")
	elif current_phase >= 2 and _paper_visual.has_state(&"awakened"):
		_paper_visual.set_state(&"awakened")
	else:
		_paper_visual.set_state(&"sleepy")

	if _is_phase_one_micro_napping() or current_phase == 1 and _look_direction.length_squared() > 0.001:
		_paper_visual.face_direction(_look_direction)
	elif player != null and is_instance_valid(player):
		_paper_visual.face_target(global_position, player.global_position)

	_sync_collision_mirroring()


func _update_distance_movement(delta: float) -> void:
	if bed_movement_bounds_enabled:
		_update_bed_anchor_movement(false)
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		velocity = Vector2.ZERO
		_move_and_slide_with_bed_bounds()
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var direction := Vector2.ZERO

	if distance > 0.001:
		direction = to_player / distance

	var desired_velocity := Vector2.ZERO

	if distance < preferred_player_distance - distance_tolerance:
		desired_velocity = -direction * move_speed
	elif distance > preferred_player_distance + distance_tolerance:
		desired_velocity = direction * move_speed
	else:
		desired_velocity = direction.orthogonal() * move_speed * strafe_speed_multiplier

	desired_velocity = _apply_center_steering(desired_velocity)
	velocity = desired_velocity
	_move_and_slide_with_bed_bounds()


func _update_rage_movement(delta: float) -> void:
	if bed_movement_bounds_enabled:
		_update_rage_chase_timers(delta)
		_update_bed_anchor_movement(true)
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		velocity = Vector2.ZERO
		_move_and_slide_with_bed_bounds()
		return

	_update_rage_chase_timers(delta)

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var direction := Vector2.ZERO

	if distance > 0.001:
		direction = to_player / distance

	var desired_velocity := Vector2.ZERO

	if distance < rage_overlap_recovery_distance:
		desired_velocity = -direction * move_speed * 0.55
	elif _rage_chase_burst_left > 0.0 and distance > rage_stop_distance:
		desired_velocity = direction * move_speed
	else:
		desired_velocity = direction.orthogonal() * move_speed * rage_rest_strafe_speed_multiplier * _rage_strafe_side

	velocity = _apply_center_steering(desired_velocity)
	_move_and_slide_with_bed_bounds()


func _update_rage_chase_timers(delta: float) -> void:
	if _rage_chase_burst_left > 0.0:
		_rage_chase_burst_left = maxf(_rage_chase_burst_left - delta, 0.0)

		if _rage_chase_burst_left <= 0.0:
			_rage_chase_rest_left = rage_chase_rest_duration

		return

	_rage_chase_rest_left = maxf(_rage_chase_rest_left - delta, 0.0)

	if _rage_chase_rest_left <= 0.0:
		_rage_chase_burst_left = rage_chase_burst_duration
		_rage_strafe_side *= -1.0


func _update_bed_anchor_movement(is_rage: bool) -> void:
	var anchor := _get_bed_follow_anchor(is_rage)
	var to_anchor := anchor - global_position
	var desired_velocity := Vector2.ZERO

	if to_anchor.length() > bed_boss_anchor_arrival_distance:
		desired_velocity = to_anchor.normalized() * move_speed
	else:
		var strafe_multiplier := bed_boss_rage_strafe_speed_multiplier if is_rage else bed_boss_idle_strafe_speed_multiplier
		desired_velocity = Vector2.RIGHT * move_speed * strafe_multiplier * _rage_strafe_side

	velocity = desired_velocity
	_move_and_slide_with_bed_bounds()


func _get_bed_follow_anchor(is_rage: bool) -> Vector2:
	var anchor := bed_movement_bounds_center + bed_boss_anchor_offset

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		return anchor

	var follow_x_multiplier := bed_phase_one_follow_x_multiplier
	var follow_y_multiplier := bed_phase_one_follow_y_multiplier
	var max_follow_x := bed_phase_one_max_follow_x
	var back_limit_offset := bed_phase_one_back_limit_offset
	var front_limit_offset := bed_phase_one_front_limit_offset

	if is_rage:
		follow_x_multiplier = bed_rage_follow_x_multiplier
		follow_y_multiplier = bed_rage_follow_y_multiplier
		max_follow_x = bed_rage_max_follow_x
		back_limit_offset = bed_rage_back_limit_offset
		front_limit_offset = bed_rage_front_limit_offset
	elif current_phase >= 2:
		follow_x_multiplier = bed_phase_two_follow_x_multiplier
		follow_y_multiplier = bed_phase_two_follow_y_multiplier
		max_follow_x = bed_phase_two_max_follow_x
		back_limit_offset = bed_phase_two_back_limit_offset
		front_limit_offset = bed_phase_two_front_limit_offset

	anchor.x += clampf(player.global_position.x * follow_x_multiplier, -max_follow_x, max_follow_x)

	var player_front_pull := (player.global_position.y - bed_player_y_reference) * follow_y_multiplier
	anchor.y += clampf(player_front_pull, back_limit_offset, front_limit_offset)

	if bodyguard_yield_enabled and current_phase == 2 and not is_rage:
		anchor += _get_bodyguard_backline_offset()

	return _clamp_point_to_bed_rect(anchor, get_bed_movement_rect())


func get_bed_movement_rect() -> Rect2:
	var padded_size := Vector2(
		maxf(bed_movement_bounds_size.x - bed_movement_bounds_padding.x * 2.0, 1.0),
		maxf(bed_movement_bounds_size.y - bed_movement_bounds_padding.y * 2.0, 1.0)
	)

	return Rect2(bed_movement_bounds_center - padded_size * 0.5, padded_size)


func _move_and_slide_with_bed_bounds() -> void:
	move_and_slide()
	_clamp_to_bed_bounds()


func _clamp_to_bed_bounds() -> void:
	if not bed_movement_bounds_enabled:
		return

	var bed_rect := get_bed_movement_rect()
	global_position = _clamp_point_to_bed_rect(global_position, bed_rect)


func _clamp_point_to_bed_rect(point: Vector2, bed_rect: Rect2) -> Vector2:
	return Vector2(
		clampf(point.x, bed_rect.position.x, bed_rect.end.x),
		clampf(point.y, bed_rect.position.y, bed_rect.end.y)
	)


func _get_bodyguard_backline_offset() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.ZERO

	if _get_alive_agent_count() <= 0:
		return Vector2.ZERO

	var player_to_boss := global_position - player.global_position

	if player_to_boss.length_squared() <= 0.001:
		player_to_boss = Vector2.UP

	return player_to_boss.normalized() * bodyguard_yield_max_offset


func _get_alive_agent_count() -> int:
	var count := 0

	for agent in _agents:
		if _is_agent_alive(agent):
			count += 1

	return count


func apply_bodyguard_pressure(agent_position: Vector2, desired_front_distance: float, max_push: float) -> void:
	if not bodyguard_yield_enabled or current_phase != 2 or _rage_active:
		return

	if player == null or not is_instance_valid(player):
		return

	var player_direction := player.global_position - global_position

	if player_direction.length_squared() <= 0.001:
		player_direction = Vector2.DOWN

	player_direction = player_direction.normalized()
	var to_agent := agent_position - global_position
	var front_projection := to_agent.dot(player_direction)

	if front_projection <= 0.0:
		return

	var side_distance := absf(to_agent.dot(player_direction.orthogonal()))
	var side_factor := 1.0 - clampf(side_distance / bodyguard_yield_agent_influence_radius, 0.0, 1.0)

	if side_factor <= 0.0:
		return

	var missing_distance := desired_front_distance - front_projection

	if missing_distance <= 0.0:
		return

	var push_distance := minf(missing_distance, max_push) * side_factor
	var bed_rect := get_bed_movement_rect()
	global_position = _clamp_point_to_bed_rect(global_position - player_direction * push_distance, bed_rect)


func _sync_collision_mirroring() -> void:
	var mirror_sign := -1.0 if mirror_collision_with_visual and sleepy_sprite != null and sleepy_sprite.flip_h else 1.0

	if sleepy_collision_shape != null:
		sleepy_collision_shape.position = Vector2(
			_base_collision_shape_position.x * mirror_sign,
			_base_collision_shape_position.y
		)

	if sleepy_hurtbox_collision_shape != null:
		sleepy_hurtbox_collision_shape.position = Vector2(
			_base_hurtbox_collision_shape_position.x * mirror_sign,
			_base_hurtbox_collision_shape_position.y
		)


func _update_lost_walk_movement() -> void:
	if _lost_walk_direction.length_squared() <= 0.001:
		_lost_walk_direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))

	velocity = _apply_center_steering(_lost_walk_direction.normalized() * move_speed * lost_walk_speed_multiplier)
	_move_and_slide_with_bed_bounds()


func _update_phase_one_behavior(delta: float) -> void:
	if not is_fight_active() or current_phase != 1 or _rage_active:
		return

	if _micro_nap_left > 0.0:
		_micro_nap_left = maxf(_micro_nap_left - delta, 0.0)

		if _micro_nap_left <= 0.0:
			_end_micro_nap()

		return

	_update_random_look(delta)

	_micro_nap_timer = maxf(_micro_nap_timer - delta, 0.0)

	if _micro_nap_timer <= 0.0:
		_start_micro_nap()
		return

	if _lost_walk_left > 0.0:
		_lost_walk_left = maxf(_lost_walk_left - delta, 0.0)

		if _lost_walk_left <= 0.0:
			_schedule_lost_walk()

		return

	_lost_walk_timer = maxf(_lost_walk_timer - delta, 0.0)

	if _lost_walk_timer <= 0.0:
		_start_lost_walk()


func _start_micro_nap() -> void:
	if _is_phase_one_lost_walking() or _special_windup_active:
		_schedule_micro_nap()
		return

	_micro_nap_left = micro_nap_duration
	_lost_walk_left = 0.0
	velocity = Vector2.ZERO
	attack_controller.set_active(false)


func _end_micro_nap() -> void:
	_schedule_micro_nap()
	_schedule_lost_walk()

	if is_fight_active():
		attack_controller.set_active(true)


func _start_lost_walk() -> void:
	if _is_phase_one_micro_napping() or _special_windup_active or _micro_nap_timer <= micro_nap_priority_window:
		_schedule_lost_walk()
		return

	_lost_walk_left = lost_walk_duration
	_lost_walk_direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	_look_direction = _lost_walk_direction


func _schedule_micro_nap() -> void:
	_micro_nap_timer = randf_range(micro_nap_min_interval, micro_nap_max_interval)


func _schedule_lost_walk() -> void:
	_lost_walk_timer = randf_range(lost_walk_min_interval, lost_walk_max_interval)
	_lost_walk_left = 0.0


func _update_random_look(delta: float) -> void:
	_random_look_timer = maxf(_random_look_timer - delta, 0.0)

	if _random_look_timer > 0.0:
		return

	_random_look_timer = randf_range(random_look_min_interval, random_look_max_interval)

	if randf() < 0.55:
		_look_direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	elif player != null and is_instance_valid(player):
		_look_direction = (player.global_position - global_position).normalized()


func _stop_phase_one_behavior() -> void:
	_micro_nap_left = 0.0
	_lost_walk_left = 0.0
	_special_windup_active = false
	_update_paper_visual()
	attack_controller.set_active(is_fight_active())


func _cancel_active_special_attacks() -> void:
	if attack_controller != null and attack_controller.has_method("cancel_active_attacks"):
		attack_controller.call("cancel_active_attacks")

	_special_windup_active = false


func _enter_rage_phase() -> void:
	if _rage_active:
		return

	_rage_active = true
	move_speed = rage_move_speed
	_rage_chase_burst_left = rage_chase_burst_duration
	_rage_chase_rest_left = 0.0
	_rage_strafe_side = -1.0 if randf() < 0.5 else 1.0
	_phase_transition_pause_left = 0.0
	_cancel_active_special_attacks()
	_stop_phase_one_behavior()
	_special_windup_active = false
	attack_controller.set_active(is_fight_active())
	_update_paper_visual()


func _start_phase_transition_pause() -> void:
	_phase_transition_pause_left = phase_transition_attack_pause

	if attack_controller != null and attack_controller.has_method("pause_attacks"):
		attack_controller.call("pause_attacks", phase_transition_attack_pause)
	else:
		attack_controller.set_active(false)

	var player_node := get_tree().get_first_node_in_group("player")

	if player_node != null and player_node.has_method("play_phase_transition_feedback"):
		player_node.call(
			"play_phase_transition_feedback",
			phase_transition_attack_pause,
			phase_transition_camera_shake_strength
		)


func _update_phase_transition_pause(delta: float) -> void:
	if _phase_transition_pause_left <= 0.0:
		return

	_phase_transition_pause_left = maxf(_phase_transition_pause_left - delta, 0.0)

	if _phase_transition_pause_left <= 0.0 and is_fight_active():
		attack_controller.set_active(true)


func _apply_center_steering(base_velocity: Vector2) -> Vector2:
	var arena_center := _get_current_arena_center()
	var to_center := arena_center - global_position
	var distance_from_center := to_center.length()

	if distance_from_center <= center_hold_radius or distance_from_center <= 0.001:
		return base_velocity

	var center_velocity := to_center.normalized() * move_speed * center_steering_strength
	return (base_velocity + center_velocity).limit_length(move_speed)


func _get_current_arena_center() -> Vector2:
	if bed_movement_bounds_enabled:
		return bed_movement_bounds_center

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


func _add_ice_cream_bomb_attack() -> void:
	if attack_controller == null:
		return

	var ice_cream_bomb: BossAttack = IceCreamBombAttackScript.new()
	ice_cream_bomb.initialize(self)
	attack_controller.attacks.insert(0, ice_cream_bomb)


func _add_ice_cream_barrage_attack() -> void:
	if attack_controller == null:
		return

	var ice_cream_barrage: BossAttack = IceCreamBarrageAttackScript.new()
	ice_cream_barrage.initialize(self)
	attack_controller.add_attack(ice_cream_barrage)


func _add_ice_cream_storm_attack() -> void:
	if attack_controller == null:
		return

	var ice_cream_storm: BossAttack = IceCreamStormAttackScript.new()
	ice_cream_storm.initialize(self)
	attack_controller.add_attack(ice_cream_storm)


func _is_phase_one_micro_napping() -> bool:
	return current_phase == 1 and _micro_nap_left > 0.0


func _is_phase_one_lost_walking() -> bool:
	return current_phase == 1 and _lost_walk_left > 0.0


func _spawn_agents() -> void:
	if _agents_spawned:
		return

	_agents_spawned = true
	var hp_value := boss_max_hp * 0.5
	var spawn_offsets := [Vector2(-agent_spawn_distance, 95.0), Vector2(agent_spawn_distance, 95.0)]
	var names := ["Agent A", "Agent B"]
	var sides := [-1.0, 1.0]

	for i in range(2):
		var agent := AgentScene.instantiate()

		if agent == null:
			continue

		agent.initialize(names[i], self, hp_value, sides[i])
		get_parent().add_child(agent)
		agent.global_position = global_position + spawn_offsets[i]
		if agent.has_signal("agent_died") and not agent.agent_died.is_connected(_on_agent_died):
			agent.agent_died.connect(_on_agent_died)
		if agent.has_method("play_spawn_intro"):
			agent.call("play_spawn_intro")
		_agents.append(agent)


func _on_agent_died(_agent_name: String) -> void:
	_check_rage_phase_from_agents()


func _check_rage_phase_from_agents() -> void:
	if _rage_active or not _agents_spawned or defeated:
		return

	_prune_dead_agents()

	for agent in _agents:
		if _is_agent_alive(agent):
			return

	enter_phase(3)


func _prune_dead_agents() -> void:
	var alive_agents: Array[Node] = []

	for agent in _agents:
		if _is_agent_alive(agent):
			alive_agents.append(agent)

	_agents = alive_agents


func _is_agent_alive(agent: Node) -> bool:
	if agent == null or not is_instance_valid(agent):
		return false

	if agent.get("current_hp") is float:
		return float(agent.get("current_hp")) > 0.0

	return not agent.is_queued_for_deletion()


func _debug_kill_all_agents() -> void:
	for agent in _agents.duplicate():
		if agent == null or not is_instance_valid(agent):
			continue

		if agent.has_method("debug_kill"):
			agent.call("debug_kill")
		elif agent.has_method("take_damage"):
			agent.call("take_damage", 999999)
		else:
			agent.queue_free()

	call_deferred("_check_rage_phase_from_agents")


func _debug_force_rage_phase() -> void:
	_debug_kill_all_agents()
	_agents.clear()
	_agents_spawned = true
	enter_phase(3)
