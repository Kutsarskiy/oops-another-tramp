extends CharacterBody2D

const PLAYER_HURTBOX_LAYER_BIT: int = 4
const PLAYER_BODY_LAYER_BIT: int = 1
const WALL_COLLISION_LAYER_BIT: int = 0
const ENEMY_COLLISION_LAYER_BIT: int = 3
const PaperStateSpriteScript: Script = preload("res://scripts/visuals/paper_state_sprite.gd")

@export var move_speed: float = 200.0
@export var recoil_decay_speed: float = 1200.0
@export var paper_shadow_offset: Vector2 = Vector2(5.0, 6.0)
@export var paper_shadow_color: Color = Color(0.0, 0.0, 0.0, 0.32)

@export var paper_state_texture_paths: Dictionary = {
	&"idle": "res://assets/characters/player/donni/donni_right_idle.png",
	&"run": "res://assets/characters/player/donni/donni_right_run.png"
}
@export var weapon_paper_state_texture_paths: Dictionary = {
	&"the_negotiator": {
		&"idle": "res://assets/characters/player/donni/weapons/the_negotiator/idle_right.png",
		&"run": "res://assets/characters/player/donni/weapons/the_negotiator/run_right.png"
	}
}

var trump_forms: Array[Dictionary] = [
	{"scale": 1.0, "speed": 200.0, "recoil_multiplier": 0.6},
	{"scale": 0.9, "speed": 220.0, "recoil_multiplier": 0.8},
	{"scale": 0.8, "speed": 240.0, "recoil_multiplier": 1.0},
	{"scale": 0.7, "speed": 260.0, "recoil_multiplier": 1.3},
	{"scale": 0.6, "speed": 290.0, "recoil_multiplier": 1.7}
]

var current_form_index: int = 0

@export var after_hit_invulnerability: float = 0.8

var _invulnerability_left: float = 0.0
var _blink_timer: float = 0.0
var _is_game_over: bool = false

@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.5
@export var after_dash_shoot_lock: float = 0.5

var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _shoot_lock_left: float = 0.0

@export var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
@export var fire_rate: float = 4.0
@export var bullet_damage: int = 1
@export var bullet_speed: float = 680.0
@export var bullet_lifetime: float = 1.45
@export var bullet_radius: float = 9.0
@export var bullet_color: Color = Color(1.0, 0.78, 0.20)
@export var muzzle_distance: float = 36.0
@export var recoil_force: float = 120.0
@export var shoot_state_duration: float = 0.08
@export var camera_shake_min_duration: float = 0.045
@export var camera_shake_max_duration: float = 0.10
@export var camera_shake_decay: float = 30.0
@export var camera_shake_min_strength: float = 1.0
@export var camera_shake_max_strength: float = 5.2
@export var camera_shake_recoil_strength_scale: float = 0.004
@export var camera_shake_strength_by_form: PackedFloat32Array = [
	2.4,
	3.0,
	3.35,
	4.15,
	5.2
]
@export var camera_shake_duration_by_form: PackedFloat32Array = [
	0.065,
	0.075,
	0.085,
	0.095,
	0.10
]

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
@onready var hurtbox_collision_shape: CollisionShape2D = get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D
@onready var muzzle: Marker2D = $Muzzle
@onready var weapon_controller: Node = get_node_or_null("WeaponController")
@onready var camera: Camera2D = _find_camera()

var _paper_visual = PaperStateSpriteScript.new()
var _paper_shadow_sprite: Sprite2D = null
var _recoil_velocity: Vector2 = Vector2.ZERO
var _camera_movement_velocity: Vector2 = Vector2.ZERO
var _base_collision_shape_position: Vector2 = Vector2.ZERO
var _base_hurtbox_collision_shape_position: Vector2 = Vector2.ZERO
var _base_camera_offset: Vector2 = Vector2.ZERO
var _last_face_direction: Vector2 = Vector2.RIGHT
var _shot_cooldown_left: float = 0.0
var _shoot_state_left: float = 0.0
var _screen_shake_time_left: float = 0.0
var _screen_shake_strength_left: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_configure_paper_shadow()

	add_to_group("player")
	z_index = 10
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1 << PLAYER_BODY_LAYER_BIT
	collision_mask = (1 << WALL_COLLISION_LAYER_BIT) | (1 << ENEMY_COLLISION_LAYER_BIT)

	_store_base_node_positions()
	_configure_hurtbox()
	_paper_visual.setup(sprite, _build_paper_state_texture_paths())
	_restore_run_snapshot()
	_apply_current_form()
	_update_paper_visual(Vector2.ZERO, false)

	if weapon_controller != null:
		weapon_controller.initialize(self)
		weapon_controller.on_trump_form_changed(_get_current_scale())
	else:
		push_warning("Player has no WeaponController child. Shooting will not work.")

	_debug_print_state("START")


