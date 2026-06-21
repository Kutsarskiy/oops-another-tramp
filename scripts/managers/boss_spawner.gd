extends Node

const DEFAULT_REWARD_SCENE: PackedScene = preload("res://scenes/items/ammo_pickup.tscn")
const DEFAULT_EXIT_PORTAL_SCENE: PackedScene = preload("res://scenes/portals/exit_portal.tscn")

@export var boss_id: String = "test_boss"
@export var start_intro_on_spawn: bool = true
@export var start_fight_on_interact: bool = true
@export var auto_start_fight_after_intro: bool = false
@export var intro_duration: float = 2.0
@export var interact_action: StringName = &"interact"
@export var intro_prompt: String = "Press E to start the boss fight."
@export var spawn_reward_on_defeat: bool = true
@export var reward_scene: PackedScene = DEFAULT_REWARD_SCENE
@export var reward_fallback_offset: Vector2 = Vector2(0.0, 140.0)
@export var spawn_exit_portal_on_defeat: bool = true
@export var exit_portal_scene: PackedScene = DEFAULT_EXIT_PORTAL_SCENE
@export var exit_fallback_position: Vector2 = Vector2(0.0, -760.0)
@export var use_run_manager_boss_id: bool = true
@export var fallback_boss_id: String = "test_boss"

@onready var spawn_point: Marker2D = $MainBossSpawnPoint
@onready var reward_spawn_point: Marker2D = get_node_or_null("RewardSpawnPoint") as Marker2D
@onready var exit_spawn_point: Marker2D = get_node_or_null("ExitSpawnPoint") as Marker2D

var _waiting_for_interact: bool = false
var _fight_started: bool = false
var _reward_spawned: bool = false
var _exit_portal_spawned: bool = false
var _prompt_refresh_left: float = 0.0


func _ready() -> void:
	RunManager.ensure_run_started()

	if use_run_manager_boss_id:
		boss_id = RunManager.current_boss_id

	BossManager.prepare_encounter()
	BossManager.encounter_completed.connect(_on_encounter_completed)
	call_deferred("_spawn_boss")


func _process(delta: float) -> void:
	if not _waiting_for_interact:
		return

	_prompt_refresh_left = maxf(_prompt_refresh_left - delta, 0.0)

	if _prompt_refresh_left <= 0.0:
		_show_action_message(intro_prompt)
		_prompt_refresh_left = 1.0

	if not InputMap.has_action(interact_action):
		return

	if Input.is_action_just_pressed(interact_action):
		_start_fight()


func spawn_boss(new_boss_id: String) -> Node:
	var scene := BossDatabase.get_boss_scene(
		new_boss_id
	)

	if scene == null:
		scene = BossDatabase.get_boss_scene(fallback_boss_id)

		if scene == null:
			push_error("BossSpawner: Unknown boss id: " + new_boss_id)
			return null

	var boss = scene.instantiate()

	_apply_boss_identity(boss, new_boss_id)

	get_tree().current_scene.add_child(boss)

	boss.global_position = spawn_point.global_position

	return boss


func _spawn_boss() -> void:
	var boss := spawn_boss(boss_id)

	if boss == null:
		return

	if start_intro_on_spawn:
		call_deferred("_begin_intro")


func _begin_intro() -> void:
	BossManager.begin_encounter_intro()
	_show_action_message("%s: %s" % [
		RunManager.get_current_circle_name(),
		BossDatabase.get_boss_display_name(boss_id)
	])

	if start_fight_on_interact:
		_waiting_for_interact = true
		_prompt_refresh_left = 0.0
	elif auto_start_fight_after_intro:
		await get_tree().create_timer(maxf(intro_duration, 0.01)).timeout
		_start_fight()


func _start_fight() -> void:
	if _fight_started:
		return

	_fight_started = true
	_waiting_for_interact = false

	BossManager.start_encounter()
	_show_action_message("Boss fight started.")


func _on_encounter_completed() -> void:
	_show_action_message("Boss defeated.")

	if spawn_reward_on_defeat:
		call_deferred("_spawn_reward")

	if spawn_exit_portal_on_defeat:
		call_deferred("_spawn_exit_portal")


func _spawn_reward() -> void:
	if _reward_spawned:
		return

	if reward_scene == null:
		return

	_reward_spawned = true

	var reward := reward_scene.instantiate() as Node2D

	if reward == null:
		return

	get_tree().current_scene.add_child(reward)
	reward.global_position = _get_reward_spawn_position()


func _get_reward_spawn_position() -> Vector2:
	if reward_spawn_point != null:
		return reward_spawn_point.global_position

	return spawn_point.global_position + reward_fallback_offset


func _spawn_exit_portal() -> void:
	if _exit_portal_spawned:
		return

	if exit_portal_scene == null:
		return

	_exit_portal_spawned = true

	var portal := exit_portal_scene.instantiate() as Node2D

	if portal == null:
		return

	get_tree().current_scene.add_child(portal)
	portal.global_position = _get_exit_spawn_position()

	if portal.has_signal("exit_requested"):
		portal.exit_requested.connect(_on_exit_requested)


func _get_exit_spawn_position() -> Vector2:
	if exit_spawn_point != null:
		return exit_spawn_point.global_position

	return exit_fallback_position


func _on_exit_requested() -> void:
	RunManager.set_run_state(RunManager.RunState.ENCOUNTER_COMPLETE)

	if RunManager.advance_to_next_circle():
		get_tree().reload_current_scene()
	else:
		_show_action_message("Run complete.")


func _apply_boss_identity(boss: Node, source_boss_id: String) -> void:
	if boss == null:
		return

	boss.set("boss_id", source_boss_id)
	boss.set("boss_name", BossDatabase.get_boss_display_name(source_boss_id))


func _show_action_message(message: String) -> void:
	print(message)

	var hud := get_tree().get_first_node_in_group("action_message_hud")

	if hud == null:
		return

	if hud.has_method("show_message"):
		hud.call("show_message", message)
