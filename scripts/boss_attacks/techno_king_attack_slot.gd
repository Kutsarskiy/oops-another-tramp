extends BossAttack
class_name TechnoKingAttackSlot


var attack_id: StringName = &""
var phase: int = 1
var asset_keys: Array[StringName] = []


func configure(new_attack_id: StringName, new_debug_name: String, new_phase: int, new_asset_keys: Array[StringName] = []) -> void:
	attack_id = new_attack_id
	debug_attack_name = new_debug_name
	phase = new_phase
	asset_keys = new_asset_keys
