extends Damageable
class_name BaseBoss


signal boss_started
signal boss_damaged(current_hp)
signal phase_changed(new_phase)
signal boss_defeated

@export var boss_id: String = "base_boss"
@export var boss_name: String = "Base Boss"
@export var boss_max_hp: float = 100.0

var current_phase: int = 1

var phase_thresholds: Dictionary = {
	2: 0.50
}


func _ready() -> void:

	max_hp = boss_max_hp

	super()

	boss_started.emit()


func take_damage(amount: int) -> void:

	super(amount)

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

	boss_defeated.emit()

	super()
