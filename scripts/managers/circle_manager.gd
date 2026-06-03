extends Node

signal circle_started(circle_id)
signal circle_completed(circle_id)

var circle_id: int = 1
var circle_name: String = ""

var boss_id: String = ""
var boss_scene: PackedScene = null


func load_circle(new_circle_id: int) -> void:

	var data := CircleDatabase.get_circle_data(new_circle_id)

	if data.is_empty():
		push_error("Circle not found: " + str(new_circle_id))
		return

	circle_id = new_circle_id
	circle_name = data["name"]
	boss_id = data["boss_id"]
	boss_scene = data["boss_scene"]


func start_circle() -> void:

	RunManager.set_current_circle(circle_id)

	RunManager.set_current_boss(boss_id)

	RunManager.set_run_state(
		RunManager.RunState.IN_CIRCLE
	)

	circle_started.emit(circle_id)


func complete_circle() -> void:

	circle_completed.emit(circle_id)


func get_next_circle() -> int:
	return circle_id + 1
