extends Node
class_name BossAttackController

@export var active: bool = false

var attacks: Array[BossAttack] = []


func add_attack(attack: BossAttack) -> void:
	attacks.append(attack)


func set_active(is_active: bool) -> void:
	active = is_active


func _process(delta: float) -> void:
	if not active:
		return

	for attack in attacks:
		attack.update(delta)