func _physics_process(delta: float) -> void:
	if _is_game_over:
		return

	_handle_debug_input()
	_update_invulnerability(delta)
	_update_dash_timers(delta)
	_update_shoot_timers(delta)

	var movement_direction := _get_movement_input_direction()
	var visual_direction := movement_direction
	var is_running := movement_direction.length_squared() > 0.0001

	if InputMap.has_action("dash") and Input.is_action_just_pressed("dash"):
		_try_start_dash(movement_direction)

	if _is_dashing():
		velocity = _dash_direction * dash_speed
		_camera_movement_velocity = velocity
		visual_direction = _dash_direction
		is_running = true
	else:
		var movement_velocity := movement_direction * move_speed
		_camera_movement_velocity = movement_velocity
		velocity = movement_velocity + _recoil_velocity

	move_and_slide()

	_update_recoil(delta)
	_update_paper_visual(visual_direction, is_running)
	_update_camera_shake(delta)


func _get_movement_input_direction() -> Vector2:
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")


func get_camera_movement_velocity() -> Vector2:
	return _camera_movement_velocity


func _find_camera() -> Camera2D:
	var child_camera := get_node_or_null("Camera2D") as Camera2D

	if child_camera != null:
		return child_camera

	return get_viewport().get_camera_2d()


func _store_base_node_positions() -> void:
	if collision_shape != null:
		_base_collision_shape_position = collision_shape.position

	if hurtbox_collision_shape != null:
		_base_hurtbox_collision_shape_position = hurtbox_collision_shape.position

	if camera != null:
		_base_camera_offset = camera.offset


func _configure_hurtbox() -> void:
	if hurtbox == null:
		return

	hurtbox.add_to_group("player")
	hurtbox.add_to_group("player_hurtbox")
	hurtbox.set_meta("damage_owner", self)
	hurtbox.set_deferred("monitoring", true)
	hurtbox.set_deferred("monitorable", true)
	hurtbox.collision_layer = 1 << PLAYER_HURTBOX_LAYER_BIT
	hurtbox.collision_mask = 0


func _update_paper_visual(face_direction: Vector2, is_running: bool) -> void:
	var state := &"idle"

	if _shoot_state_left > 0.0 and _paper_visual.has_state(&"shoot"):
		state = &"shoot"
	elif is_running:
		state = &"run"

	_paper_visual.set_state(_get_paper_visual_state_for_current_weapon(state))

	if face_direction.length_squared() > 0.0001:
		_last_face_direction = face_direction.normalized()

	_paper_visual.face_direction(_last_face_direction)
	_update_paper_shadow()


func _configure_paper_shadow() -> void:
	_paper_shadow_sprite = get_node_or_null("PaperShadow") as Sprite2D

	if _paper_shadow_sprite == null:
		_paper_shadow_sprite = Sprite2D.new()
		_paper_shadow_sprite.name = "PaperShadow"
		add_child(_paper_shadow_sprite)
		move_child(_paper_shadow_sprite, 0)

	_paper_shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_paper_shadow_sprite.centered = sprite.centered
	_paper_shadow_sprite.offset = sprite.offset
	_paper_shadow_sprite.position = sprite.position + paper_shadow_offset
	_paper_shadow_sprite.modulate = paper_shadow_color
	_paper_shadow_sprite.z_index = sprite.z_index - 1
	_update_paper_shadow()


func _update_paper_shadow() -> void:
	if _paper_shadow_sprite == null or sprite == null:
		return

	_paper_shadow_sprite.texture = sprite.texture
	_paper_shadow_sprite.flip_h = sprite.flip_h
	_paper_shadow_sprite.flip_v = sprite.flip_v
	_paper_shadow_sprite.scale = sprite.scale
	_paper_shadow_sprite.position = sprite.position + paper_shadow_offset


func _build_paper_state_texture_paths() -> Dictionary:
	var texture_paths := paper_state_texture_paths.duplicate()

	for weapon_id in weapon_paper_state_texture_paths.keys():
		var weapon_states = weapon_paper_state_texture_paths[weapon_id]

		if not weapon_states is Dictionary:
			continue

		for state in weapon_states.keys():
			var paper_state := _get_weapon_paper_state(StringName(str(weapon_id)), StringName(str(state)))
			texture_paths[paper_state] = weapon_states[state]

	return texture_paths


func _get_paper_visual_state_for_current_weapon(base_state: StringName) -> StringName:
	var weapon_id := _get_current_weapon_id()

	if weapon_id == &"":
		return base_state

	var weapon_state := _get_weapon_paper_state(weapon_id, base_state)

	if _paper_visual.has_state(weapon_state):
		return weapon_state

	return base_state


