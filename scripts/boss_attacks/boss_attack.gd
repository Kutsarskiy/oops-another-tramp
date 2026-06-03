extends RefCounted
class_name BossAttack


var owner_boss: BaseBoss


func initialize(boss: BaseBoss) -> void:
	owner_boss = boss


func update(_delta: float) -> void:
	pass
