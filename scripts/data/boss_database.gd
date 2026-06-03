extends Node
class_name BossDatabase


static func get_boss_scene(boss_id: String) -> PackedScene:

	match boss_id:

		"test_boss":
			return preload(
				"res://scenes/bosses/test_boss.tscn"
			)

	return null