func _get_weapon_paper_state(weapon_id: StringName, base_state: StringName) -> StringName:
	return StringName("%s:%s" % [String(weapon_id), String(base_state)])


func _get_current_weapon_id() -> StringName:
	if weapon_controller == null or not weapon_controller.has_method("get_current_weapon_id"):
		return &""

	return weapon_controller.call("get_current_weapon_id")


func take_damage(_amount: int) -> void:
	if _is_game_over:
		return

	if _is_invulnerable():
		return

	_set_invulnerable(after_hit_invulnerability)
	_lose_current_form()


func _lose_current_form() -> void:
	print("Trump form lost:", current_form_index + 1)

	if current_form_index + 1 >= trump_forms.size():
		_game_over()
		return

	current_form_index += 1
	_apply_current_form()

	if weapon_controller != null:
		weapon_controller.on_trump_form_changed(_get_current_scale())

	_debug_print_state("FORM LOST")


func _game_over() -> void:
	_is_game_over = true
	print("GAME OVER")
	call_deferred("_reload_current_scene")


func _reload_current_scene() -> void:
	get_tree().reload_current_scene()


func _apply_current_form() -> void:
	var form: Dictionary = trump_forms[current_form_index]
	var form_scale: float = float(form["scale"])
	var form_speed: float = float(form["speed"])

	move_speed = form_speed
	sprite.scale = Vector2.ONE * form_scale

	if collision_shape != null:
		collision_shape.scale = Vector2.ONE * form_scale
		collision_shape.position = _base_collision_shape_position * form_scale

	if hurtbox_collision_shape != null:
		hurtbox_collision_shape.scale = Vector2.ONE * form_scale
		hurtbox_collision_shape.position = _base_hurtbox_collision_shape_position * form_scale

	if muzzle != null:
		muzzle.position = Vector2(muzzle_distance * form_scale, 0.0)

	var c: Color = sprite.modulate
	c.a = 1.0
	sprite.modulate = c


func _get_current_scale() -> float:
	return float(trump_forms[current_form_index]["scale"])


func get_current_life_count() -> int:
	return clampi(trump_forms.size() - current_form_index, 0, trump_forms.size())


func get_max_life_count() -> int:
	return trump_forms.size()


func get_current_trump_scale() -> float:
	return _get_current_scale()


func create_run_snapshot() -> Dictionary:
	var weapon_snapshot: Dictionary = {}

	if weapon_controller != null and weapon_controller.has_method("create_run_snapshot"):
		weapon_snapshot = weapon_controller.call("create_run_snapshot")

	return {
		"current_form_index": current_form_index,
		"weapon_controller": weapon_snapshot
	}


func _restore_run_snapshot() -> void:
	if not RunManager.has_player_snapshot():
		return

	current_form_index = clampi(
		int(RunManager.player_snapshot.get("current_form_index", current_form_index)),
		0,
		trump_forms.size() - 1
	)


func _get_current_recoil_multiplier() -> float:
	var form: Dictionary = trump_forms[current_form_index]

	if not form.has("recoil_multiplier"):
		return 1.0

	return float(form["recoil_multiplier"])


func can_weapon_fire() -> bool:
	return _can_shoot()


func can_weapon_reload() -> bool:
	return not _is_game_over and not _is_dashing()


func _handle_shoot_input() -> void:
	if not InputMap.has_action("shoot"):
		return

	if Input.is_action_pressed("shoot"):
		_try_shoot()


func _try_shoot() -> void:
	if not _can_shoot():
		return

	var shoot_direction := _get_shoot_direction()
	var bullet := bullet_scene.instantiate() as Area2D

	if bullet == null:
		return

	if bullet.has_method("setup_bullet"):
		bullet.call("setup_bullet", false)

	if bullet.has_method("configure_projectile"):
		bullet.call(
			"configure_projectile",
			bullet_damage,
			bullet_speed,
			bullet_lifetime,
			bullet_radius,
			bullet_color
		)

	bullet.global_position = get_weapon_muzzle_global_position(shoot_direction)
	bullet.set("direction", shoot_direction)
	get_bullet_spawn_parent().add_child(bullet)

	apply_weapon_recoil(shoot_direction, recoil_force)
	on_weapon_fired(&"paper_shot")

	_shot_cooldown_left = 1.0 / maxf(fire_rate, 0.01)


func _can_shoot() -> bool:
	if _is_game_over:
		return false

	if _is_dashing():
		return false

	if _shoot_lock_left > 0.0:
		return false

	return _shot_cooldown_left <= 0.0


func _get_shoot_direction() -> Vector2:
	var shoot_direction := get_global_mouse_position() - global_position

	if shoot_direction.length_squared() < 0.0001:
		return _last_face_direction

	return shoot_direction.normalized()


func get_weapon_muzzle_global_position(shoot_direction: Vector2) -> Vector2:
	var direction := shoot_direction

	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT

	return global_position + direction.normalized() * muzzle_distance * _get_current_scale()


