extends CharacterBody2D

const ENEMY_LAYER_BIT: int = 3
const PLAYER_BODY_LAYER_BIT: int = 1
const WALL_COLLISION_LAYER_BIT: int = 0

@export var move_speed: float = 65.0
@export var fire_rate: float = 0.5
@export var start_shoot_delay: float = 1.5
@export var keep_distance: float = 420.0
@export var max_hp: int = 3
@export var global_stun_damage_multiplier: float = 2.0
@export var global_stun_tint: Color = Color(1.0, 0.58, 0.58, 1.0)
@export var spawn_intro_enabled: bool = true
@export var spawn_intro_duration: float = 0.55
@export var spawn_intro_fall_height: float = 210.0
@export var spawn_intro_start_rotation_degrees: float = -12.0
@export var spawn_intro_shadow_offset: Vector2 = Vector2(0.0, 48.0)
@export var spawn_intro_shadow_color: Color = Color(0.0, 0.0, 0.0, 0.28)
@export var mirror_collision_with_visual: bool = true

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
@onready var hurtbox_collision_shape: CollisionShape2D = get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D

var hp: int
var _shoot_cd: float = 0.0
var _player: Node2D = null
var BulletScene: PackedScene = preload("res://scenes/bullet.tscn")
var _global_stun_left: float = 0.0
var _base_stun_modulate: Color = Color.WHITE
var _spawn_intro_active: bool = false
var _spawn_intro_shadow: Sprite2D = null
var _base_collision_layer: int = 0
var _base_collision_mask: int = 0
var _base_hurtbox_monitoring: bool = false
var _base_hurtbox_monitorable: bool = false
var _base_collision_shape_position: Vector2 = Vector2.ZERO
var _base_hurtbox_collision_shape_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	hp = max_hp
	add_to_group("enemy")

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1 << ENEMY_LAYER_BIT
	collision_mask = (1 << WALL_COLLISION_LAYER_BIT) | (1 << PLAYER_BODY_LAYER_BIT)
	_base_collision_layer = collision_layer
	_base_collision_mask = collision_mask

	_configure_hurtbox()
	if collision_shape != null:
		_base_collision_shape_position = collision_shape.position
	if hurtbox_collision_shape != null:
		_base_hurtbox_collision_shape_position = hurtbox_collision_shape.position
	_ensure_temp_texture()
	if sprite != null:
		_base_stun_modulate = sprite.modulate

	_player = get_tree().get_first_node_in_group("player") as Node2D
	_shoot_cd = start_shoot_delay

	if spawn_intro_enabled:
		call_deferred("play_spawn_intro")


func _physics_process(delta: float) -> void:
	if _spawn_intro_active:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _update_global_stun(delta):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player := _player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player.normalized()

	if sprite != null and absf(direction.x) > 0.001:
		sprite.flip_h = direction.x < 0.0
		_sync_collision_mirroring()

	var move_direction := Vector2.ZERO

	if distance > keep_distance:
		move_direction = direction

	velocity = move_direction * move_speed
	move_and_slide()

	_shoot_cd = maxf(_shoot_cd - delta, 0.0)

	if _shoot_cd <= 0.0:
		_shoot_cd = 1.0 / maxf(fire_rate, 0.01)
		_shoot(direction)


func _shoot(direction: Vector2) -> void:
	var bullet := BulletScene.instantiate() as Area2D

	if bullet == null:
		return

	if bullet.has_method("setup_bullet"):
		bullet.call("setup_bullet", true)

	bullet.set("team", &"enemy")
	bullet.set("direction", direction)
	bullet.global_position = global_position

	get_parent().add_child(bullet)


func _sync_collision_mirroring() -> void:
	var mirror_sign := -1.0 if mirror_collision_with_visual and sprite != null and sprite.flip_h else 1.0

	if collision_shape != null:
		collision_shape.position = Vector2(_base_collision_shape_position.x * mirror_sign, _base_collision_shape_position.y)

	if hurtbox_collision_shape != null:
		hurtbox_collision_shape.position = Vector2(
			_base_hurtbox_collision_shape_position.x * mirror_sign,
			_base_hurtbox_collision_shape_position.y
		)


func take_damage(amount: int) -> void:
	if _spawn_intro_active:
		return

	hp -= ceili(_get_global_stun_modified_damage(amount))

	if hp <= 0:
		queue_free()


func _configure_hurtbox() -> void:
	if hurtbox == null:
		return

	hurtbox.add_to_group("enemy")
	hurtbox.add_to_group("enemy_hurtbox")
	hurtbox.set_meta("damage_owner", self)
	hurtbox.set_deferred("monitoring", true)
	hurtbox.set_deferred("monitorable", true)
	hurtbox.collision_layer = 1 << ENEMY_LAYER_BIT
	hurtbox.collision_mask = 0
	_base_hurtbox_monitoring = true
	_base_hurtbox_monitorable = true


