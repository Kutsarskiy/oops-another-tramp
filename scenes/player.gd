extends CharacterBody2D

# --- Базовые параметры ---
@export var move_speed: float = 200.0
@export var fire_rate: float = 10.0 # выстрелов в секунду

# --- Трамп-формы ---
# scale — размер активного Трампа
# speed — скорость активного Трампа
var trump_forms: Array[Dictionary] = [
	{"scale": 1.0, "speed": 200.0},
	{"scale": 0.8, "speed": 220.0},
	{"scale": 0.6, "speed": 240.0},
	{"scale": 0.4, "speed": 260.0},
	{"scale": 0.2, "speed": 290.0}
]

var current_form_index: int = 0

# --- Урон / неуязвимость ---
@export var after_hit_invulnerability: float = 0.8

var _invulnerability_left: float = 0.0
var _blink_timer: float = 0.0
var _is_game_over: bool = false

# --- Рывок ---
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.5
@export var after_dash_shoot_lock: float = 0.5

var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _shoot_lock_left: float = 0.0

# --- Хвост Трампов ---
@export var ghost_spacing_frames: int = 8
@export var ghost_follow_speed: float = 8.0
@export var ghost_base_size: float = 64.0

var _ghosts: Array[Polygon2D] = []
var _position_history: Array[Vector2] = []

# --- Стрельба ---
@export var muzzle_distance: float = 36.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var muzzle: Marker2D = $Muzzle

var _shoot_cd: float = 0.0
var BulletScene: PackedScene = preload("res://scenes/bullet.tscn")


func _ready() -> void:
	add_to_group("player")
	z_index = 10

	_apply_current_form()
	_reset_tail_history()

	# Важно: хвост создаём отложенно, когда сцена уже полностью собрана.
	call_deferred("_create_trump_tail")

	_debug_print_state("START")


func _physics_process(delta: float) -> void:
	if _is_game_over:
		return

	_handle_debug_input()
	_update_invulnerability(delta)
	_update_dash_timers(delta)

	if InputMap.has_action("dash") and Input.is_action_just_pressed("dash"):
		_try_start_dash()

	# --- Movement / Dash ---
	if _is_dashing():
		velocity = _dash_direction * dash_speed
	else:
		var dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = dir * move_speed

	move_and_slide()

	# --- Хвост ---
	_record_position()
	_update_trump_tail(delta)

	# --- Shooting ---
	_shoot_cd = maxf(_shoot_cd - delta, 0.0)

	if not _is_dashing() and _shoot_lock_left <= 0.0 and Input.is_action_pressed("shoot") and _shoot_cd <= 0.0:
		_shoot_cd = 1.0 / fire_rate
		_shoot()


func _shoot() -> void:
	var shoot_vector: Vector2 = get_global_mouse_position() - global_position

	if shoot_vector.length_squared() < 0.0001:
		shoot_vector = Vector2.RIGHT

	var shoot_direction: Vector2 = shoot_vector.normalized()
	var current_scale: float = _get_current_scale()

	var bullet = BulletScene.instantiate()
	bullet.setup_bullet(false) # пуля игрока

	bullet.global_position = global_position + shoot_direction * muzzle_distance * current_scale
	bullet.direction = shoot_direction

	get_parent().add_child(bullet)


func take_damage(_amount: int) -> void:
	if _is_game_over:
		return

	if _is_invulnerable():
		return

	# Важно: сначала блокируем следующий урон, потом меняем форму.
	# Так несколько пуль в один момент не смогут снять сразу несколько Трампов.
	_set_invulnerable(after_hit_invulnerability)
	_lose_current_form()


func _lose_current_form() -> void:
	print("Trump form lost:", current_form_index + 1)

	if current_form_index + 1 >= trump_forms.size():
		_game_over()
		return

	var new_player_position: Vector2 = global_position

	# Новая активная форма появляется на позиции первой копии из хвоста.
	if _ghosts.size() > 0 and is_instance_valid(_ghosts[0]):
		new_player_position = _ghosts[0].global_position

	current_form_index += 1
	global_position = new_player_position

	_apply_current_form()
	_rebuild_trump_tail()

	_debug_print_state("FORM LOST")


func _game_over() -> void:
	_is_game_over = true
	print("GAME OVER")

	get_tree().reload_current_scene()


func _apply_current_form() -> void:
	var form: Dictionary = trump_forms[current_form_index]

	var form_scale: float = float(form["scale"])
	var form_speed: float = float(form["speed"])

	move_speed = form_speed

	sprite.scale = Vector2.ONE * form_scale
	collision_shape.scale = Vector2.ONE * form_scale

	muzzle.position = Vector2(muzzle_distance * form_scale, 0.0)

	var c: Color = sprite.modulate
	c.a = 1.0
	sprite.modulate = c


