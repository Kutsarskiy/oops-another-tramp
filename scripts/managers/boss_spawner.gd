extends Node

@export var boss_id: String = "test_boss"

@onready var spawn_point: Marker2D = $MainBossSpawnPoint


func _ready() -> void:

	call_deferred("_spawn_boss")


func spawn_boss(new_boss_id: String) -> Node:

	var scene := BossDatabase.get_boss_scene(
		new_boss_id
	)

	if scene == null:

		push_error(
			"BossSpawner: Unknown boss id: "
			+ new_boss_id
		)

		return null

	var boss = scene.instantiate()

	get_tree().current_scene.add_child(boss)

	boss.global_position = spawn_point.global_position

	return boss


func _spawn_boss() -> void:

	spawn_boss(boss_id)