func get_bullet_spawn_parent() -> Node:
	var parent_node := get_parent()

	if parent_node != null:
		return parent_node

	return self


func apply_weapon_recoil(shoot_direction: Vector2, recoil: float) -> void:
	if recoil <= 0.0:
		return

	var direction := shoot_direction

	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT

	_recoil_velocity -= direction.normalized() * recoil * _get_current_recoil_multiplier()


func on_weapon_fired(_weapon_id: StringName, weapon_recoil_force: float = 0.0) -> void:
	_shoot_state_left = shoot_state_duration

	var form_t := _get_current_form_t()
	var shake_index := _get_camera_shake_form_index()
	var recoil_bonus := weapon_recoil_force * camera_shake_recoil_strength_scale
	var shake_strength := _get_camera_shake_strength(shake_index, form_t) + recoil_bonus
	var shake_duration := _get_camera_shake_duration(shake_index, form_t)

	_screen_shake_time_left = maxf(_screen_shake_time_left, shake_duration)
	_screen_shake_strength_left = maxf(_screen_shake_strength_left, shake_strength)

	var aim_direction := _get_shoot_direction()

	if aim_direction.length_squared() > 0.0001:
		_last_face_direction = aim_direction.normalized()


func _get_current_form_t() -> float:
	if trump_forms.size() <= 1:
		return 0.0

	return float(current_form_index) / float(trump_forms.size() - 1)


func _get_camera_shake_form_index() -> int:
	var max_size := mini(camera_shake_strength_by_form.size(), camera_shake_duration_by_form.size())

	if max_size <= 0:
		return -1

	return clampi(current_form_index, 0, max_size - 1)


func _get_camera_shake_strength(shake_index: int, form_t: float) -> float:
	if shake_index >= 0:
		return camera_shake_strength_by_form[shake_index]

	return lerpf(camera_shake_min_strength, camera_shake_max_strength, form_t)


func _get_camera_shake_duration(shake_index: int, form_t: float) -> float:
	if shake_index >= 0:
		return camera_shake_duration_by_form[shake_index]

	return lerpf(camera_shake_min_duration, camera_shake_max_duration, form_t)


func _update_recoil(delta: float) -> void:
	if _recoil_velocity.length_squared() <= 0.0001:
		_recoil_velocity = Vector2.ZERO
		return

	_recoil_velocity = _recoil_velocity.move_toward(Vector2.ZERO, recoil_decay_speed * delta)


func _update_shoot_timers(delta: float) -> void:
	if _shot_cooldown_left > 0.0:
		_shot_cooldown_left = maxf(_shot_cooldown_left - delta, 0.0)

	if _shoot_state_left > 0.0:
		_shoot_state_left = maxf(_shoot_state_left - delta, 0.0)


func _update_camera_shake(delta: float) -> void:
	if camera == null:
		return

	if _screen_shake_time_left <= 0.0 and _screen_shake_strength_left <= 0.01:
		_set_camera_shake_offset(Vector2.ZERO)
		_screen_shake_strength_left = 0.0
		return

	var shake_offset := Vector2(
		randf_range(-_screen_shake_strength_left, _screen_shake_strength_left),
		randf_range(-_screen_shake_strength_left, _screen_shake_strength_left)
	)

	_set_camera_shake_offset(shake_offset)

	_screen_shake_time_left = maxf(_screen_shake_time_left - delta, 0.0)
	_screen_shake_strength_left = maxf(_screen_shake_strength_left - camera_shake_decay * delta, 0.0)


func _set_camera_shake_offset(shake_offset: Vector2) -> void:
	if camera == null:
		return

	if camera.has_method("set_shake_offset"):
		camera.call("set_shake_offset", shake_offset)
	else:
		camera.offset = _base_camera_offset + shake_offset


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


func _try_start_dash(movement_direction: Vector2) -> void:
	if _is_dashing():
		return

	if _dash_cooldown_left > 0.0:
		return

	if movement_direction.length_squared() < 0.0001:
		return

	_dash_direction = movement_direction.normalized()
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown
	_shoot_lock_left = dash_duration + after_dash_shoot_lock
	_set_invulnerable(dash_duration)

	print("DASH")


func _is_dashing() -> bool:
	return _dash_time_left > 0.0


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
	print("Current recoil multiplier:", _get_current_recoil_multiplier())
	print("Invulnerability:", _invulnerability_left)
	print("Dash cooldown:", _dash_cooldown_left)
	print("Dash time left:", _dash_time_left)
	print("Shoot lock:", _shoot_lock_left)

	if weapon_controller != null:
		print("Weapon:", weapon_controller.get_current_weapon_name())
		print("Ammo:", weapon_controller.get_current_ammo_text())
