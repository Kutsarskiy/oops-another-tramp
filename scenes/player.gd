extends CharacterBody2D

const PLAYER_HURTBOX_LAYER_BIT: int = 4
const PLAYER_BODY_LAYER_BIT: int = 1
const WALL_COLLISION_LAYER_BIT: int = 0
const ENEMY_COLLISION_LAYER_BIT: int = 3
const PLAYER_BLOCKER_LAYER_BIT: int = 5
const PaperStateSpriteScript: Script = preload("res://scripts/visuals/paper_state_sprite.gd")

@export var move_speed: float = 200.0
@export var recoil_decay_speed: float = 1200.0
@export var paper_shadow_offset: Vector2 = Vector2(5.0, 6.0)
@export var paper_shadow_color: Color = Color(0.0, 0.0, 0.0, 0.32)
@export var mirror_collision_with_visual: bool = true
@export var reload_indicator_offset: Vector2 = Vector2(-22.0, -58.0)
@export var reload_indicator_size: Vector2 = Vector2(44.0, 5.0)
@export var reload_indicator_color: Color = Color.WHITE
@export var reload_indicator_line_width: float = 2.0
@export var reload_indicator_cap_height: float = 9.0

@export var paper_state_texture_paths: Dictionary = {
	&"idle": "res://assets/characters/player/donni/weapons/the_negotiator/idle_right.png",
	&"run": "res://assets/characters/player/donni/weapons/the_negotiator/run_right.png"
}
@export var weapon_paper_state_texture_paths: Dictionary = {
	&"the_negotiator": {
		&"idle": "res://assets/characters/player/donni/weapons/the_negotiator/idle_right.png",
		&"run": "res://assets/characters/player/donni/weapons/the_negotiator/run_right.png"
	},
	&"the_final_offer": {
		&"idle": "res://assets/characters/player/donni/weapons/the_final_offer/idle_right.png",
		&"run": "res://assets/characters/player/donni/weapons/the_final_offer/run_right.png"
	},
	&"the_second_amendment": {
		&"idle": "res://assets/characters/player/donni/weapons/the_second_amendment/idle_right.png",
		&"run": "res://assets/characters/player/donni/weapons/the_second_amendment/run_right.png"
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
@export var dash_duration: float = 0.25
@export var dash_cooldown: float = 0.5
@export var after_dash_invulnerability: float = 0.25
@export var after_dash_shoot_lock: float = 0.5
@export var dash_trail_spawn_interval: float = 0.035
@export var dash_trail_lifetime: float = 0.18
@export var dash_trail_start_color: Color = Color(1.0, 0.86, 0.42, 0.42)
@export var dash_trail_end_scale_multiplier: float = 0.92
@export var enemy_stun_on_hit_duration: float = 2.0
@export var damage_flash_duration: float = 0.25
@export var damage_flash_color: Color = Color(1.0, 0.0, 0.0, 0.28)
@export var damage_camera_shake_duration: float = 0.25
@export var damage_camera_shake_strength: float = 8.0
@export var damage_hit_stop_duration: float = 0.1
@export var boss_defeat_flash_duration: float = 1.0
@export var boss_defeat_flash_color: Color = Color(1.0, 1.0, 1.0, 0.82)
@export var boss_defeat_camera_shake_duration: float = 1.0
@export var boss_defeat_camera_shake_strength: float = 12.0
@export var boss_defeat_hit_stop_duration: float = 0.1
@export var boss_defeat_player_tint_duration: float = 0.0
@export var boss_defeat_player_tint: Color = Color(1.0, 0.2, 0.2, 1.0)

var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_trail_spawn_left: float = 0.0
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
var _reload_indicator: Node2D = null
var _reload_indicator_back_line: ColorRect = null
var _reload_indicator_left_cap: ColorRect = null
var _reload_indicator_right_cap: ColorRect = null
var _reload_indicator_fill: ColorRect = null
var _recoil_velocity: Vector2 = Vector2.ZERO
var _camera_movement_velocity: Vector2 = Vector2.ZERO
var _base_collision_shape_position: Vector2 = Vector2.ZERO
var _base_hurtbox_collision_shape_position: Vector2 = Vector2.ZERO
var _base_hurtbox_collision_layer: int = 0
var _base_hurtbox_collision_mask: int = 0
var _base_camera_offset: Vector2 = Vector2.ZERO
var _last_face_direction: Vector2 = Vector2.RIGHT
var _shot_cooldown_left: float = 0.0
var _shoot_state_left: float = 0.0
var _screen_shake_time_left: float = 0.0
var _screen_shake_strength_left: float = 0.0
var _damage_flash_rect: ColorRect = null
var _damage_flash_time_left: float = 0.0
var _damage_flash_duration: float = 0.0
var _boss_defeat_tint_left: float = 0.0
var _debug_hurtbox_disabled: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_configure_damage_flash()
	_configure_paper_shadow()
	_configure_reload_indicator()

	add_to_group("player")
	z_index = 10
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1 << PLAYER_BODY_LAYER_BIT
	collision_mask = (
		(1 << WALL_COLLISION_LAYER_BIT)
		| (1 << ENEMY_COLLISION_LAYER_BIT)
		| (1 << PLAYER_BLOCKER_LAYER_BIT)
	)

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
	_update_dash_trail(delta)
	_update_camera_shake(delta)
	_update_boss_defeat_tint(delta)
	_update_damage_flash(delta)
	_update_reload_indicator()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_BRACKETRIGHT or key_event.physical_keycode == KEY_BRACKETRIGHT or key_event.unicode == 1098:
		_set_debug_hurtbox_disabled(not _debug_hurtbox_disabled)


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
	_base_hurtbox_collision_layer = hurtbox.collision_layer
	_base_hurtbox_collision_mask = hurtbox.collision_mask


func _set_debug_hurtbox_disabled(is_disabled: bool) -> void:
	if hurtbox == null:
		return

	_debug_hurtbox_disabled = is_disabled

	hurtbox.set_deferred("monitoring", not is_disabled)
	hurtbox.set_deferred("monitorable", not is_disabled)
	hurtbox.set_deferred("collision_layer", 0 if is_disabled else _base_hurtbox_collision_layer)
	hurtbox.set_deferred("collision_mask", 0 if is_disabled else _base_hurtbox_collision_mask)

	if hurtbox_collision_shape != null:
		hurtbox_collision_shape.set_deferred("disabled", is_disabled)

	print("DEBUG: player hurtbox disabled" if is_disabled else "DEBUG: player hurtbox enabled")


func is_debug_hurtbox_disabled() -> bool:
	return _debug_hurtbox_disabled


func is_invulnerable() -> bool:
	return _is_invulnerable()


func apply_heavy_hit_knockback(source_position: Vector2, base_force: float) -> void:
	if base_force <= 0.0:
		return

	var knockback_direction := global_position - source_position

	if knockback_direction.length_squared() <= 0.001:
		knockback_direction = _last_face_direction

	if knockback_direction.length_squared() <= 0.001:
		knockback_direction = Vector2.RIGHT

	var form_scale := maxf(_get_current_scale(), 0.1)
	var scale_multiplier := clampf(1.0 / form_scale, 1.0, 1.85)
	_recoil_velocity += knockback_direction.normalized() * base_force * scale_multiplier


func _update_paper_visual(face_direction: Vector2, is_running: bool) -> void:
	var state := &"idle"

	if _shoot_state_left > 0.0 and _paper_visual.has_state(&"shoot"):
		state = &"shoot"
	elif is_running:
		state = &"run"

	_paper_visual.set_state(_get_paper_visual_state_for_current_weapon(state))

	var visual_face_direction := face_direction

	if _should_face_aim_direction():
		visual_face_direction = _get_aim_face_direction()

	if visual_face_direction.length_squared() > 0.0001:
		_last_face_direction = visual_face_direction.normalized()

	_paper_visual.face_direction(_last_face_direction)
	_sync_collision_mirroring()
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


func _configure_reload_indicator() -> void:
	_reload_indicator = Node2D.new()
	_reload_indicator.name = "ReloadIndicator"
	_reload_indicator.visible = false
	_reload_indicator.z_index = 50
	add_child(_reload_indicator)

	_reload_indicator_left_cap = ColorRect.new()
	_reload_indicator_left_cap.name = "LeftCap"
	_reload_indicator.add_child(_reload_indicator_left_cap)

	_reload_indicator_right_cap = ColorRect.new()
	_reload_indicator_right_cap.name = "RightCap"
	_reload_indicator.add_child(_reload_indicator_right_cap)

	_reload_indicator_back_line = ColorRect.new()
	_reload_indicator_back_line.name = "BackLine"
	_reload_indicator.add_child(_reload_indicator_back_line)

	_reload_indicator_fill = ColorRect.new()
	_reload_indicator_fill.name = "Fill"
	_reload_indicator.add_child(_reload_indicator_fill)

	_update_reload_indicator()


func _update_reload_indicator() -> void:
	if _reload_indicator == null or weapon_controller == null:
		return

	var is_reloading := false
	var reload_progress := 0.0

	if weapon_controller.has_method("is_reloading"):
		is_reloading = bool(weapon_controller.call("is_reloading"))

	if is_reloading and weapon_controller.has_method("get_reload_progress"):
		reload_progress = float(weapon_controller.call("get_reload_progress"))

	_reload_indicator.visible = is_reloading
	_reload_indicator.position = reload_indicator_offset

	var line_width := maxf(reload_indicator_line_width, 1.0)
	var cap_height := maxf(reload_indicator_cap_height, line_width)
	var line_y := (cap_height - line_width) * 0.5
	var inner_width := maxf(reload_indicator_size.x - line_width * 2.0, 0.0)

	for rect in [_reload_indicator_left_cap, _reload_indicator_right_cap, _reload_indicator_back_line, _reload_indicator_fill]:
		rect.color = reload_indicator_color

	_reload_indicator_left_cap.position = Vector2.ZERO
	_reload_indicator_left_cap.size = Vector2(line_width, cap_height)

	_reload_indicator_right_cap.position = Vector2(reload_indicator_size.x - line_width, 0.0)
	_reload_indicator_right_cap.size = Vector2(line_width, cap_height)

	_reload_indicator_back_line.position = Vector2(line_width, line_y)
	_reload_indicator_back_line.size = Vector2(inner_width, line_width)

	_reload_indicator_fill.position = Vector2(line_width, line_y)
	_reload_indicator_fill.size = Vector2(
		line_width,
		cap_height
	)
	_reload_indicator_fill.position.x = line_width + maxf(inner_width - line_width, 0.0) * clampf(reload_progress, 0.0, 1.0)
	_reload_indicator_fill.position.y = 0.0


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


func _should_face_aim_direction() -> bool:
	if _shoot_state_left > 0.0:
		return true

	if InputMap.has_action("shoot") and Input.is_action_pressed("shoot"):
		return true

	return _get_current_weapon_id() != &""


func _get_aim_face_direction() -> Vector2:
	var aim_direction := get_global_mouse_position() - global_position

	if aim_direction.length_squared() < 0.0001:
		return _last_face_direction

	return aim_direction.normalized()


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
	_play_damage_feedback()
	_clear_enemy_bullets()
	_stun_all_enemies()
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

	if hurtbox_collision_shape != null:
		hurtbox_collision_shape.scale = Vector2.ONE * form_scale

	_sync_collision_mirroring()

	if muzzle != null:
		muzzle.position = Vector2(muzzle_distance * form_scale, 0.0)

	var c: Color = sprite.modulate
	c.a = 1.0
	sprite.modulate = c
	_apply_player_modulate()


func _get_current_scale() -> float:
	return float(trump_forms[current_form_index]["scale"])


func _sync_collision_mirroring() -> void:
	var form_scale := _get_current_scale()
	var mirror_sign := -1.0 if mirror_collision_with_visual and sprite != null and sprite.flip_h else 1.0

	if collision_shape != null:
		collision_shape.position = Vector2(
			_base_collision_shape_position.x * mirror_sign,
			_base_collision_shape_position.y
		) * form_scale

	if hurtbox_collision_shape != null:
		hurtbox_collision_shape.position = Vector2(
			_base_hurtbox_collision_shape_position.x * mirror_sign,
			_base_hurtbox_collision_shape_position.y
		) * form_scale


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
		_apply_player_modulate()
		return

	_invulnerability_left = maxf(_invulnerability_left - delta, 0.0)
	_blink_timer += delta
	_apply_player_modulate()


func _update_dash_timers(delta: float) -> void:
	if _dash_time_left > 0.0:
		_dash_time_left = maxf(_dash_time_left - delta, 0.0)

	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)

	if _shoot_lock_left > 0.0:
		_shoot_lock_left = maxf(_shoot_lock_left - delta, 0.0)


func _update_dash_trail(delta: float) -> void:
	if not _is_dashing():
		_dash_trail_spawn_left = 0.0
		return

	_dash_trail_spawn_left -= delta

	if _dash_trail_spawn_left > 0.0:
		return

	_spawn_dash_trail_afterimage()
	_dash_trail_spawn_left = dash_trail_spawn_interval


func _spawn_dash_trail_afterimage() -> void:
	if sprite == null or sprite.texture == null:
		return

	var parent_node := get_parent()

	if parent_node == null:
		return

	var afterimage := Sprite2D.new()
	afterimage.name = "DashTrailAfterimage"
	afterimage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	afterimage.texture = sprite.texture
	afterimage.centered = sprite.centered
	afterimage.offset = sprite.offset
	afterimage.flip_h = sprite.flip_h
	afterimage.flip_v = sprite.flip_v
	afterimage.z_index = z_index - 1
	afterimage.modulate = dash_trail_start_color

	parent_node.add_child(afterimage)
	afterimage.global_position = sprite.global_position
	afterimage.global_rotation = sprite.global_rotation
	afterimage.global_scale = sprite.global_scale

	var tween := afterimage.create_tween()
	tween.set_parallel(true)
	tween.tween_property(afterimage, "modulate:a", 0.0, dash_trail_lifetime)
	tween.tween_property(afterimage, "scale", afterimage.scale * dash_trail_end_scale_multiplier, dash_trail_lifetime)
	tween.chain().tween_callback(afterimage.queue_free)


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
	_dash_trail_spawn_left = 0.0
	_shoot_lock_left = dash_duration + after_dash_shoot_lock
	_set_invulnerable(dash_duration + after_dash_invulnerability)

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


func _clear_enemy_bullets() -> void:
	for bullet in get_tree().get_nodes_in_group("enemy_bullet"):
		if is_instance_valid(bullet):
			if bullet.has_method("evaporate"):
				bullet.call("evaporate")
			else:
				bullet.queue_free()


func _stun_all_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self:
			continue

		if enemy.has_method("apply_global_stun"):
			enemy.call("apply_global_stun", enemy_stun_on_hit_duration)


func _play_damage_feedback() -> void:
	_play_hit_stop(damage_hit_stop_duration)
	_play_screen_flash(damage_flash_color, damage_flash_duration)

	_screen_shake_time_left = maxf(_screen_shake_time_left, damage_camera_shake_duration)
	_screen_shake_strength_left = maxf(_screen_shake_strength_left, damage_camera_shake_strength)


func play_boss_defeat_feedback() -> void:
	_play_hit_stop(boss_defeat_hit_stop_duration)
	_play_screen_flash(boss_defeat_flash_color, boss_defeat_flash_duration)
	_screen_shake_time_left = maxf(_screen_shake_time_left, boss_defeat_camera_shake_duration)
	_screen_shake_strength_left = maxf(_screen_shake_strength_left, boss_defeat_camera_shake_strength)
	_boss_defeat_tint_left = boss_defeat_player_tint_duration
	_apply_player_modulate()


func play_phase_transition_feedback(duration: float = 1.0, strength: float = 9.0) -> void:
	_screen_shake_time_left = maxf(_screen_shake_time_left, duration)
	_screen_shake_strength_left = maxf(_screen_shake_strength_left, strength)


func _play_screen_flash(flash_color: Color, duration: float) -> void:
	_damage_flash_duration = maxf(duration, 0.01)
	_damage_flash_time_left = _damage_flash_duration

	if _damage_flash_rect != null:
		_damage_flash_rect.visible = true
		_damage_flash_rect.color = flash_color


func _play_hit_stop(duration: float) -> void:
	if has_node("/root/HitStop"):
		get_node("/root/HitStop").call("trigger", duration)


func _configure_damage_flash() -> void:
	var game_root := get_tree().current_scene

	if game_root == null:
		return

	var ui_layer := game_root.get_node_or_null("UI")

	if ui_layer == null:
		return

	_damage_flash_rect = ui_layer.get_node_or_null("DamageFlash") as ColorRect

	if _damage_flash_rect == null:
		_damage_flash_rect = ColorRect.new()
		_damage_flash_rect.name = "DamageFlash"
		ui_layer.add_child(_damage_flash_rect)

	_damage_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash_rect.offset_left = 0.0
	_damage_flash_rect.offset_top = 0.0
	_damage_flash_rect.offset_right = 0.0
	_damage_flash_rect.offset_bottom = 0.0
	_damage_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_flash_rect.visible = false
	_damage_flash_rect.color = Color.TRANSPARENT


func _update_damage_flash(delta: float) -> void:
	if _damage_flash_rect == null:
		return

	if _damage_flash_time_left <= 0.0:
		_damage_flash_rect.visible = false
		_damage_flash_rect.color = Color.TRANSPARENT
		return

	_damage_flash_time_left = maxf(_damage_flash_time_left - delta, 0.0)
	var flash_t := _damage_flash_time_left / _damage_flash_duration
	var flash_color := _damage_flash_rect.color
	flash_color.a *= flash_t
	_damage_flash_rect.color = flash_color

	if _damage_flash_time_left <= 0.0:
		_damage_flash_rect.visible = false
		_damage_flash_rect.color = Color.TRANSPARENT


func _update_boss_defeat_tint(delta: float) -> void:
	if _boss_defeat_tint_left <= 0.0:
		return

	_boss_defeat_tint_left = maxf(_boss_defeat_tint_left - delta, 0.0)
	_apply_player_modulate()


func _apply_player_modulate() -> void:
	if sprite == null:
		return

	var modulate_color := Color.WHITE

	if _boss_defeat_tint_left > 0.0:
		modulate_color = boss_defeat_player_tint

	if _is_invulnerable() and int(_blink_timer * 16.0) % 2 == 0:
		modulate_color.a = 0.45

	sprite.modulate = modulate_color
