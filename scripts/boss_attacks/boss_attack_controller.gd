extends Node
class_name BossAttackController

signal current_attack_changed(attack_name: String)

@export var active: bool = false

var attacks: Array[BossAttack] = []
var current_attack_name: String = ""
var _attack_pause_left: float = 0.0


func add_attack(attack: BossAttack) -> void:
	attacks.append(attack)


func set_active(is_active: bool) -> void:
	active = is_active

	if not active:
		clear_attack()


func cancel_active_attacks() -> void:
	for attack in attacks:
		attack.cancel()

	clear_attack()


func pause_attacks(duration: float, should_cancel_active_attacks: bool = true) -> void:
	_attack_pause_left = maxf(_attack_pause_left, duration)

	if should_cancel_active_attacks:
		cancel_active_attacks()
	else:
		clear_attack()


func show_attack(attack_name: String) -> void:
	if current_attack_name == attack_name:
		return

	current_attack_name = attack_name
	current_attack_changed.emit(current_attack_name)


func clear_attack(attack_name: String = "") -> void:
	if not attack_name.is_empty() and current_attack_name != attack_name:
		return

	if current_attack_name.is_empty():
		return

	current_attack_name = ""
	current_attack_changed.emit(current_attack_name)


func _process(delta: float) -> void:
	if not active:
		return

	if _attack_pause_left > 0.0:
		_attack_pause_left = maxf(_attack_pause_left - delta, 0.0)
		return

	for attack in attacks:
		attack.update(delta)
