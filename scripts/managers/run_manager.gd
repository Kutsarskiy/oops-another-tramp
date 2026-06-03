extends Node

enum RunState {
	MENU,
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

var current_circle: int = 1
var current_boss_id: String = ""

var player_lives: int = 5
var player_money: int = 0

var run_state: RunState = RunState.MENU


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

	set_run_state(RunState.MENU)
