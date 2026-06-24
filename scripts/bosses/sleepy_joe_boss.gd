extends "res://scripts/bosses/test_boss.gd"

const PaperStateSpriteScript: Script = preload("res://scripts/visuals/paper_state_sprite.gd")
const AgentScene: PackedScene = preload("res://scenes/bosses/sleepy_joe_agent.tscn")
const IceCreamBombAttackScript: Script = preload("res://scripts/boss_attacks/ice_cream_bomb_attack.gd")

@export var paper_state_texture_paths: Dictionary = {
	&"sleepy": "res://assets/characters/bosses/sleepy_joe/paper/sleepy_joe_idle.png",
	&"awakened": "res://assets/characters/bosses/sleepy_joe/paper/sleepy_joe_attack.png",
	&"confused": "res://assets/characters/bosses/sleepy_joe/paper/sleepy_joe_confused.png",
	&"sleeping": "res://assets/characters/bosses/sleepy_joe/paper/sleepy_joe_sleep.png",
	&"windup": "res://assets/characters/bosses/sleepy_joe/paper/sleepy_joe_right_shoot.png"
}
@export var phase_one_move_speed: float = 60.0
@export var phase_two_move_speed: float = 120.0
@export var phase_one_basic_attack_spread_multiplier: float = 1.25
@export var center_hold_radius: float = 210.0
@export var center_steering_strength: float = 0.75
@export var phase_transition_attack_pause: float = 1.0
@export var phase_transition_camera_shake_strength: float = 18.0
@export var preferred_player_distance: float = 360.0
@export var distance_tolerance: float = 70.0
@export var strafe_speed_multiplier: float = 0.48
@export var agent_spawn_distance: float = 280.0
@export var micro_nap_min_interval: float = 7.0
@export var micro_nap_max_interval: float = 13.0
@export var micro_nap_duration: float = 2.5
@export var lost_walk_min_interval: float = 4.8
@export var lost_walk_max_interval: float = 9.0
@export var lost_walk_duration: float = 5.0
@export var lost_walk_speed_multiplier: float = 1.0
@export var micro_nap_damage_multiplier: float = 1.5
@export var random_look_min_interval: float = 1.2
@export var random_look_max_interval: float = 2.8

@onready var sleepy_sprite: Sprite2D = $Sprite2D

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


func _ready() -> void:
	boss_id = "sleepy_joe"
	boss_name = "Sleepy Joe"
	boss_max_hp = 140.0
	move_speed = phase_one_move_speed

	_paper_visual.setup(sleepy_sprite, paper_state_texture_paths)
	super()
	_add_ice_cream_bomb_attack()
	_update_paper_visual()


func _physics_process(delta: float) -> void:
	_update_phase_transition_pause(delta)

	if _update_global_stun(delta):
		velocity = Vector2.ZERO
		move_and_slide()
		_update_paper_visual()
		return

	_update_phase_one_behavior(delta)
	_update_paper_visual()

	if not is_fight_active():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _is_phase_one_micro_napping():
		velocity = Vector2.ZERO
		move_and_slide()
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
		and not _special_windup_active
		and not _is_phase_one_micro_napping()
	)


func can_start_special_attack() -> bool:
	return (
		is_fight_active()
		and current_phase == 1
		and _phase_transition_pause_left <= 0.0
		and not _special_windup_active
		and not _is_phase_one_micro_napping()
		and not _is_phase_one_lost_walking()
	)


func set_special_windup_active(is_active: bool) -> void:
	_special_windup_active = is_active
	_update_paper_visual()


func get_basic_attack_direction(target: Node2D, fallback_direction: Vector2) -> Vector2:
	if _is_phase_one_lost_walking() and target != null:
		var away_from_player := global_position - target.global_position

		if away_from_player.length_squared() > 0.001:
			return away_from_player.normalized()

	return fallback_direction


func get_basic_attack_spread_multiplier() -> float:
	if current_phase == 1:
		return phase_one_basic_attack_spread_multiplier

	return 1.0


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

	if phase_number == 2:
		move_speed = phase_two_move_speed
		_stop_phase_one_behavior()
		_start_phase_transition_pause()
		call_deferred("_spawn_agents")


func die() -> void:
	_agents.clear()
	super()


func _update_paper_visual() -> void:
	if sleepy_sprite == null:
		return

	if _special_windup_active and _paper_visual.has_state(&"windup"):
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


func _update_distance_movement(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
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
	move_and_slide()


func _update_lost_walk_movement() -> void:
	if _lost_walk_direction.length_squared() <= 0.001:
		_lost_walk_direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))

	velocity = _apply_center_steering(_lost_walk_direction.normalized() * move_speed * lost_walk_speed_multiplier)
	move_and_slide()


func _update_phase_one_behavior(delta: float) -> void:
	if not is_fight_active() or current_phase != 1:
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
	if _is_phase_one_micro_napping() or _special_windup_active:
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
	attack_controller.set_active(is_fight_active())


func _start_phase_transition_pause() -> void:
	_phase_transition_pause_left = phase_transition_attack_pause
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


func _is_phase_one_micro_napping() -> bool:
	return current_phase == 1 and _micro_nap_left > 0.0


func _is_phase_one_lost_walking() -> bool:
	return current_phase == 1 and _lost_walk_left > 0.0


func _spawn_agents() -> void:
	if _agents_spawned:
		return

	_agents_spawned = true
	var hp_value := boss_max_hp * 0.5
	var spawn_offsets := [Vector2(-agent_spawn_distance, 80.0), Vector2(agent_spawn_distance, 80.0)]
	var names := ["Agent A", "Agent B"]
	var sides := [-1.0, 1.0]

	for i in range(2):
		var agent := AgentScene.instantiate()

		if agent == null:
			continue

		agent.initialize(names[i], self, hp_value, sides[i])
		get_parent().add_child(agent)
		agent.global_position = global_position + spawn_offsets[i]
		_agents.append(agent)
