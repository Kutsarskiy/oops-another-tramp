extends Damageable
class_name BaseBoss

const BOSS_COLLISION_LAYER_BIT: int = 3
const PLAYER_BODY_LAYER_BIT: int = 1
const WALL_COLLISION_LAYER_BIT: int = 0


signal boss_started
signal boss_intro_started
signal boss_damaged(current_hp)
signal phase_changed(new_phase)
signal boss_defeated

@export var boss_id: String = "base_boss"
@export var boss_name: String = "Base Boss"
@export var boss_max_hp: float = 100.0
@export var can_take_damage_before_fight: bool = false
@export var global_stun_damage_multiplier: float = 2.0
@export var global_stun_tint: Color = Color(1.0, 0.58, 0.58, 1.0)
@export var boss_defeat_enemy_burn_tint: Color = Color(1.0, 0.18, 0.18, 1.0)
@export var boss_defeat_enemy_burn_duration: float = 0.5
@export var boss_defeat_enemy_evaporate_duration: float = 0.5
@export var debug_max_phase: int = 2
@export var phase_transition_attack_pause: float = 1.0

var current_phase: int = 1
var fight_started: bool = false
var defeated: bool = false
var _global_stun_left: float = 0.0
var _attack_controller_was_active_before_stun: bool = false
var _stun_sprite: Sprite2D = null
var _base_stun_modulate: Color = Color.WHITE

var phase_thresholds: Dictionary = {
	2: 0.50
}

@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D


func _ready() -> void:

	max_hp = boss_max_hp

	add_to_group("enemy")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1 << BOSS_COLLISION_LAYER_BIT
	collision_mask = (1 << WALL_COLLISION_LAYER_BIT) | (1 << PLAYER_BODY_LAYER_BIT)

	_configure_hurtbox()

	super()
	_configure_global_stun_visual()


func begin_intro() -> void:
	boss_intro_started.emit()


func start_fight() -> void:
	if fight_started or defeated:
		return

	fight_started = true
	boss_started.emit()


func take_damage(amount: int) -> void:
	if defeated:
		return

	if not fight_started and not can_take_damage_before_fight:
		return

	current_hp -= _get_global_stun_modified_damage(amount)
	damaged.emit(amount)

	if current_hp <= 0.0:
		current_hp = 0.0
		boss_damaged.emit(current_hp)
		die()
		return

	boss_damaged.emit(current_hp)

	check_phase_transition()


func check_phase_transition() -> void:

	for phase in phase_thresholds.keys():

		if phase <= current_phase:
			continue

		var threshold: float = phase_thresholds[phase]

		if current_hp <= max_hp * threshold:
			enter_phase(phase)


func enter_phase(phase_number: int) -> void:

	current_phase = phase_number

	phase_changed.emit(current_phase)
	_pause_attacks_for_phase_transition()


func debug_advance_phase_or_die() -> void:
	if defeated:
		return

	if _debug_trigger_next_phase_condition():
		return

	die()


func _debug_trigger_next_phase_condition() -> bool:
	var next_phase := _debug_get_next_phase_with_health_threshold()

	if next_phase <= current_phase:
		return false

	_debug_drop_health_to_phase_threshold(next_phase)
	return true


func _debug_get_next_phase_with_health_threshold() -> int:
	var phases := phase_thresholds.keys()
	phases.sort()

	for phase in phases:
		var phase_number := int(phase)

		if phase_number > current_phase:
			return phase_number

	return -1


func _debug_drop_health_to_phase_threshold(phase_number: int) -> void:
	if not phase_thresholds.has(phase_number):
		return

	var threshold := float(phase_thresholds[phase_number])
	current_hp = maxf(max_hp * threshold - 0.001, 1.0)
	boss_damaged.emit(current_hp)
	check_phase_transition()


func die() -> void:
	if defeated:
		return

	defeated = true
	fight_started = false
	_trigger_boss_defeat_feedback()
	_burn_and_remove_enemy(self)

	boss_defeated.emit()
	died.emit()


func is_fight_active() -> bool:
	return fight_started and not defeated


func _pause_attacks_for_phase_transition() -> void:
	if phase_transition_attack_pause <= 0.0:
		return

	var attack_controller := get_node_or_null("AttackController")

	if attack_controller != null and attack_controller.has_method("pause_attacks"):
		attack_controller.call("pause_attacks", phase_transition_attack_pause)


func apply_global_stun(duration: float) -> void:
	var was_already_stunned := is_globally_stunned()
	_global_stun_left = maxf(_global_stun_left, duration)

	var attack_controller := get_node_or_null("AttackController")

	if attack_controller != null and attack_controller.has_method("set_active"):
		if not was_already_stunned:
			_attack_controller_was_active_before_stun = bool(attack_controller.get("active"))

		attack_controller.call("set_active", false)

	_set_global_stun_visual(true)


