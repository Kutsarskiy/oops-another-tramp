extends Node

enum RunState {
	MENU,
	TEST_ROOM,
	IN_CIRCLE,
	BOSS_INTRO,
	BOSS_FIGHT,
	BOSS_DEFEATED,
	ENCOUNTER_COMPLETE,
	SHOP,
	RUN_COMPLETE,
	GAME_OVER
}

signal run_state_changed(new_state)
signal circle_changed(circle_id)
signal boss_changed(boss_id)
signal run_completed

var current_circle: int = 1
var current_boss_id: String = ""

var player_lives: int = 5
var player_money: int = 0
var player_snapshot: Dictionary = {}

var run_state: RunState = RunState.MENU


func ensure_run_started() -> void:
	if run_state == RunState.MENU:
		start_new_run()


func start_new_run() -> void:
	current_circle = 1
	current_boss_id = ""

	player_lives = 5
	player_money = 0
	player_snapshot = {}

	set_run_state(RunState.TEST_ROOM)


func enter_test_room() -> void:
	current_boss_id = ""
	set_run_state(RunState.TEST_ROOM)


func is_in_test_room() -> bool:
	return run_state == RunState.TEST_ROOM


func load_circle(circle_id: int) -> bool:
	var data := CircleDatabase.get_circle_data(circle_id)

	if data.is_empty():
		push_error("RunManager: Circle not found: " + str(circle_id))
		return false

	set_current_circle(circle_id)
	set_current_boss(str(data.get("boss_id", "")))
	set_run_state(RunState.IN_CIRCLE)

	return true


func advance_to_next_circle() -> bool:
	save_player_snapshot()

	if current_circle >= CircleDatabase.get_circle_count():
		set_run_state(RunState.RUN_COMPLETE)
		run_completed.emit()
		return false

	return load_circle(current_circle + 1)


func get_current_circle_data() -> Dictionary:
	return CircleDatabase.get_circle_data(current_circle)


func get_current_circle_name() -> String:
	var data := get_current_circle_data()

	if data.is_empty():
		return "Unknown Circle"

	return str(data.get("name", "Unknown Circle"))


func is_final_circle() -> bool:
	return current_circle >= CircleDatabase.get_circle_count()


func save_player_snapshot() -> void:
	var player := get_tree().get_first_node_in_group("player")

	if player == null:
		return

	if not player.has_method("create_run_snapshot"):
		return

	var snapshot: Variant = player.call("create_run_snapshot")

	if snapshot is Dictionary:
		player_snapshot = snapshot


func has_player_snapshot() -> bool:
	return not player_snapshot.is_empty()


func set_run_state(new_state: RunState) -> void:
	if run_state == new_state:
		return

	run_state = new_state
	run_state_changed.emit(run_state)


func set_current_circle(circle_id: int) -> void:
	current_circle = circle_id
	circle_changed.emit(circle_id)


func set_current_boss(boss_id: String) -> void:
	current_boss_id = boss_id
	boss_changed.emit(boss_id)


func add_money(amount: int) -> void:
	player_money += amount


func remove_money(amount: int) -> void:
	player_money = max(0, player_money - amount)


func lose_life() -> void:
	player_lives -= 1

	if player_lives <= 0:
		player_lives = 0
		set_run_state(RunState.GAME_OVER)


func reset_run() -> void:
	current_circle = 1
	current_boss_id = ""

	player_lives = 5
	player_money = 0
	player_snapshot = {}

	set_run_state(RunState.MENU)
