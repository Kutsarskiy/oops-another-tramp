extends RefCounted
class_name BossAttack


var owner_boss: BaseBoss
var debug_attack_name: String = ""


func initialize(boss: BaseBoss) -> void:
	owner_boss = boss


func get_debug_attack_name() -> String:
	if not debug_attack_name.is_empty():
		return debug_attack_name

	return get_script().resource_path.get_file().get_basename().capitalize()


func update(_delta: float) -> void:
	pass


func cancel() -> void:
	pass


func show_debug_attack(attack_name: String = "") -> void:
	if owner_boss == null:
		return

	var attack_controller := owner_boss.get_node_or_null("AttackController")

	if attack_controller != null and attack_controller.has_method("show_attack"):
		attack_controller.call("show_attack", attack_name if not attack_name.is_empty() else get_debug_attack_name())


func clear_debug_attack(attack_name: String = "") -> void:
	if owner_boss == null:
		return

	var attack_controller := owner_boss.get_node_or_null("AttackController")

	if attack_controller != null and attack_controller.has_method("clear_attack"):
		attack_controller.call("clear_attack", attack_name if not attack_name.is_empty() else get_debug_attack_name())