func _get_current_scale() -> float:
	return float(trump_forms[current_form_index]["scale"])


func _is_invulnerable() -> bool:
	return _invulnerability_left > 0.0


func _set_invulnerable(duration: float) -> void:
	_invulnerability_left = maxf(_invulnerability_left, duration)
	_blink_timer = 0.0


func _update_invulnerability(delta: float) -> void:
	if _invulnerability_left <= 0.0:
		var normal_color: Color = sprite.modulate
		normal_color.a = 1.0
		sprite.modulate = normal_color
		return

	_invulnerability_left = maxf(_invulnerability_left - delta, 0.0)
	_blink_timer += delta

	var c: Color = sprite.modulate

	if int(_blink_timer * 16.0) % 2 == 0:
		c.a = 0.45
	else:
		c.a = 1.0

	sprite.modulate = c


func _update_dash_timers(delta: float) -> void:
	if _dash_time_left > 0.0:
		_dash_time_left = maxf(_dash_time_left - delta, 0.0)

	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)

	if _shoot_lock_left > 0.0:
		_shoot_lock_left = maxf(_shoot_lock_left - delta, 0.0)


func _try_start_dash() -> void:
	if _is_dashing():
		return

	if _dash_cooldown_left > 0.0:
		return

	var movement_direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Если игрок не двигается, рывок не выполняется.
	if movement_direction.length_squared() < 0.0001:
		return

	_dash_direction = movement_direction.normalized()
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown

	# Блокируем стрельбу на время рывка и ещё немного после него.
	_shoot_lock_left = dash_duration + after_dash_shoot_lock

	# Во время рывка Трамп неуязвим.
	_set_invulnerable(dash_duration)

	print("DASH")


func _is_dashing() -> bool:
	return _dash_time_left > 0.0


func _rebuild_trump_tail() -> void:
	_clear_trump_tail()
	_reset_tail_history()
	call_deferred("_create_trump_tail")


func _create_trump_tail() -> void:
	if get_parent() == null:
		return

	var half_size: float = ghost_base_size / 2.0
	var ghost_order: int = 0

	for form_index in range(current_form_index + 1, trump_forms.size()):
		var ghost := Polygon2D.new()

		ghost.name = "TrumpGhost_%s" % str(form_index)

		ghost.polygon = PackedVector2Array([
			Vector2(-half_size, -half_size),
			Vector2(half_size, -half_size),
			Vector2(half_size, half_size),
			Vector2(-half_size, half_size)
		])

		var ghost_scale: float = float(trump_forms[form_index]["scale"])
		ghost.scale = Vector2.ONE * ghost_scale
		ghost.global_position = global_position

		var alpha: float = 0.32 - float(ghost_order) * 0.05
		ghost.color = Color(0.05, 0.10, 0.07, alpha)

		ghost.z_index = 5

		get_parent().add_child(ghost)
		_ghosts.append(ghost)

		ghost_order += 1

	print("Trump tail created. Ghost count:", _ghosts.size())


func _clear_trump_tail() -> void:
	for ghost in _ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()

	_ghosts.clear()


func _reset_tail_history() -> void:
	_position_history.clear()

	var max_history_size: int = (trump_forms.size() + 1) * ghost_spacing_frames + 10

	for i in range(max_history_size):
		_position_history.append(global_position)


func _record_position() -> void:
	_position_history.push_front(global_position)

	var max_history_size: int = (trump_forms.size() + 1) * ghost_spacing_frames + 10

	while _position_history.size() > max_history_size:
		_position_history.pop_back()


func _update_trump_tail(delta: float) -> void:
	if _position_history.is_empty():
		return

	var lerp_weight: float = clampf(ghost_follow_speed * delta, 0.0, 1.0)

	for i in range(_ghosts.size()):
		var ghost: Polygon2D = _ghosts[i]

		if not is_instance_valid(ghost):
			continue

		var history_index: int = mini((i + 1) * ghost_spacing_frames, _position_history.size() - 1)
		var target_position: Vector2 = _position_history[history_index]

		ghost.global_position = ghost.global_position.lerp(target_position, lerp_weight)


func _handle_debug_input() -> void:
	if not OS.is_debug_build():
		return

	if not InputMap.has_action("debug_lose_form"):
		return

	if Input.is_action_just_pressed("debug_lose_form"):
		print("DEBUG: forced form loss")
		take_damage(999)


func _debug_print_state(reason: String) -> void:
	print("---", reason, "---")
	print("Current form index:", current_form_index)
	print("Current scale:", _get_current_scale())
	print("Current speed:", move_speed)
	print("Ghosts:", _ghosts.size())
	print("Invulnerability:", _invulnerability_left)
	print("Dash cooldown:", _dash_cooldown_left)
	print("Dash time left:", _dash_time_left)
	print("Shoot lock:", _shoot_lock_left)