func _ensure_temp_texture() -> void:
	if sprite == null:
		return

	if sprite.texture != null:
		return

	var image := Image.create(72, 88, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var center := Vector2(36.0, 44.0)
	var body_radius := Vector2(25.0, 34.0)

	for y in range(88):
		for x in range(72):
			var offset := Vector2(float(x), float(y)) - center
			var body_value := pow(offset.x / body_radius.x, 2.0) + pow(offset.y / body_radius.y, 2.0)

			if body_value <= 1.0:
				image.set_pixel(x, y, Color(0.95, 0.32, 0.34, 1.0))

	image.fill_rect(Rect2i(18, 20, 36, 12), Color(0.28, 0.08, 0.10, 1.0))
	image.fill_rect(Rect2i(24, 58, 24, 8), Color(0.28, 0.08, 0.10, 1.0))

	sprite.texture = ImageTexture.create_from_image(image)


func play_spawn_intro() -> void:
	if sprite == null:
		return

	_spawn_intro_active = true
	_disable_spawn_intro_collision()
	_ensure_spawn_intro_shadow()

	var base_position := sprite.position
	var base_scale := sprite.scale
	var base_modulate := _base_stun_modulate
	var duration := maxf(spawn_intro_duration, 0.01)

	sprite.position = base_position + Vector2.UP * spawn_intro_fall_height
	sprite.rotation_degrees = spawn_intro_start_rotation_degrees
	sprite.scale = base_scale * 0.84
	sprite.modulate = Color(base_modulate.r, base_modulate.g, base_modulate.b, 0.0)

	if _spawn_intro_shadow != null:
		_spawn_intro_shadow.visible = true
		_spawn_intro_shadow.texture = sprite.texture
		_spawn_intro_shadow.flip_h = sprite.flip_h
		_spawn_intro_shadow.flip_v = sprite.flip_v
		_spawn_intro_shadow.position = base_position + spawn_intro_shadow_offset
		_spawn_intro_shadow.scale = base_scale * 0.48
		_spawn_intro_shadow.modulate = Color(
			spawn_intro_shadow_color.r,
			spawn_intro_shadow_color.g,
			spawn_intro_shadow_color.b,
			0.0
		)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", base_position, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "rotation_degrees", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", base_modulate.a, duration * 0.35)

	if _spawn_intro_shadow != null:
		tween.tween_property(_spawn_intro_shadow, "scale", base_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_spawn_intro_shadow, "modulate:a", spawn_intro_shadow_color.a, duration * 0.45)

	tween.chain()
	tween.tween_property(sprite, "scale", base_scale * Vector2(1.12, 0.88), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", base_scale, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_spawn_intro)


func _ensure_spawn_intro_shadow() -> void:
	if _spawn_intro_shadow != null:
		return

	_spawn_intro_shadow = Sprite2D.new()
	_spawn_intro_shadow.name = "SpawnIntroShadow"
	_spawn_intro_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spawn_intro_shadow.centered = sprite.centered
	_spawn_intro_shadow.offset = sprite.offset
	_spawn_intro_shadow.z_index = sprite.z_index - 1
	_spawn_intro_shadow.visible = false
	add_child(_spawn_intro_shadow)


func _disable_spawn_intro_collision() -> void:
	collision_layer = 0
	collision_mask = 0

	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	if hurtbox != null:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)

	if hurtbox_collision_shape != null:
		hurtbox_collision_shape.set_deferred("disabled", true)


func _finish_spawn_intro() -> void:
	_spawn_intro_active = false
	collision_layer = _base_collision_layer
	collision_mask = _base_collision_mask
	sprite.modulate = _base_stun_modulate

	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)

	if hurtbox != null:
		hurtbox.set_deferred("monitoring", _base_hurtbox_monitoring)
		hurtbox.set_deferred("monitorable", _base_hurtbox_monitorable)

	if hurtbox_collision_shape != null:
		hurtbox_collision_shape.set_deferred("disabled", false)

	if _spawn_intro_shadow != null:
		var shadow_tween := _spawn_intro_shadow.create_tween()
		shadow_tween.tween_property(_spawn_intro_shadow, "modulate:a", 0.0, 0.12)
		shadow_tween.tween_callback(_spawn_intro_shadow.hide)


func apply_global_stun(duration: float) -> void:
	_global_stun_left = maxf(_global_stun_left, duration)
	_set_global_stun_visual(true)


func _update_global_stun(delta: float) -> bool:
	if _global_stun_left <= 0.0:
		return false

	_global_stun_left = maxf(_global_stun_left - delta, 0.0)

	if _global_stun_left <= 0.0:
		_set_global_stun_visual(false)

	return true


func _get_global_stun_modified_damage(amount: int) -> float:
	var final_amount := float(amount)

	if _global_stun_left > 0.0:
		final_amount *= global_stun_damage_multiplier

	return final_amount


func _set_global_stun_visual(is_enabled: bool) -> void:
	if sprite == null:
		return

	if is_enabled:
		sprite.modulate = _base_stun_modulate * global_stun_tint
	else:
		sprite.modulate = _base_stun_modulate
