extends Camera2D

@export var target_group: StringName = &"player"
@export var follow_speed: float = 18.0
@export var movement_lookahead_distance: float = 52.0
@export var movement_lookahead_speed: float = 15.0
@export var cursor_lookahead_distance: float = 72.0
@export var cursor_deadzone_radius: float = 145.0
@export var cursor_full_offset_radius: float = 460.0
@export var cursor_lookahead_speed: float = 11.0
@export var room_padding: Vector2 = Vector2(40.0, 40.0)

var _target: Node2D = null
var _movement_offset: Vector2 = Vector2.ZERO
var _cursor_offset: Vector2 = Vector2.ZERO
var _shake_offset: Vector2 = Vector2.ZERO
var _follow_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false
	make_current()
	_find_target()

	if _target != null:
		_follow_position = _clamp_to_current_room(_target.global_position)
		global_position = _follow_position


func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_find_target()

	if _target == null:
		return

	_update_offsets(delta)

	var target_position := _target.global_position + _movement_offset + _cursor_offset
	target_position = _clamp_to_current_room(target_position)

	var follow_weight := 1.0 - exp(-follow_speed * delta)
	_follow_position = _follow_position.lerp(target_position, follow_weight)
	global_position = _follow_position
	offset = _shake_offset


func set_shake_offset(shake_offset: Vector2) -> void:
	_shake_offset = shake_offset
	offset = _shake_offset


func snap_to_target() -> void:
	if _target == null or not is_instance_valid(_target):
		_find_target()

	if _target == null:
		return

	_movement_offset = Vector2.ZERO
	_cursor_offset = Vector2.ZERO
	_follow_position = _clamp_to_current_room(_target.global_position)
	global_position = _follow_position
	offset = _shake_offset


func _find_target() -> void:
	_target = get_tree().get_first_node_in_group(target_group) as Node2D


func _update_offsets(delta: float) -> void:
	var target_velocity := Vector2.ZERO

	if _target.has_method("get_camera_movement_velocity"):
		target_velocity = _target.call("get_camera_movement_velocity")
	elif _target is CharacterBody2D:
		target_velocity = (_target as CharacterBody2D).velocity

	var desired_movement_offset := Vector2.ZERO

	if target_velocity.length_squared() > 1.0:
		desired_movement_offset = target_velocity.normalized() * movement_lookahead_distance

	var movement_weight := 1.0 - exp(-movement_lookahead_speed * delta)
	_movement_offset = _movement_offset.lerp(desired_movement_offset, movement_weight)

	var mouse_vector := get_global_mouse_position() - _target.global_position
	var desired_cursor_offset := Vector2.ZERO
	var mouse_distance := mouse_vector.length()

	if mouse_distance > cursor_deadzone_radius:
		var cursor_t := inverse_lerp(cursor_deadzone_radius, cursor_full_offset_radius, mouse_distance)
		cursor_t = clampf(cursor_t, 0.0, 1.0)
		desired_cursor_offset = mouse_vector.normalized() * cursor_lookahead_distance * cursor_t

	var cursor_weight := 1.0 - exp(-cursor_lookahead_speed * delta)
	_cursor_offset = _cursor_offset.lerp(desired_cursor_offset, cursor_weight)


func _clamp_to_current_room(camera_position: Vector2) -> Vector2:
	var arena := _get_current_arena()

	if arena == null:
		return camera_position

	var arena_size: Vector2 = arena.get("arena_size")

	if arena_size.x <= 0.0 or arena_size.y <= 0.0:
		return camera_position

	var viewport_size := get_viewport_rect().size / zoom
	var half_visible := viewport_size * 0.5
	var half_arena := arena_size * 0.5

	var min_position := arena.global_position - half_arena + half_visible + room_padding
	var max_position := arena.global_position + half_arena - half_visible - room_padding

	if min_position.x > max_position.x:
		camera_position.x = arena.global_position.x
	else:
		camera_position.x = clampf(camera_position.x, min_position.x, max_position.x)

	if min_position.y > max_position.y:
		camera_position.y = arena.global_position.y
	else:
		camera_position.y = clampf(camera_position.y, min_position.y, max_position.y)

	return camera_position


func _get_current_arena() -> Node2D:
	var game_root := get_tree().current_scene

	if game_root == null:
		return null

	var arena_container := game_root.get_node_or_null("ArenaContainer")

	if arena_container == null:
		return null

	for child in arena_container.get_children():
		if child is Node2D and child.get("arena_size") is Vector2:
			return child as Node2D

	return null
