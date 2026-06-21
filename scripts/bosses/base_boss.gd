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

var current_phase: int = 1
var fight_started: bool = false
var defeated: bool = false

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

	current_hp -= amount
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


func die() -> void:
	if defeated:
		return

	defeated = true
	fight_started = false

	boss_defeated.emit()

	super()


func is_fight_active() -> bool:
	return fight_started and not defeated


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
