extends Node

@export var arena_container_path: NodePath = ^"ArenaContainer"

@onready var arena_container: Node = get_node_or_null(arena_container_path)

var current_arena: Node = null


func _ready() -> void:
	RunManager.ensure_run_started()
	load_current_arena()


func load_current_arena() -> void:
	if arena_container == null:
		push_error("ArenaLoader: ArenaContainer not found.")
		return

	_clear_current_arena()

	var arena_scene: PackedScene = null

	if RunManager.is_in_test_room():
		arena_scene = CircleDatabase.get_test_room_scene()
	else:
		var data := RunManager.get_current_circle_data()

		if data.is_empty():
			push_error("ArenaLoader: current circle data is empty.")
			return

		arena_scene = data.get("arena_scene", null)

	if arena_scene == null:
		push_error("ArenaLoader: arena_scene is missing for circle " + str(RunManager.current_circle))
		return

	current_arena = arena_scene.instantiate()
	arena_container.add_child(current_arena)
	_position_player_at_spawn()


func _clear_current_arena() -> void:
	if current_arena != null and is_instance_valid(current_arena):
		current_arena.queue_free()

	current_arena = null

	for child in arena_container.get_children():
		child.queue_free()


func _position_player_at_spawn() -> void:
	if current_arena == null:
		return

	var spawn_point := current_arena.get_node_or_null("PlayerSpawnPoint") as Node2D

	if spawn_point == null:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		return

	player.global_position = spawn_point.global_position
	_snap_camera_to_player()


func _snap_camera_to_player() -> void:
	var camera := get_viewport().get_camera_2d()

	if camera == null:
		return

	if camera.has_method("snap_to_target"):
		camera.call_deferred("snap_to_target")
