extends Node
class_name BossAttackController


var attacks: Array[BossAttack] = []


func add_attack(attack: BossAttack) -> void:
	attacks.append(attack)


func _process(delta: float) -> void:

	for attack in attacks:
		attack.update(delta)
