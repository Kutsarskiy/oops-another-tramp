extends RefCounted
class_name BossEncounter

var main_bosses: Array[BaseBoss] = []
var mini_bosses: Array[BaseBoss] = []
var boss_objects: Array = []


func add_main_boss(boss: BaseBoss) -> void:

	if boss not in main_bosses:
		main_bosses.append(boss)


func add_mini_boss(boss: BaseBoss) -> void:

	if boss not in mini_bosses:
		mini_bosses.append(boss)


func add_boss_object(obj) -> void:

	if obj not in boss_objects:
		boss_objects.append(obj)


func remove_main_boss(boss: BaseBoss) -> void:

	main_bosses.erase(boss)


func remove_mini_boss(boss: BaseBoss) -> void:

	mini_bosses.erase(boss)


func remove_boss_object(obj) -> void:

	boss_objects.erase(obj)


func is_completed() -> bool:

	return main_bosses.is_empty()