func is_globally_stunned() -> bool:
	return _global_stun_left > 0.0


func _update_global_stun(delta: float) -> bool:
	if _global_stun_left <= 0.0:
		return false

	_global_stun_left = maxf(_global_stun_left - delta, 0.0)

	if _global_stun_left <= 0.0:
		var attack_controller := get_node_or_null("AttackController")

		if attack_controller != null and attack_controller.has_method("set_active"):
			attack_controller.call("set_active", _attack_controller_was_active_before_stun and is_fight_active())

		_set_global_stun_visual(false)

	return true


func _get_global_stun_modified_damage(amount: int) -> float:
	var final_amount := float(amount)

	if is_globally_stunned():
		final_amount *= global_stun_damage_multiplier

	return final_amount


func _configure_global_stun_visual() -> void:
	_stun_sprite = get_node_or_null("Sprite2D") as Sprite2D

	if _stun_sprite != null:
		_base_stun_modulate = _stun_sprite.modulate


func _set_global_stun_visual(is_enabled: bool) -> void:
	if _stun_sprite == null:
		return

	if is_enabled:
		_stun_sprite.modulate = _base_stun_modulate * global_stun_tint
	else:
		_stun_sprite.modulate = _base_stun_modulate


func _trigger_boss_defeat_feedback() -> void:
	var player := get_tree().get_first_node_in_group("player")

	if player != null and player.has_method("play_boss_defeat_feedback"):
		player.call("play_boss_defeat_feedback")

	_evaporate_all_bullets()
	_burn_and_remove_all_enemies()


func _evaporate_all_bullets() -> void:
	for group_name in ["enemy_bullet", "player_bullet"]:
		for bullet in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(bullet):
				continue

			if bullet.has_method("evaporate"):
				bullet.call("evaporate")
			else:
				bullet.queue_free()


func _burn_and_remove_all_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self or not is_instance_valid(enemy):
			continue

		_burn_and_remove_enemy(enemy)


func _burn_and_remove_enemy(enemy: Node) -> void:
	if enemy.has_method("begin_boss_defeat_vanish"):
		enemy.call("begin_boss_defeat_vanish")

	if enemy.has_method("apply_global_stun"):
		enemy.call(
			"apply_global_stun",
			boss_defeat_enemy_burn_duration + boss_defeat_enemy_evaporate_duration
		)

	var enemy_sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D

	if enemy_sprite != null:
		enemy_sprite.modulate = boss_defeat_enemy_burn_tint

	var collision_object := enemy as CollisionObject2D

	if collision_object != null:
		collision_object.set_deferred("collision_layer", 0)
		collision_object.set_deferred("collision_mask", 0)

	var enemy_ref: WeakRef = weakref(enemy)
	var timer := get_tree().create_timer(boss_defeat_enemy_burn_duration)
	timer.timeout.connect(func() -> void:
		var enemy_node := enemy_ref.get_ref() as Node

		if enemy_node != null:
			_evaporate_enemy(enemy_node)
	)


func _evaporate_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return

	var enemy_sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
	var enemy_node_2d := enemy as Node2D
	var duration := maxf(boss_defeat_enemy_evaporate_duration, 0.01)

	if enemy_sprite != null:
		var tween := enemy.create_tween()
		var enemy_ref: WeakRef = weakref(enemy)
		tween.set_parallel(true)
		tween.tween_property(enemy_sprite, "modulate:a", 0.0, duration)

		if enemy_node_2d != null:
			tween.tween_property(enemy_node_2d, "scale", enemy_node_2d.scale * 1.12, duration)

		tween.finished.connect(func() -> void:
			var enemy_node := enemy_ref.get_ref() as Node

			if enemy_node != null:
				enemy_node.queue_free()
		)
		return

	var enemy_ref: WeakRef = weakref(enemy)
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		var enemy_node := enemy_ref.get_ref() as Node

		if enemy_node != null:
			enemy_node.queue_free()
	)


func _configure_hurtbox() -> void:
	if hurtbox == null:
		return

	hurtbox.add_to_group("enemy")
	hurtbox.add_to_group("boss_hurtbox")
	hurtbox.set_meta("damage_owner", self)

	hurtbox.set_deferred("monitoring", true)
	hurtbox.set_deferred("monitorable", true)
	hurtbox.collision_layer = 1 << BOSS_COLLISION_LAYER_BIT
	hurtbox.collision_mask = 0
